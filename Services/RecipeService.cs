using FitnessBackend.Models;

namespace FitnessBackend.Services
{
    public static class RecipeService
    {
        public static readonly List<CalorieRange> CalorieBands =
        [
            new() { Min = 0, Max = 250, Name = "0-250 kcal" },
            new() { Min = 250, Max = 350, Name = "250-350 kcal" },
            new() { Min = 350, Max = 450, Name = "350-450 kcal" },
            new() { Min = 450, Max = 600, Name = "450-600 kcal" },
        ];

        public static List<RecipeCategory> Categories => NosaltyApi.Categories;

        public static async Task<List<RecipeListItem>> SearchAsync(string query)
        {
            try
            {
                return await NosaltyApi.SearchAsync(query);
            }
            catch
            {
                return [];
            }
        }

        public static async Task<(List<RecipeListItem>? Items, string? Error)> ByCategoryAsync(string categoryId)
        {
            var category = NosaltyApi.Categories.FirstOrDefault(k =>
                k.Id.Equals(categoryId, StringComparison.OrdinalIgnoreCase));

            if (category == null)
                return (null, $"Ismeretlen kategoria: {categoryId}");

            try
            {
                return (await NosaltyApi.ByCategoryAsync(category.Id), null);
            }
            catch
            {
                return ([], null);
            }
        }

        public static async Task<List<RecipeListItem>> ByCaloriesAsync(int min, int max)
        {
            try
            {
                return await NosaltyApi.ByCaloriesAsync(min, max);
            }
            catch
            {
                return [];
            }
        }

        public static async Task<List<RecipeListItem>> DiscoverAsync(int count = 12)
        {
            try
            {
                return await NosaltyApi.DiscoverAsync(count);
            }
            catch
            {
                return [];
            }
        }

        public static List<RecipeListItem> Favorites => RecipeStore.Favorites;

        public static async Task<(RecipeListItem? Item, string? Error)> AddFavoriteAsync(string recipeId)
        {
            var existing = RecipeStore.Favorites.FirstOrDefault(r => r.Id == recipeId);
            if (existing != null)
                return (existing, null);

            var detailed = await NosaltyApi.GetByIdAsync(recipeId);
            if (detailed == null)
                return (null, "Nincs ilyen recept.");

            RecipeStore.Favorites.Add(detailed);
            return (detailed, null);
        }

        public static (string? Message, string? Error) RemoveFavorite(string recipeId)
        {
            var item = RecipeStore.Favorites.FirstOrDefault(r => r.Id == recipeId);
            if (item == null)
                return (null, "Nincs a kedvencek kozott.");

            RecipeStore.Favorites.Remove(item);
            return ($"Kedvenc torolve: {item.Name}", null);
        }

        public static async Task<(object? Result, string? Error)> AddToLogAsync(
            string userName, string recipeId, AddRecipeRequest request)
        {
            if (string.IsNullOrWhiteSpace(userName))
                return (null, "Bejelentkezes szukseges.");

            request.RecipeId = recipeId;
            var (log, entry, err) = await NutritionStore.AddRecipeAsync(userName, request);
            if (err != null)
                return (null, err);

            return (new
            {
                message = $"Recept hozzaadva: {entry?.FoodName}",
                added = entry,
                log,
                uzenet = $"Recept hozzaadva: {entry?.FoodName}",
                hozzaadott = entry,
                mai_naplo = log
            }, null);
        }

        public static async Task<(RecipeDetail? Recipe, string? Error)> GetByIdAsync(string recipeId)
        {
            try
            {
                var recipe = await NosaltyApi.GetByIdAsync(recipeId);
                if (recipe == null)
                    return (null, "Nincs ilyen recept.");
                return (recipe, null);
            }
            catch
            {
                return (null, "A recept nem elerheto.");
            }
        }
    }
}
