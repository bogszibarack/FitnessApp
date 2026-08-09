using System.Collections.Concurrent;
using System.Globalization;
using System.Net.Http.Headers;
using System.Text;
using System.Text.Json;
using System.Text.RegularExpressions;
using FitnessBackend.Models;

namespace FitnessBackend.Services
{
    public static class FatSecretConfig
    {
        public static string ClientId { get; set; } = "";
        public static string ClientSecret { get; set; } = "";
        public const string TokenUrl = "https://oauth.fatsecret.com/connect/token";
        public const string ApiUrl = "https://platform.fatsecret.com/rest/server.api";

        public static bool HasCredentials =>
            !string.IsNullOrWhiteSpace(ClientId) && !string.IsNullOrWhiteSpace(ClientSecret);
    }

    /// <summary>
    /// FatSecret Platform API — food search and barcode (OAuth 2.0 client credentials).
    /// </summary>
    public static class FatSecretApi
    {
        private static readonly HttpClient Http = new();
        private static readonly ConcurrentDictionary<string, (DateTime At, List<FoodItem> Items)> SearchCache = new();
        private static readonly ConcurrentDictionary<string, FoodItem> BarcodeCache = new();
        private static readonly TimeSpan SearchCacheTtl = TimeSpan.FromMinutes(30);

        private static string? _accessToken;
        private static DateTime _tokenExpiresAt = DateTime.MinValue;
        private static readonly SemaphoreSlim TokenLock = new(1, 1);

        private static readonly Regex DescriptionRegex = new(
            @"Per\s+([\d.,]+)\s*(g|oz|ml|cup|serving|slice|piece|medium|large|small)\s*-\s*Calories:\s*([\d.,]+)\s*kcal\s*\|\s*Fat:\s*([\d.,]+)\s*g\s*\|\s*Carbs:\s*([\d.,]+)\s*g\s*\|\s*Protein:\s*([\d.,]+)\s*g",
            RegexOptions.IgnoreCase | RegexOptions.CultureInvariant);

        public static async Task<List<FoodItem>> SearchAsync(string query, int max = 15)
        {
            if (!FatSecretConfig.HasCredentials || string.IsNullOrWhiteSpace(query))
                return [];

            string key = query.Trim().ToLowerInvariant();
            if (SearchCache.TryGetValue(key, out var cached) &&
                DateTime.UtcNow - cached.At < SearchCacheTtl &&
                cached.Items.Count > 0)
                return cached.Items;

            var results = new List<FoodItem>();

            foreach (var expression in SearchExpressions(query))
            {
                var hits = await FoodsSearchAsync(expression, max);
                foreach (var item in hits)
                {
                    if (!results.Any(e => e.Id == item.Id))
                        results.Add(item);
                }
                if (results.Count >= max) break;
            }

            if (results.Count > 0)
                SearchCache[key] = (DateTime.UtcNow, results);

            return results;
        }

        public static async Task<FoodItem?> LookupBarcodeAsync(string barcode)
        {
            if (!FatSecretConfig.HasCredentials || string.IsNullOrWhiteSpace(barcode))
                return null;

            string code = barcode.Trim();
            if (BarcodeCache.TryGetValue(code, out var cached))
                return cached;

            try
            {
                string? foodId = await FoodIdFromBarcodeAsync(code);
                if (string.IsNullOrWhiteSpace(foodId)) return null;

                var food = await FoodDetailsAsync(foodId, code);
                if (food != null)
                    BarcodeCache[code] = food;
                return food;
            }
            catch (Exception)
            {
                return null;
            }
        }

        private static IEnumerable<string> SearchExpressions(string query)
        {
            string raw = query.Trim();
            string english = SearchQueryTranslator.ToEnglish(query);
            // FatSecret is English-first — try translated query before raw HU.
            if (!string.Equals(english, raw, StringComparison.OrdinalIgnoreCase))
                yield return english;
            yield return raw;
        }

        private static async Task<List<FoodItem>> FoodsSearchAsync(string expression, int max)
        {
            var json = await ApiCallAsync(new Dictionary<string, string>
            {
                ["method"] = "foods.search",
                ["search_expression"] = expression,
                ["max_results"] = max.ToString(CultureInfo.InvariantCulture),
                ["page_number"] = "0",
            });

            if (json == null) return [];

            // Prefer foods_search.results; fall back to legacy foods.food.
            JsonElement results;
            if (json.Value.TryGetProperty("foods_search", out var search) &&
                search.TryGetProperty("results", out results))
            {
                // ok
            }
            else if (json.Value.TryGetProperty("foods", out var foods))
            {
                results = foods;
            }
            else
            {
                return [];
            }

            var list = new List<FoodItem>();
            foreach (var food in FoodElements(results))
            {
                var item = FromSearchResult(food);
                if (item != null && item.Calories > 0)
                    list.Add(item);
            }

            return list;
        }

        private static async Task<string?> FoodIdFromBarcodeAsync(string barcode)
        {
            var json = await ApiCallAsync(new Dictionary<string, string>
            {
                ["method"] = "food.find_id_for_barcode",
                ["barcode"] = barcode,
            });

            if (json == null) return null;

            if (json.Value.TryGetProperty("food_id", out var idElem))
            {
                if (idElem.ValueKind == JsonValueKind.Object &&
                    idElem.TryGetProperty("value", out var value))
                    return value.GetString();

                if (idElem.ValueKind == JsonValueKind.String)
                    return idElem.GetString();
            }

            return null;
        }

        private static async Task<FoodItem?> FoodDetailsAsync(string foodId, string? barcode = null)
        {
            var json = await ApiCallAsync(new Dictionary<string, string>
            {
                ["method"] = "food.get.v4",
                ["food_id"] = foodId,
            });

            if (json == null || !json.Value.TryGetProperty("food", out var food))
                return null;

            string name = food.TryGetProperty("food_name", out var nameElem) ? nameElem.GetString() ?? "" : "";
            string brand = food.TryGetProperty("brand_name", out var brandElem) ? brandElem.GetString() ?? "" : "";
            if (string.IsNullOrWhiteSpace(name)) return null;

            string fullName = string.IsNullOrWhiteSpace(brand) ? name : $"[{brand}] {name}";
            string image = "";

            if (food.TryGetProperty("food_images", out var images) &&
                images.TryGetProperty("food_image", out var imageList))
            {
                foreach (var img in ImageElements(imageList))
                {
                    if (img.TryGetProperty("image_url", out var urlElem))
                    {
                        image = urlElem.GetString() ?? "";
                        if (!string.IsNullOrWhiteSpace(image)) break;
                    }
                }
            }

            var (kcal, protein, carbs, fat) = MacrosFromServings(food);
            if (kcal <= 0 && food.TryGetProperty("food_description", out var descElem))
            {
                var parsed = MacrosFromDescription(descElem.GetString() ?? "");
                if (parsed.HasValue) (kcal, protein, carbs, fat) = parsed.Value;
            }

            if (kcal <= 0) return null;

            return new FoodItem
            {
                Id = barcode ?? $"fs_{foodId}",
                Name = fullName,
                Calories = kcal,
                Protein = protein,
                Carbs = carbs,
                Fat = fat,
                ImageUrl = image,
            };
        }

        private static FoodItem? FromSearchResult(JsonElement food)
        {
            string id = food.TryGetProperty("food_id", out var idElem) ? idElem.GetString() ?? "" : "";
            string name = food.TryGetProperty("food_name", out var nameElem) ? nameElem.GetString() ?? "" : "";
            string brand = food.TryGetProperty("brand_name", out var brandElem) ? brandElem.GetString() ?? "" : "";
            if (string.IsNullOrWhiteSpace(id) || string.IsNullOrWhiteSpace(name)) return null;

            string fullName = string.IsNullOrWhiteSpace(brand) ? name : $"[{brand}] {name}";
            string description = food.TryGetProperty("food_description", out var descElem) ? descElem.GetString() ?? "" : "";
            var macros = MacrosFromDescription(description);
            if (macros == null) return null;

            var (kcal, protein, carbs, fat) = macros.Value;

            return new FoodItem
            {
                Id = $"fs_{id}",
                Name = fullName,
                Calories = kcal,
                Protein = protein,
                Carbs = carbs,
                Fat = fat,
            };
        }

        private static (double kcal, double protein, double carbs, double fat) MacrosFromServings(JsonElement food)
        {
            if (!food.TryGetProperty("servings", out var servings) ||
                !servings.TryGetProperty("serving", out var servingList))
                return (0, 0, 0, 0);

            JsonElement? best = null;
            foreach (var s in ServingElements(servingList))
            {
                string desc = s.TryGetProperty("serving_description", out var d) ? d.GetString() ?? "" : "";
                if (desc.Contains("100 g", StringComparison.OrdinalIgnoreCase) ||
                    desc.Contains("100g", StringComparison.OrdinalIgnoreCase))
                {
                    best = s;
                    break;
                }
                best ??= s;
            }

            if (best == null) return (0, 0, 0, 0);
            return MacrosFromServing(best.Value);
        }

        private static (double kcal, double protein, double carbs, double fat) MacrosFromServing(JsonElement serving)
        {
            double kcal = JsonDouble(serving, "calories");
            double protein = JsonDouble(serving, "protein");
            double carbs = JsonDouble(serving, "carbohydrate");
            double fat = JsonDouble(serving, "fat");

            double amount = JsonDouble(serving, "metric_serving_amount");
            string unit = serving.TryGetProperty("metric_serving_unit", out var u) ? u.GetString() ?? "g" : "g";

            if (amount > 0 && !unit.Equals("g", StringComparison.OrdinalIgnoreCase))
                return (Math.Round(kcal, 1), Math.Round(protein, 1), Math.Round(carbs, 1), Math.Round(fat, 1));

            if (amount > 0 && Math.Abs(amount - 100) > 0.01)
            {
                double scale = 100.0 / amount;
                kcal *= scale;
                protein *= scale;
                carbs *= scale;
                fat *= scale;
            }

            return (
                Math.Round(kcal, 1),
                Math.Round(protein, 1),
                Math.Round(carbs, 1),
                Math.Round(fat, 1)
            );
        }

        private static (double kcal, double protein, double carbs, double fat)? MacrosFromDescription(string description)
        {
            if (string.IsNullOrWhiteSpace(description)) return null;

            var match = DescriptionRegex.Match(description);
            if (!match.Success) return null;

            double amount = ParseDouble(match.Groups[1].Value);
            string unit = match.Groups[2].Value.ToLowerInvariant();
            double kcal = ParseDouble(match.Groups[3].Value);
            double fat = ParseDouble(match.Groups[4].Value);
            double carbs = ParseDouble(match.Groups[5].Value);
            double protein = ParseDouble(match.Groups[6].Value);

            if (unit == "g" && amount > 0 && Math.Abs(amount - 100) > 0.01)
            {
                double scale = 100.0 / amount;
                kcal *= scale;
                protein *= scale;
                carbs *= scale;
                fat *= scale;
            }

            return (
                Math.Round(kcal, 1),
                Math.Round(protein, 1),
                Math.Round(carbs, 1),
                Math.Round(fat, 1)
            );
        }

        private static async Task<JsonElement?> ApiCallAsync(Dictionary<string, string> parameters)
        {
            string? token = await GetAccessTokenAsync();
            if (token == null) return null;

            var queryParts = parameters
                .Select(p => $"{Uri.EscapeDataString(p.Key)}={Uri.EscapeDataString(p.Value)}")
                .Append("format=json");
            var url = FatSecretConfig.ApiUrl + "?" + string.Join("&", queryParts);

            using var request = new HttpRequestMessage(HttpMethod.Get, url);
            request.Headers.Authorization = new AuthenticationHeaderValue("Bearer", token);

            using var response = await Http.SendAsync(request);
            if (!response.IsSuccessStatusCode) return null;

            string raw = await response.Content.ReadAsStringAsync();
            using var doc = JsonDocument.Parse(raw);
            return doc.RootElement.Clone();
        }

        private static async Task<string?> GetAccessTokenAsync()
        {
            if (_accessToken != null && DateTime.UtcNow < _tokenExpiresAt)
                return _accessToken;

            await TokenLock.WaitAsync();
            try
            {
                if (_accessToken != null && DateTime.UtcNow < _tokenExpiresAt)
                    return _accessToken;

                string auth = Convert.ToBase64String(
                    Encoding.UTF8.GetBytes($"{FatSecretConfig.ClientId}:{FatSecretConfig.ClientSecret}"));

                using var request = new HttpRequestMessage(HttpMethod.Post, FatSecretConfig.TokenUrl);
                request.Headers.Authorization = new AuthenticationHeaderValue("Basic", auth);
                request.Content = new FormUrlEncodedContent(new Dictionary<string, string>
                {
                    ["grant_type"] = "client_credentials",
                    ["scope"] = "basic",
                });

                using var response = await Http.SendAsync(request);
                if (!response.IsSuccessStatusCode) return null;

                string raw = await response.Content.ReadAsStringAsync();
                using var doc = JsonDocument.Parse(raw);
                _accessToken = doc.RootElement.TryGetProperty("access_token", out var t) ? t.GetString() : null;

                int expiresIn = doc.RootElement.TryGetProperty("expires_in", out var e) ? e.GetInt32() : 3600;
                _tokenExpiresAt = DateTime.UtcNow.AddSeconds(Math.Max(60, expiresIn - 60));

                return _accessToken;
            }
            finally
            {
                TokenLock.Release();
            }
        }

        private static IEnumerable<JsonElement> FoodElements(JsonElement results)
        {
            if (!results.TryGetProperty("food", out var food)) yield break;

            if (food.ValueKind == JsonValueKind.Array)
            {
                foreach (var item in food.EnumerateArray())
                    yield return item;
            }
            else if (food.ValueKind == JsonValueKind.Object)
            {
                yield return food;
            }
        }

        private static IEnumerable<JsonElement> ServingElements(JsonElement serving)
        {
            if (serving.ValueKind == JsonValueKind.Array)
            {
                foreach (var item in serving.EnumerateArray())
                    yield return item;
            }
            else if (serving.ValueKind == JsonValueKind.Object)
            {
                yield return serving;
            }
        }

        private static IEnumerable<JsonElement> ImageElements(JsonElement image)
        {
            if (image.ValueKind == JsonValueKind.Array)
            {
                foreach (var item in image.EnumerateArray())
                    yield return item;
            }
            else if (image.ValueKind == JsonValueKind.Object)
            {
                yield return image;
            }
        }

        private static double JsonDouble(JsonElement elem, string field)
        {
            if (!elem.TryGetProperty(field, out var e)) return 0;
            if (e.ValueKind == JsonValueKind.Number) return e.GetDouble();
            if (e.ValueKind == JsonValueKind.String) return ParseDouble(e.GetString() ?? "0");
            return 0;
        }

        private static double ParseDouble(string value) =>
            double.TryParse(value.Replace(',', '.'), NumberStyles.Any, CultureInfo.InvariantCulture, out var v) ? v : 0;
    }
}
