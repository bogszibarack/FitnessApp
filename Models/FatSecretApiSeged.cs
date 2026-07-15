using System.Collections.Concurrent;
using System.Globalization;
using System.Net.Http.Headers;
using System.Text;
using System.Text.Json;
using System.Text.RegularExpressions;

namespace FitnessBackend.Models
{
    public static class FatSecretConfig
    {
        public static string ClientId { get; set; } = "";
        public static string ClientSecret { get; set; } = "";
        public const string TokenUrl = "https://oauth.fatsecret.com/connect/token";
        public const string ApiUrl = "https://platform.fatsecret.com/rest/server.api";
        public static bool VanKulcs =>
            !string.IsNullOrWhiteSpace(ClientId) && !string.IsNullOrWhiteSpace(ClientSecret);
    }

    /// <summary>
    /// FatSecret Platform API — étel keresés és vonalkód (OAuth 2.0 client credentials).
    /// </summary>
    public static class FatSecretApiSeged
    {
        private static readonly HttpClient kliens = new();
        private static readonly ConcurrentDictionary<string, List<FoodItem>> kereses_cache = new();
        private static readonly ConcurrentDictionary<string, FoodItem> vonalkod_cache = new();

        private static string? _accessToken;
        private static DateTime _tokenLejar = DateTime.MinValue;
        private static readonly SemaphoreSlim tokenLock = new(1, 1);

        private static readonly Regex leirasRegex = new(
            @"Per\s+([\d.,]+)\s*(g|oz|ml|cup|serving|slice|piece|medium|large|small)\s*-\s*Calories:\s*([\d.,]+)\s*kcal\s*\|\s*Fat:\s*([\d.,]+)\s*g\s*\|\s*Carbs:\s*([\d.,]+)\s*g\s*\|\s*Protein:\s*([\d.,]+)\s*g",
            RegexOptions.IgnoreCase | RegexOptions.CultureInvariant);

        public static async Task<List<FoodItem>> Kereses(string keresoszó, int max = 15)
        {
            if (!FatSecretConfig.VanKulcs || string.IsNullOrWhiteSpace(keresoszó))
                return new List<FoodItem>();

            string kulcs = keresoszó.Trim().ToLowerInvariant();
            if (kereses_cache.TryGetValue(kulcs, out var cached))
                return cached;

            var eredmenyek = new List<FoodItem>();

            foreach (var kifejezes in KeresesiKifejezesek(keresoszó))
            {
                var talalatok = await FoodsSearch(kifejezes, max);
                foreach (var t in talalatok)
                {
                    if (!eredmenyek.Any(e => e.Id == t.Id))
                        eredmenyek.Add(t);
                }
                if (eredmenyek.Count >= max) break;
            }

            if (eredmenyek.Count > 0)
                kereses_cache[kulcs] = eredmenyek;

            return eredmenyek;
        }

        public static async Task<FoodItem?> VonalkodKereses(string vonalkod)
        {
            if (!FatSecretConfig.VanKulcs || string.IsNullOrWhiteSpace(vonalkod))
                return null;

            string kod = vonalkod.Trim();
            if (vonalkod_cache.TryGetValue(kod, out var cached))
                return cached;

            try
            {
                string? foodId = await FoodIdVonalkodbol(kod);
                if (string.IsNullOrWhiteSpace(foodId)) return null;

                var etel = await FoodReszletek(foodId, kod);
                if (etel != null)
                    vonalkod_cache[kod] = etel;
                return etel;
            }
            catch (Exception)
            {
                return null;
            }
        }

        private static IEnumerable<string> KeresesiKifejezesek(string keresoszó)
        {
            yield return keresoszó.Trim();
            string angol = MagyarKeresesFordito.Forditas(keresoszó);
            if (!string.Equals(angol, keresoszó.Trim(), StringComparison.OrdinalIgnoreCase))
                yield return angol;
        }

        private static async Task<List<FoodItem>> FoodsSearch(string kifejezes, int max)
        {
            var json = await ApiHivas(new Dictionary<string, string>
            {
                ["method"] = "foods.search",
                ["search_expression"] = kifejezes,
                ["max_results"] = max.ToString(CultureInfo.InvariantCulture),
                ["page_number"] = "0",
            });

            if (json == null) return new List<FoodItem>();

            if (!json.Value.TryGetProperty("foods_search", out var kereses) ||
                !kereses.TryGetProperty("results", out var results))
                return new List<FoodItem>();

            var lista = new List<FoodItem>();
            foreach (var food in FoodElemek(results))
            {
                var item = FoodItemKeresesbol(food);
                if (item != null && item.Calories > 0)
                    lista.Add(item);
            }

            return lista;
        }

        private static async Task<string?> FoodIdVonalkodbol(string vonalkod)
        {
            var json = await ApiHivas(new Dictionary<string, string>
            {
                ["method"] = "food.find_id_for_barcode",
                ["barcode"] = vonalkod,
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

        private static async Task<FoodItem?> FoodReszletek(string foodId, string? vonalkod = null)
        {
            var json = await ApiHivas(new Dictionary<string, string>
            {
                ["method"] = "food.get.v4",
                ["food_id"] = foodId,
            });

            if (json == null || !json.Value.TryGetProperty("food", out var food))
                return null;

            string nev = food.TryGetProperty("food_name", out var nevElem) ? nevElem.GetString() ?? "" : "";
            string marka = food.TryGetProperty("brand_name", out var markaElem) ? markaElem.GetString() ?? "" : "";
            if (string.IsNullOrWhiteSpace(nev)) return null;

            string teljesNev = string.IsNullOrWhiteSpace(marka) ? nev : $"[{marka}] {nev}";
            string kep = "";

            if (food.TryGetProperty("food_images", out var kepek) &&
                kepek.TryGetProperty("food_image", out var kepLista))
            {
                foreach (var k in KepElemek(kepLista))
                {
                    if (k.TryGetProperty("image_url", out var urlElem))
                    {
                        kep = urlElem.GetString() ?? "";
                        if (!string.IsNullOrWhiteSpace(kep)) break;
                    }
                }
            }

            var (kcal, feherje, szenhidrat, zsir) = MakrokSzolgaltatasbol(food);
            if (kcal <= 0 && food.TryGetProperty("food_description", out var leirasElem))
            {
                var parsed = LeirasbolMakrok(leirasElem.GetString() ?? "");
                if (parsed.HasValue) (kcal, feherje, szenhidrat, zsir) = parsed.Value;
            }

            if (kcal <= 0) return null;

            return new FoodItem
            {
                Id = vonalkod ?? $"fs_{foodId}",
                Name = teljesNev,
                Calories = kcal,
                Protein = feherje,
                Carbs = szenhidrat,
                Fat = zsir,
                ImageUrl = kep,
            };
        }

        private static FoodItem? FoodItemKeresesbol(JsonElement food)
        {
            string id = food.TryGetProperty("food_id", out var idElem) ? idElem.GetString() ?? "" : "";
            string nev = food.TryGetProperty("food_name", out var nevElem) ? nevElem.GetString() ?? "" : "";
            string marka = food.TryGetProperty("brand_name", out var markaElem) ? markaElem.GetString() ?? "" : "";
            if (string.IsNullOrWhiteSpace(id) || string.IsNullOrWhiteSpace(nev)) return null;

            string teljesNev = string.IsNullOrWhiteSpace(marka) ? nev : $"[{marka}] {nev}";
            string leiras = food.TryGetProperty("food_description", out var leirasElem) ? leirasElem.GetString() ?? "" : "";
            var makrok = LeirasbolMakrok(leiras);
            if (makrok == null) return null;

            var (kcal, feherje, szenhidrat, zsir) = makrok.Value;

            return new FoodItem
            {
                Id = $"fs_{id}",
                Name = teljesNev,
                Calories = kcal,
                Protein = feherje,
                Carbs = szenhidrat,
                Fat = zsir,
            };
        }

        private static (double kcal, double feherje, double szenhidrat, double zsir) MakrokSzolgaltatasbol(JsonElement food)
        {
            if (!food.TryGetProperty("servings", out var servings) ||
                !servings.TryGetProperty("serving", out var servingLista))
                return (0, 0, 0, 0);

            JsonElement? legjobb = null;
            foreach (var s in ServingElemek(servingLista))
            {
                string desc = s.TryGetProperty("serving_description", out var d) ? d.GetString() ?? "" : "";
                if (desc.Contains("100 g", StringComparison.OrdinalIgnoreCase) ||
                    desc.Contains("100g", StringComparison.OrdinalIgnoreCase))
                {
                    legjobb = s;
                    break;
                }
                legjobb ??= s;
            }

            if (legjobb == null) return (0, 0, 0, 0);
            return MakrokServingbol(legjobb.Value);
        }

        private static (double kcal, double feherje, double szenhidrat, double zsir) MakrokServingbol(JsonElement serving)
        {
            double kcal = JsonDouble(serving, "calories");
            double feherje = JsonDouble(serving, "protein");
            double szenhidrat = JsonDouble(serving, "carbohydrate");
            double zsir = JsonDouble(serving, "fat");

            double mennyiseg = JsonDouble(serving, "metric_serving_amount");
            string egyseg = serving.TryGetProperty("metric_serving_unit", out var u) ? u.GetString() ?? "g" : "g";

            if (mennyiseg > 0 && !egyseg.Equals("g", StringComparison.OrdinalIgnoreCase))
                return (Math.Round(kcal, 1), Math.Round(feherje, 1), Math.Round(szenhidrat, 1), Math.Round(zsir, 1));

            if (mennyiseg > 0 && Math.Abs(mennyiseg - 100) > 0.01)
            {
                double szorzo = 100.0 / mennyiseg;
                kcal *= szorzo;
                feherje *= szorzo;
                szenhidrat *= szorzo;
                zsir *= szorzo;
            }

            return (
                Math.Round(kcal, 1),
                Math.Round(feherje, 1),
                Math.Round(szenhidrat, 1),
                Math.Round(zsir, 1)
            );
        }

        private static (double kcal, double feherje, double szenhidrat, double zsir)? LeirasbolMakrok(string leiras)
        {
            if (string.IsNullOrWhiteSpace(leiras)) return null;

            var match = leirasRegex.Match(leiras);
            if (!match.Success) return null;

            double mennyiseg = ParseDouble(match.Groups[1].Value);
            string egyseg = match.Groups[2].Value.ToLowerInvariant();
            double kcal = ParseDouble(match.Groups[3].Value);
            double zsir = ParseDouble(match.Groups[4].Value);
            double szenhidrat = ParseDouble(match.Groups[5].Value);
            double feherje = ParseDouble(match.Groups[6].Value);

            if (egyseg == "g" && mennyiseg > 0 && Math.Abs(mennyiseg - 100) > 0.01)
            {
                double szorzo = 100.0 / mennyiseg;
                kcal *= szorzo;
                feherje *= szorzo;
                szenhidrat *= szorzo;
                zsir *= szorzo;
            }

            return (
                Math.Round(kcal, 1),
                Math.Round(feherje, 1),
                Math.Round(szenhidrat, 1),
                Math.Round(zsir, 1)
            );
        }

        private static async Task<JsonElement?> ApiHivas(Dictionary<string, string> parameterek)
        {
            string? token = await AccessToken();
            if (token == null) return null;

            var queryParts = parameterek
                .Select(p => $"{Uri.EscapeDataString(p.Key)}={Uri.EscapeDataString(p.Value)}")
                .Append("format=json");
            var url = FatSecretConfig.ApiUrl + "?" + string.Join("&", queryParts);

            using var request = new HttpRequestMessage(HttpMethod.Get, url);
            request.Headers.Authorization = new AuthenticationHeaderValue("Bearer", token);

            using var response = await kliens.SendAsync(request);
            if (!response.IsSuccessStatusCode) return null;

            string nyers = await response.Content.ReadAsStringAsync();
            using var doc = JsonDocument.Parse(nyers);
            return doc.RootElement.Clone();
        }

        private static async Task<string?> AccessToken()
        {
            if (_accessToken != null && DateTime.UtcNow < _tokenLejar)
                return _accessToken;

            await tokenLock.WaitAsync();
            try
            {
                if (_accessToken != null && DateTime.UtcNow < _tokenLejar)
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

                using var response = await kliens.SendAsync(request);
                if (!response.IsSuccessStatusCode) return null;

                string nyers = await response.Content.ReadAsStringAsync();
                using var doc = JsonDocument.Parse(nyers);
                _accessToken = doc.RootElement.TryGetProperty("access_token", out var t) ? t.GetString() : null;

                int lejarMp = doc.RootElement.TryGetProperty("expires_in", out var e) ? e.GetInt32() : 3600;
                _tokenLejar = DateTime.UtcNow.AddSeconds(Math.Max(60, lejarMp - 60));

                return _accessToken;
            }
            finally
            {
                tokenLock.Release();
            }
        }

        private static IEnumerable<JsonElement> FoodElemek(JsonElement results)
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

        private static IEnumerable<JsonElement> ServingElemek(JsonElement serving)
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

        private static IEnumerable<JsonElement> KepElemek(JsonElement kep)
        {
            if (kep.ValueKind == JsonValueKind.Array)
            {
                foreach (var item in kep.EnumerateArray())
                    yield return item;
            }
            else if (kep.ValueKind == JsonValueKind.Object)
            {
                yield return kep;
            }
        }

        private static double JsonDouble(JsonElement elem, string mezo)
        {
            if (!elem.TryGetProperty(mezo, out var e)) return 0;
            if (e.ValueKind == JsonValueKind.Number) return e.GetDouble();
            if (e.ValueKind == JsonValueKind.String) return ParseDouble(e.GetString() ?? "0");
            return 0;
        }

        private static double ParseDouble(string value) =>
            double.TryParse(value.Replace(',', '.'), NumberStyles.Any, CultureInfo.InvariantCulture, out var v) ? v : 0;
    }
}
