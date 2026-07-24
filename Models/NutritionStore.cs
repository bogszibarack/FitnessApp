using FitnessBackend.Services;

namespace FitnessBackend.Models
{
    public static class NutritionStore
    {
        public static List<DailyNutritionSession> DailyLogs { get; } = new();

        public static DailyNutritionSession GetOrCreateLog(DateTime date)
        {
            var log = DailyLogs.FirstOrDefault(n => n.Date.Date == date.Date);
            if (log == null)
            {
                log = new DailyNutritionSession { Date = date.Date, TargetCalories = 2200 };
                DailyLogs.Add(log);
            }
            return log;
        }

        public static async Task<(DailyNutritionSession? log, LoggedFood? entry, string? error)>
            AddRecipeAsync(AddRecipeRequest request)
        {
            if (string.IsNullOrWhiteSpace(request.RecipeId))
                return (null, null, "RecipeId kotelezo.");

            if (request.Servings <= 0)
                return (null, null, "Servings kotelezo es nagyobb mint 0.");

            LoggedFood entry;

            if (request.CaloriesPerServing.HasValue && request.CaloriesPerServing.Value > 0)
            {
                entry = new LoggedFood
                {
                    FoodId = request.RecipeId,
                    FoodName = request.RecipeName ?? request.RecipeId,
                    MealType = request.MealType,
                    FromRecipe = true,
                    RecipeId = request.RecipeId,
                    Servings = request.Servings,
                    CaloriesPer100g = request.CaloriesPerServing.Value,
                    ProteinPer100g = request.ProteinPerServing ?? 0,
                    CarbsPer100g = request.CarbsPerServing ?? 0,
                    FatPer100g = request.FatPerServing ?? 0,
                };
            }
            else
            {
                var recipe = await NosaltyApi.GetByIdAsync(request.RecipeId);
                if (recipe == null)
                    return (null, null, "Nincs ilyen recept.");

                entry = NosaltyApi.ToLoggedFood(recipe, request.Servings, request.MealType);
            }

            var log = GetOrCreateLog(DateTime.Today);
            log.EatenFoods.Add(entry);
            DataStore.SaveNutrition();

            return (log, entry, null);
        }
    }
}
