namespace FitnessBackend.Models
{
    public class FoodItem
    {
        public string Id { get; set; } = "";
        public string Name { get; set; } = "";
        public double Calories { get; set; }
        public double Protein { get; set; }
        public double Carbs { get; set; }
        public double Fat { get; set; }
        public string ImageUrl { get; set; } = "";
    }

    public class LoggedFood
    {
        public string FoodId { get; set; } = "";
        public string FoodName { get; set; } = "";
        public double AmountGrams { get; set; }
        public string MealType { get; set; } = "";
        public string ImageUrl { get; set; } = "";

        public bool FromRecipe { get; set; }
        public string RecipeId { get; set; } = "";
        public double Servings { get; set; } = 1;

        public double CaloriesPer100g { get; set; }
        public double ProteinPer100g { get; set; }
        public double CarbsPer100g { get; set; }
        public double FatPer100g { get; set; }

        // Legacy JSON aliases
        public string KepUrl { set => ImageUrl = value; }
        public bool Receptbol { set => FromRecipe = value; }
        public string ReceptId { set => RecipeId = value; }
        public double AdagSzam { set => Servings = value; }

        public double CalculatedCalories => FromRecipe
            ? Math.Round(CaloriesPer100g * Servings, 1)
            : Math.Round((CaloriesPer100g * AmountGrams) / 100.0, 1);

        public double CalculatedProtein => FromRecipe
            ? Math.Round(ProteinPer100g * Servings, 1)
            : Math.Round((ProteinPer100g * AmountGrams) / 100.0, 1);

        public double CalculatedCarbs => FromRecipe
            ? Math.Round(CarbsPer100g * Servings, 1)
            : Math.Round((CarbsPer100g * AmountGrams) / 100.0, 1);

        public double CalculatedFat => FromRecipe
            ? Math.Round(FatPer100g * Servings, 1)
            : Math.Round((FatPer100g * AmountGrams) / 100.0, 1);
    }

    public class DailyNutritionSession
    {
        public string UserName { get; set; } = "";
        public DateTime Date { get; set; } = DateTime.Today;
        public double TargetCalories { get; set; } = 2000;
        public List<LoggedFood> EatenFoods { get; set; } = new();

        public double TotalCalories => Math.Round(EatenFoods.Sum(f => f.CalculatedCalories), 1);
        public double TotalProtein => Math.Round(EatenFoods.Sum(f => f.CalculatedProtein), 1);
        public double TotalCarbs => Math.Round(EatenFoods.Sum(f => f.CalculatedCarbs), 1);
        public double TotalFat => Math.Round(EatenFoods.Sum(f => f.CalculatedFat), 1);
        public double RemainingCalories => Math.Max(0, TargetCalories - TotalCalories);
    }

    /// <summary>User-created reusable food (per 100 g macros).</summary>
    public class CustomFood
    {
        public string Id { get; set; } = "";
        public string UserName { get; set; } = "";
        public string Name { get; set; } = "";
        public double Calories { get; set; }
        public double Protein { get; set; }
        public double Carbs { get; set; }
        public double Fat { get; set; }
        public DateTime CreatedAt { get; set; } = DateTime.UtcNow;

        public FoodItem ToFoodItem() => new()
        {
            Id = Id,
            Name = Name,
            Calories = Calories,
            Protein = Protein,
            Carbs = Carbs,
            Fat = Fat,
        };
    }

    public class CustomFoodRequest
    {
        public string Name { get; set; } = "";
        public double Calories { get; set; }
        public double Protein { get; set; }
        public double Carbs { get; set; }
        public double Fat { get; set; }
    }
}
