using FitnessBackend.Services;

namespace FitnessBackend.Models
{
    public static class NutritionStore
    {
        public static List<DailyNutritionSession> DailyLogs { get; } = new();
        public static List<CustomFood> CustomFoods { get; } = new();

        public static DailyNutritionSession GetOrCreateLog(string userName, DateTime date)
        {
            var key = (userName ?? "").Trim();
            var log = DailyLogs.FirstOrDefault(n =>
                n.Date.Date == date.Date &&
                n.UserName.Equals(key, StringComparison.OrdinalIgnoreCase));
            if (log == null)
            {
                log = new DailyNutritionSession
                {
                    UserName = key,
                    Date = date.Date,
                    TargetCalories = 2200,
                };
                DailyLogs.Add(log);
            }
            else if (string.IsNullOrWhiteSpace(log.UserName))
            {
                log.UserName = key;
            }
            return log;
        }

        /// <summary>One-time: attach orphan (empty UserName) logs to an owner.</summary>
        public static int AssignLegacyOwner(string userName)
        {
            var key = userName.Trim();
            if (string.IsNullOrEmpty(key)) return 0;
            var n = 0;
            foreach (var log in DailyLogs.Where(l => string.IsNullOrWhiteSpace(l.UserName)))
            {
                log.UserName = key;
                n++;
            }
            if (n > 0) DataStore.SaveNutrition();
            return n;
        }

        public static List<CustomFood> ListCustomFoods(string userName) =>
            CustomFoods
                .Where(f => f.UserName.Equals(userName.Trim(), StringComparison.OrdinalIgnoreCase))
                .OrderByDescending(f => f.CreatedAt)
                .ToList();

        public static CustomFood? AddCustomFood(string userName, CustomFoodRequest request)
        {
            if (string.IsNullOrWhiteSpace(request.Name)) return null;
            if (request.Calories < 0 || request.Protein < 0 || request.Carbs < 0 || request.Fat < 0)
                return null;

            var food = new CustomFood
            {
                Id = $"custom_{Guid.NewGuid():N}",
                UserName = userName.Trim(),
                Name = request.Name.Trim(),
                Calories = Math.Round(request.Calories, 1),
                Protein = Math.Round(request.Protein, 1),
                Carbs = Math.Round(request.Carbs, 1),
                Fat = Math.Round(request.Fat, 1),
                CreatedAt = DateTime.UtcNow,
            };
            CustomFoods.Add(food);
            DataStore.SaveCustomFoods();
            return food;
        }

        public static bool DeleteCustomFood(string userName, string foodId)
        {
            var item = CustomFoods.FirstOrDefault(f =>
                f.Id == foodId &&
                f.UserName.Equals(userName.Trim(), StringComparison.OrdinalIgnoreCase));
            if (item == null) return false;
            CustomFoods.Remove(item);
            DataStore.SaveCustomFoods();
            return true;
        }

        public static async Task<(DailyNutritionSession? log, LoggedFood? entry, string? error)>
            AddRecipeAsync(string userName, AddRecipeRequest request)
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

            var log = GetOrCreateLog(userName, DateTime.Today);
            log.EatenFoods.Add(entry);
            DataStore.SaveNutrition();

            return (log, entry, null);
        }
    }
}
