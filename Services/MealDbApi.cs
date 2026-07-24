using System.Collections.Concurrent;
using System.Text.Json;
using FitnessBackend.Models;

namespace FitnessBackend.Services
{
    /// <summary>
    /// TheMealDB integration — free, unlimited, with images.
    /// https://www.themealdb.com/api.php
    /// </summary>
    public static class MealDbApi
    {
        private static readonly HttpClient Http = new();
        private const string BaseUrl = "https://www.themealdb.com/api/json/v1/1";

        private static readonly ConcurrentDictionary<string, (DateTime At, List<RecipeListItem> Items)> ListCache = new();
        private static readonly ConcurrentDictionary<string, (DateTime At, RecipeDetail? Recipe)> DetailCache = new();
        private static readonly TimeSpan CacheTtl = TimeSpan.FromHours(6);

        public static async Task<List<RecipeListItem>> SearchAsync(string query, int count = 12)
        {
            string english = SearchQueryTranslator.ToEnglish(query);
            string key = $"search_{english}_{count}";
            if (TryGetCachedList(key, out var cached)) return cached!;

            string url = $"{BaseUrl}/search.php?s={Uri.EscapeDataString(english)}";
            var list = await ParseMealsAsync(url, count);

            ListCache[key] = (DateTime.UtcNow, list);
            return list;
        }

        public static async Task<List<RecipeListItem>> ByCategoryAsync(string categoryEn, int count = 12)
        {
            string key = $"kat_{categoryEn}_{count}";
            if (TryGetCachedList(key, out var cached)) return cached!;

            string url = $"{BaseUrl}/filter.php?c={Uri.EscapeDataString(categoryEn)}";
            var list = await ParseFilterMealsAsync(url, count, categoryEn);

            ListCache[key] = (DateTime.UtcNow, list);
            return list;
        }

        public static async Task<List<RecipeListItem>> DiscoverAsync(int count = 12)
        {
            string key = $"felf_{count}";
            if (TryGetCachedList(key, out var cached)) return cached!;

            var list = new List<RecipeListItem>();
            var ids = new HashSet<string>();
            int batches = (int)Math.Ceiling(count / 3.0);

            var tasks = Enumerable.Range(0, batches)
                .Select(_ => Http.GetStringAsync($"{BaseUrl}/random.php"))
                .ToList();

            var responses = await Task.WhenAll(tasks);

            foreach (var json in responses)
            {
                using var doc = JsonDocument.Parse(json);
                if (!doc.RootElement.TryGetProperty("meals", out var meals) ||
                    meals.ValueKind != JsonValueKind.Array) continue;

                foreach (var meal in meals.EnumerateArray())
                {
                    var item = ToListItem(meal);
                    if (item != null && ids.Add(item.Id))
                    {
                        list.Add(item);
                        if (list.Count >= count) break;
                    }
                }
                if (list.Count >= count) break;
            }

            await Translator.TranslateTitlesAsync(list);
            ListCache[key] = (DateTime.UtcNow, list);
            return list;
        }

        public static async Task<RecipeDetail?> GetByIdAsync(string recipeId)
        {
            string key = $"reszlet_{recipeId}";
            if (DetailCache.TryGetValue(key, out var c) && DateTime.UtcNow - c.At < CacheTtl)
                return c.Recipe;

            string url = $"{BaseUrl}/lookup.php?i={Uri.EscapeDataString(recipeId)}";
            string json = await Http.GetStringAsync(url);
            using var doc = JsonDocument.Parse(json);

            if (!doc.RootElement.TryGetProperty("meals", out var meals) ||
                meals.ValueKind != JsonValueKind.Array || meals.GetArrayLength() == 0)
                return null;

            var detail = ToDetail(meals[0]);
            if (detail != null)
            {
                detail.Name = await Translator.TranslateAsync(detail.Name);
                detail.Description = await Translator.TranslateLongAsync(detail.Description);
                foreach (var ingredient in detail.Ingredients)
                    ingredient.Name = await Translator.TranslateAsync(ingredient.Name);
            }

            DetailCache[key] = (DateTime.UtcNow, detail);
            return detail;
        }

        public static LoggedFood ToLoggedFood(RecipeDetail recipe, double servings, string mealType)
        {
            return new LoggedFood
            {
                FoodId = $"recept_{recipe.Id}",
                RecipeId = recipe.Id,
                FoodName = recipe.Name,
                FromRecipe = true,
                Servings = servings,
                MealType = mealType,
                ImageUrl = recipe.ImageUrl,
                CaloriesPer100g = recipe.EstimatedCalories,
                ProteinPer100g = recipe.EstimatedProtein,
                CarbsPer100g = recipe.EstimatedCarbs,
                FatPer100g = recipe.EstimatedFat
            };
        }

        public static readonly List<RecipeCategory> Categories =
        [
            new() { Id = "Chicken", Name = "Csirke", Icon = "🍗", SpoonacularQuery = "Chicken" },
            new() { Id = "Beef", Name = "Marhahús", Icon = "🥩", SpoonacularQuery = "Beef" },
            new() { Id = "Seafood", Name = "Tenger gyümölcsei", Icon = "🐟", SpoonacularQuery = "Seafood" },
            new() { Id = "Vegetarian", Name = "Vegetáriánus", Icon = "🥗", SpoonacularQuery = "Vegetarian" },
            new() { Id = "Vegan", Name = "Vegán", Icon = "🌱", SpoonacularQuery = "Vegan" },
            new() { Id = "Pasta", Name = "Tészta", Icon = "🍝", SpoonacularQuery = "Pasta" },
            new() { Id = "Pork", Name = "Sertéshús", Icon = "🥓", SpoonacularQuery = "Pork" },
            new() { Id = "Lamb", Name = "Bárány", Icon = "🍖", SpoonacularQuery = "Lamb" },
            new() { Id = "Breakfast", Name = "Reggeli", Icon = "🥚", SpoonacularQuery = "Breakfast" },
            new() { Id = "Dessert", Name = "Desszert", Icon = "🍰", SpoonacularQuery = "Dessert" },
        ];

        private static (int Kcal, double Protein, double Carbs, double Fat) EstimateNutrition(string category)
        {
            return category.ToLowerInvariant() switch
            {
                "chicken" => (350, 36, 14, 11),
                "beef" => (460, 32, 8, 24),
                "seafood" => (290, 28, 6, 9),
                "pork" => (400, 30, 10, 20),
                "lamb" => (420, 28, 8, 22),
                "pasta" => (430, 16, 58, 11),
                "vegetarian" => (280, 12, 35, 8),
                "vegan" => (250, 10, 40, 6),
                "breakfast" => (320, 15, 32, 12),
                "dessert" => (390, 6, 55, 16),
                "side" => (220, 6, 35, 5),
                _ => (350, 20, 30, 10),
            };
        }

        private static async Task<List<RecipeListItem>> ParseMealsAsync(string url, int count)
        {
            string json = await Http.GetStringAsync(url);
            using var doc = JsonDocument.Parse(json);
            var list = new List<RecipeListItem>();

            if (!doc.RootElement.TryGetProperty("meals", out var meals) ||
                meals.ValueKind != JsonValueKind.Array) return list;

            foreach (var meal in meals.EnumerateArray())
            {
                var item = ToListItem(meal);
                if (item != null) list.Add(item);
                if (list.Count >= count) break;
            }

            await Translator.TranslateTitlesAsync(list);
            return list;
        }

        private static async Task<List<RecipeListItem>> ParseFilterMealsAsync(string url, int count, string category)
        {
            string json = await Http.GetStringAsync(url);
            using var doc = JsonDocument.Parse(json);
            var list = new List<RecipeListItem>();

            if (!doc.RootElement.TryGetProperty("meals", out var meals) ||
                meals.ValueKind != JsonValueKind.Array) return list;

            var (kcal, protein, carbs, fat) = EstimateNutrition(category);

            foreach (var meal in meals.EnumerateArray())
            {
                string id = meal.TryGetProperty("idMeal", out var idEl) ? idEl.GetString() ?? "" : "";
                string name = meal.TryGetProperty("strMeal", out var nameEl) ? nameEl.GetString() ?? "" : "";
                string image = meal.TryGetProperty("strMealThumb", out var imgEl) ? imgEl.GetString() ?? "" : "";

                if (string.IsNullOrWhiteSpace(id)) continue;

                list.Add(new RecipeListItem
                {
                    Id = id,
                    Name = name,
                    ImageUrl = image,
                    Category = CategoryHu(category),
                    EstimatedCalories = kcal,
                    EstimatedProtein = protein,
                    EstimatedCarbs = carbs,
                    EstimatedFat = fat,
                });
                if (list.Count >= count) break;
            }

            await Translator.TranslateTitlesAsync(list);
            return list;
        }

        private static RecipeListItem? ToListItem(JsonElement meal)
        {
            string id = meal.TryGetProperty("idMeal", out var idEl) ? idEl.GetString() ?? "" : "";
            string name = meal.TryGetProperty("strMeal", out var nameEl) ? nameEl.GetString() ?? "" : "";
            string image = meal.TryGetProperty("strMealThumb", out var imgEl) ? imgEl.GetString() ?? "" : "";
            string categoryEn = meal.TryGetProperty("strCategory", out var catEl) ? catEl.GetString() ?? "" : "";

            if (string.IsNullOrWhiteSpace(id)) return null;

            var (kcal, protein, carbs, fat) = EstimateNutrition(categoryEn);

            return new RecipeListItem
            {
                Id = id,
                Name = name,
                ImageUrl = image,
                Category = CategoryHu(categoryEn),
                EstimatedCalories = kcal,
                EstimatedProtein = protein,
                EstimatedCarbs = carbs,
                EstimatedFat = fat,
                Tags = BuildTags(meal, kcal, protein, carbs, fat),
            };
        }

        private static RecipeDetail? ToDetail(JsonElement meal)
        {
            string id = meal.TryGetProperty("idMeal", out var idEl) ? idEl.GetString() ?? "" : "";
            string name = meal.TryGetProperty("strMeal", out var nameEl) ? nameEl.GetString() ?? "" : "";
            string image = meal.TryGetProperty("strMealThumb", out var imgEl) ? imgEl.GetString() ?? "" : "";
            string categoryEn = meal.TryGetProperty("strCategory", out var catEl) ? catEl.GetString() ?? "" : "";
            string area = meal.TryGetProperty("strArea", out var areaEl) ? areaEl.GetString() ?? "" : "";
            string instructions = meal.TryGetProperty("strInstructions", out var instEl) ? instEl.GetString() ?? "" : "";
            string youtube = meal.TryGetProperty("strYoutube", out var ytEl) ? ytEl.GetString() ?? "" : "";

            if (string.IsNullOrWhiteSpace(id)) return null;

            var (kcal, protein, carbs, fat) = EstimateNutrition(categoryEn);

            return new RecipeDetail
            {
                Id = id,
                Name = name,
                ImageUrl = image,
                Category = CategoryHu(categoryEn),
                Origin = AreaHu(area),
                EstimatedCalories = kcal,
                EstimatedProtein = protein,
                EstimatedCarbs = carbs,
                EstimatedFat = fat,
                Description = CleanInstructions(instructions),
                YoutubeUrl = youtube,
                Ingredients = ExtractIngredients(meal),
                Tags = BuildTags(meal, kcal, protein, carbs, fat),
            };
        }

        private static List<RecipeIngredient> ExtractIngredients(JsonElement meal)
        {
            var list = new List<RecipeIngredient>();
            for (int i = 1; i <= 20; i++)
            {
                string nameKey = $"strIngredient{i}";
                string amountKey = $"strMeasure{i}";

                if (!meal.TryGetProperty(nameKey, out var nameEl) ||
                    nameEl.ValueKind != JsonValueKind.String) break;

                string name = nameEl.GetString()?.Trim() ?? "";
                string amount = meal.TryGetProperty(amountKey, out var amountEl) ? amountEl.GetString()?.Trim() ?? "" : "";

                if (string.IsNullOrWhiteSpace(name)) break;

                list.Add(new RecipeIngredient { Name = name, Amount = amount });
            }
            return list;
        }

        private static List<string> BuildTags(JsonElement meal, int kcal, double protein, double carbs, double fat)
        {
            var tags = new List<string>();
            string category = meal.TryGetProperty("strCategory", out var catEl) ? catEl.GetString() ?? "" : "";

            if (protein >= 30) tags.Add("Magas fehérje");
            if (carbs <= 20) tags.Add("Kevés szénhidrát");
            if (fat <= 10) tags.Add("Alacsony zsír");
            if (category.Equals("Vegetarian", StringComparison.OrdinalIgnoreCase)) tags.Add("Vegetáriánus");
            if (category.Equals("Vegan", StringComparison.OrdinalIgnoreCase)) tags.Add("Vegán");
            if (kcal < 300) tags.Add("Alacsony kalória");

            if (meal.TryGetProperty("strTags", out var tagEl) && tagEl.ValueKind == JsonValueKind.String)
            {
                var raw = tagEl.GetString() ?? "";
                foreach (var t in raw.Split(',', StringSplitOptions.RemoveEmptyEntries))
                {
                    var name = t.Trim();
                    if (!string.IsNullOrWhiteSpace(name)) tags.Add(name);
                }
            }

            return tags;
        }

        private static string CleanInstructions(string text)
        {
            if (string.IsNullOrWhiteSpace(text)) return "";
            return text
                .Replace("\r\n", "\n")
                .Replace("\r", "\n")
                .Replace("  ", " ")
                .Trim();
        }

        private static string CategoryHu(string en) => en.ToLowerInvariant() switch
        {
            "chicken" => "Csirke",
            "beef" => "Marhahús",
            "seafood" => "Tenger gyümölcsei",
            "pork" => "Sertéshús",
            "lamb" => "Bárány",
            "pasta" => "Tészta",
            "vegetarian" => "Vegetáriánus",
            "vegan" => "Vegán",
            "breakfast" => "Reggeli",
            "dessert" => "Desszert",
            "side" => "Köret",
            "starter" => "Előétel",
            "goat" => "Kecske",
            "miscellaneous" => "Egyéb",
            _ => en,
        };

        private static string AreaHu(string en) => en.ToLowerInvariant() switch
        {
            "american" => "Amerikai",
            "british" => "Brit",
            "canadian" => "Kanadai",
            "chinese" => "Kínai",
            "french" => "Francia",
            "greek" => "Görög",
            "indian" => "Indiai",
            "italian" => "Olasz",
            "japanese" => "Japán",
            "mexican" => "Mexikói",
            "moroccan" => "Marokkói",
            "spanish" => "Spanyol",
            "thai" => "Thai",
            "turkish" => "Török",
            _ => en,
        };

        private static bool TryGetCachedList(string key, out List<RecipeListItem>? list)
        {
            if (ListCache.TryGetValue(key, out var c) && DateTime.UtcNow - c.At < CacheTtl)
            {
                list = c.Items;
                return true;
            }
            list = null;
            return false;
        }
    }
}
