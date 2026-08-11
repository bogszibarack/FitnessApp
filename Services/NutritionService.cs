using System.Collections.Concurrent;
using System.Text.Json;
using FitnessBackend.Models;

namespace FitnessBackend.Services
{
    public static class NutritionService
    {
        private static readonly ConcurrentDictionary<string, (DateTime At, List<FoodItem> Items)> _searchCache = new();
        private static readonly TimeSpan CacheTtl = TimeSpan.FromMinutes(30);

        private const string OffApiBase = "https://world.openfoodfacts.org";
        private const string OffSearchApi = "https://search.openfoodfacts.org/search";
        private const string OffUserAgent = "FitnessBackend/1.0 (flexio; food-search)";

        private static List<FoodItem> SearchOffline(string query) =>
            HungarianFoodCatalog.Search(query, max: 12);

                private static string StripAccents(string s) =>
            s.Replace('á', 'a').Replace('é', 'e').Replace('í', 'i')
             .Replace('ó', 'o').Replace('ö', 'o').Replace('ő', 'o')
             .Replace('ú', 'u').Replace('ü', 'u').Replace('ű', 'u');

        public static async Task<List<FoodItem>> SearchFoodAsync(string query, string? userName = null)
        {
            string key = query.Trim().ToLowerInvariant();
            if (key.Length < 2) return [];

            // Per-user cache key so custom foods don't leak across accounts.
            string cacheKey = string.IsNullOrWhiteSpace(userName) ? key : $"{userName.Trim().ToLowerInvariant()}|{key}";

            if (_searchCache.TryGetValue(cacheKey, out var cached) &&
                DateTime.UtcNow - cached.At < CacheTtl &&
                cached.Items.Count > 0)
                return cached.Items;

            var results = new List<FoodItem>();
            var seen = new HashSet<string>(StringComparer.OrdinalIgnoreCase);

            void AddRange(IEnumerable<FoodItem> items)
            {
                foreach (var item in items)
                {
                    if (string.IsNullOrWhiteSpace(item.Id) || !seen.Add(item.Id)) continue;
                    results.Add(item);
                }
            }

            // User custom foods first
            if (!string.IsNullOrWhiteSpace(userName))
            {
                var needle = StripAccents(key);
                AddRange(NutritionStore.ListCustomFoods(userName)
                    .Where(f => StripAccents(f.Name.ToLowerInvariant()).Contains(needle))
                    .Select(f => f.ToFoodItem()));
            }

            AddRange(SearchOffline(query));

            if (FatSecretConfig.HasCredentials)
            {
                try
                {
                    AddRange(await FatSecretApi.SearchAsync(query, 15));
                }
                catch (Exception ex)
                {
                    Console.WriteLine($"[Nutrition] FatSecret search failed: {ex.Message}");
                }
            }

            if (results.Count < 12)
            {
                try
                {
                    var off = await SearchOpenFoodFactsAsync(query, 12);
                    Console.WriteLine($"[Nutrition] OFF '{query}' → {off.Count} hits (before merge had {results.Count})");
                    AddRange(off);
                }
                catch (Exception ex)
                {
                    Console.WriteLine($"[Nutrition] OpenFoodFacts search failed: {ex.Message}");
                }
            }

            results = RankFoodResults(query, results).Take(20).ToList();

            if (results.Count > 0)
                _searchCache[cacheKey] = (DateTime.UtcNow, results);

            return results;
        }

        private static List<FoodItem> RankFoodResults(string query, List<FoodItem> items)
        {
            string norm = StripAccents(query.Trim().ToLowerInvariant());
            var tokens = norm.Split(' ', StringSplitOptions.RemoveEmptyEntries)
                .Where(t => t.Length >= 2)
                .ToArray();
            string english = StripAccents(SearchQueryTranslator.ToEnglish(query).ToLowerInvariant());
            var engTokens = english.Split(' ', StringSplitOptions.RemoveEmptyEntries)
                .Where(t => t.Length >= 2)
                .ToArray();

            var catalogById = HungarianFoodCatalog.All.ToDictionary(e => e.Id, StringComparer.OrdinalIgnoreCase);

            var ranked = items
                .Select(item =>
                {
                    // Score display name + catalog aliases (so "hasábburgonya" boosts "Sült krumpli").
                    var labels = new List<string> { StripAccents(item.Name.ToLowerInvariant()) };
                    if (catalogById.TryGetValue(item.Id, out var entry))
                    {
                        foreach (var a in entry.Aliases)
                            labels.Add(StripAccents(a.ToLowerInvariant()));
                    }

                    int score = 0;
                    int hits = 0;
                    foreach (var name in labels)
                    {
                        int local = 0;
                        if (name == norm || name == english) local += 100;
                        if (name.StartsWith(norm, StringComparison.Ordinal) ||
                            (english.Length >= 3 && name.StartsWith(english, StringComparison.Ordinal))) local += 50;
                        if (name.Contains(norm, StringComparison.Ordinal) ||
                            (english.Length >= 3 && name.Contains(english, StringComparison.Ordinal))) local += 25;
                        int huHits = tokens.Count(t => name.Contains(t, StringComparison.Ordinal));
                        int enHits = engTokens.Count(t => name.Contains(t, StringComparison.Ordinal));
                        local += Math.Max(huHits, enHits) * 12;
                        hits = Math.Max(hits, Math.Max(huHits, enHits));
                        if (local > score) score = local;
                    }

                    if (item.Id.StartsWith("custom_", StringComparison.Ordinal)) score += 50;
                    else if (item.Id.StartsWith("hu_", StringComparison.Ordinal)) score += 40;
                    else if (item.Id.StartsWith("off_", StringComparison.Ordinal)) score += 8;
                    return (Item: item, Score: score, Hits: hits);
                })
                .Where(x => x.Score > 0)
                .Where(x => x.Hits > 0 ||
                            x.Item.Id.StartsWith("hu_", StringComparison.Ordinal) ||
                            x.Item.Id.StartsWith("off_", StringComparison.Ordinal) ||
                            x.Score >= 25)
                .OrderByDescending(x => x.Score)
                .Select(x => x.Item)
                .ToList();

            return ranked;
        }

        private static async Task<List<FoodItem>> SearchOpenFoodFactsAsync(string query, int max)
        {
            using var client = new HttpClient();
            client.DefaultRequestHeaders.TryAddWithoutValidation("User-Agent", OffUserAgent);
            client.Timeout = TimeSpan.FromSeconds(12);

            var results = new List<FoodItem>();
            var seen = new HashSet<string>(StringComparer.OrdinalIgnoreCase);

            void AddProduct(JsonElement product)
            {
                if (results.Count >= max) return;
                var food = FromOffProduct(product);
                if (food == null || food.Calories <= 0) return;
                if (!seen.Add(food.Id)) return;
                results.Add(food);
            }

            // 1) search-a-licious (more reliable than cgi/search.pl from cloud IPs)
            foreach (string term in SearchQueryTranslator.SearchExpressions(query).Take(4))
            {
                if (results.Count >= max) break;
                try
                {
                    string url =
                        $"{OffSearchApi}?q={Uri.EscapeDataString(term)}&page_size={Math.Min(max, 12)}&langs=hu";
                    using var resp = await client.GetAsync(url);
                    if (!resp.IsSuccessStatusCode) continue;
                    string raw = await resp.Content.ReadAsStringAsync();
                    using var doc = JsonDocument.Parse(raw);
                    if (!doc.RootElement.TryGetProperty("hits", out var hits) ||
                        hits.ValueKind != JsonValueKind.Array)
                        continue;
                    foreach (var hit in hits.EnumerateArray())
                        AddProduct(hit);
                }
                catch (Exception ex)
                {
                    Console.WriteLine($"[Nutrition] OFF search-a-licious '{term}' failed: {ex.Message}");
                }
            }

            // 2) Legacy cgi/search.pl fallback if still thin
            if (results.Count < 4)
            {
                foreach (string term in SearchQueryTranslator.SearchExpressions(query).Take(3))
                {
                    if (results.Count >= max) break;
                    try
                    {
                        string url =
                            $"{OffApiBase}/cgi/search.pl?search_terms={Uri.EscapeDataString(term)}" +
                            "&search_simple=1&action=process&json=1" +
                            $"&page_size={Math.Min(max, 12)}";
                        using var resp = await client.GetAsync(url);
                        if (!resp.IsSuccessStatusCode) continue;
                        string raw = await resp.Content.ReadAsStringAsync();
                        using var doc = JsonDocument.Parse(raw);
                        if (!doc.RootElement.TryGetProperty("products", out var products) ||
                            products.ValueKind != JsonValueKind.Array)
                            continue;
                        foreach (var product in products.EnumerateArray())
                            AddProduct(product);
                    }
                    catch
                    {
                        // ignore — search-a-licious is primary
                    }
                }
            }

            return results;
        }

        public static async Task<(FoodItem? Food, string? Error, int Status)> LookupBarcodeAsync(string barcode)
        {
            try
            {
                if (FatSecretConfig.HasCredentials)
                {
                    var fs = await FatSecretApi.LookupBarcodeAsync(barcode);
                    if (fs != null) return (fs, null, 200);
                }

                using var client = new HttpClient();
                client.DefaultRequestHeaders.Add("User-Agent", OffUserAgent);

                string url = $"{OffApiBase}/api/v2/product/{barcode}.json" +
                             "?fields=code,product_name,product_name_hu,product_name_en,brands,nutriments,image_front_thumb_url";
                string raw = await client.GetStringAsync(url);

                using JsonDocument doc = JsonDocument.Parse(raw);
                int status = doc.RootElement.TryGetProperty("status", out var s) ? s.GetInt32() : 0;

                if (status != 1 || !doc.RootElement.TryGetProperty("product", out var product))
                    return (null, "Nem talalhato termek ehhez a vonalkodhoz.", 404);

                var food = FromOffProduct(product);
                if (food == null) return (null, "A termek adatai hianyosak.", 404);

                return (food, null, 200);
            }
            catch (Exception)
            {
                return (null, "A vonalkod-adatbazis nem elerheto. Probald ujra kesobb!", 503);
            }
        }

        public static DailyNutritionSession GetLog(string userName, DateTime date) =>
            NutritionStore.GetOrCreateLog(userName, date);

        public static object MealSummary(string userName, string mealType)
        {
            var log = GetLog(userName, DateTime.Today);
            var foods = log.EatenFoods
                .Where(e => e.MealType.Equals(mealType, StringComparison.OrdinalIgnoreCase))
                .ToList();

            return new
            {
                meal = mealType,
                foods,
                totalCalories = Math.Round(foods.Sum(e => e.CalculatedCalories), 1),
                totalProtein = Math.Round(foods.Sum(e => e.CalculatedProtein), 1),
                etkezes = mealType,
                etelek = foods,
                ossz_kaloria = Math.Round(foods.Sum(e => e.CalculatedCalories), 1),
                ossz_feherje = Math.Round(foods.Sum(e => e.CalculatedProtein), 1),
            };
        }

        public static DailyNutritionSession SetTargetCalories(string userName, double target)
        {
            var log = GetLog(userName, DateTime.Today);
            log.TargetCalories = target;
            DataStore.SaveNutrition();
            return log;
        }

        public static (DailyNutritionSession? Log, string? Error) AddFood(string userName, LoggedFood food)
        {
            if (!food.FromRecipe && food.AmountGrams <= 0)
                return (null, "Az AmountGrams (gramm) kotelezo es nagyobb mint 0.");

            var log = GetLog(userName, DateTime.Today);
            log.EatenFoods.Add(food);
            DataStore.SaveNutrition();
            return (log, null);
        }

        public static Task<(DailyNutritionSession? log, LoggedFood? entry, string? error)> AddRecipeAsync(
            string userName, AddRecipeRequest request) =>
            NutritionStore.AddRecipeAsync(userName, request);

        public static List<LoggedFood> TodaysRecipes(string userName) =>
            GetLog(userName, DateTime.Today).EatenFoods.Where(e => e.FromRecipe).ToList();

        public static (DailyNutritionSession? Log, string? Error) UpdateFood(string userName, int index, LoggedFood food)
        {
            var log = GetLog(userName, DateTime.Today);
            if (index < 0 || index >= log.EatenFoods.Count)
                return (null, "Nincs ilyen etel a mai naploban.");
            log.EatenFoods[index] = food;
            DataStore.SaveNutrition();
            return (log, null);
        }

        public static (DailyNutritionSession? Log, string? Error) DeleteFood(string userName, int index)
        {
            var log = GetLog(userName, DateTime.Today);
            if (index < 0 || index >= log.EatenFoods.Count)
                return (null, "Nincs ilyen etel a mai naploban.");
            log.EatenFoods.RemoveAt(index);
            DataStore.SaveNutrition();
            return (log, null);
        }

        public static (CustomFood? Food, string? Error) CreateCustomFood(string userName, CustomFoodRequest request)
        {
            var food = NutritionStore.AddCustomFood(userName, request);
            if (food == null) return (null, "Nev es nem negativ makrok kotelezoek.");
            return (food, null);
        }

        public static List<CustomFood> ListCustomFoods(string userName) =>
            NutritionStore.ListCustomFoods(userName);

        public static bool DeleteCustomFood(string userName, string foodId) =>
            NutritionStore.DeleteCustomFood(userName, foodId);

        private static FoodItem? FromOffProduct(JsonElement product)
        {
            string name = OffProductName(product);
            if (string.IsNullOrWhiteSpace(name)) return null;

            string brand = product.TryGetProperty("brands", out var m) ? m.GetString() ?? "" : "";
            string fullName = string.IsNullOrWhiteSpace(brand) ? name : $"[{brand}] {name}";
            string id = product.TryGetProperty("code", out var c) ? c.GetString() ?? "0" : "0";
            string image = "";
            foreach (var imgField in new[] { "image_front_thumb_url", "image_front_small_url", "image_thumb_url" })
            {
                if (product.TryGetProperty(imgField, out var k) && k.ValueKind == JsonValueKind.String)
                {
                    image = k.GetString() ?? "";
                    if (!string.IsNullOrWhiteSpace(image)) break;
                }
            }

            double kcal = 0, protein = 0, carbs = 0, fat = 0;

            if (product.TryGetProperty("nutriments", out var nu))
            {
                kcal = OffNutrient(nu, "energy-kcal_100g");
                if (kcal <= 0)
                {
                    double kj = OffNutrient(nu, "energy-kj_100g");
                    if (kj > 0) kcal = kj / 4.184;
                }
                protein = OffNutrient(nu, "proteins_100g");
                carbs = OffNutrient(nu, "carbohydrates_100g");
                fat = OffNutrient(nu, "fat_100g");
            }

            return new FoodItem
            {
                Id = id,
                Name = fullName,
                Calories = Math.Round(kcal, 1),
                Protein = Math.Round(protein, 1),
                Carbs = Math.Round(carbs, 1),
                Fat = Math.Round(fat, 1),
                ImageUrl = image
            };
        }

        private static string OffProductName(JsonElement product)
        {
            foreach (var field in new[] { "product_name_hu", "product_name_en", "product_name" })
            {
                if (product.TryGetProperty(field, out var v) && v.ValueKind == JsonValueKind.String)
                {
                    string s = v.GetString() ?? "";
                    if (!string.IsNullOrWhiteSpace(s)) return s;
                }
            }
            return "";
        }

        private static double OffNutrient(JsonElement nu, string field)
        {
            if (!nu.TryGetProperty(field, out var e)) return 0;
            if (e.ValueKind == JsonValueKind.Number) return e.GetDouble();
            if (e.ValueKind == JsonValueKind.String &&
                double.TryParse(e.GetString(), System.Globalization.NumberStyles.Any,
                    System.Globalization.CultureInfo.InvariantCulture, out var v))
                return v;
            return 0;
        }
    }
}
