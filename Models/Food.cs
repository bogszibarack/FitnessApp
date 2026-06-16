namespace FitnessBackend.Models
{
    // Egy konkrét étel vagy alapanyag adatai (100g-ra vonatkoztatva)
    public class FoodItem
    {
        public string Id { get; set; } = "";
        public string Name { get; set; } = "";
        public double Calories { get; set; }     // Kalória (kcal)
        public double Protein { get; set; }      // Fehérje (g)
        public double Carbs { get; set; }        // Szénhidrát (g)
        public double Fat { get; set; }          // Zsír (g)
        public string ImageUrl { get; set; } = ""; // Az étel képe
    }

    // Egy olyan bejegyzés, amit a júzer ténylegesen megevett
    public class LoggedFood
    {
        public string FoodId { get; set; } = "";
        public string FoodName { get; set; } = "";
        public double AmountGrams { get; set; }       // Gramm (Open Food Facts ételnél)
        public string MealType { get; set; } = "";     // reggeli / ebed / vacsora / nasi
        public string KepUrl { get; set; } = "";

        // Receptből jött-e (TheMealDB)
        public bool Receptbol { get; set; }
        public string ReceptId { get; set; } = "";
        public double AdagSzam { get; set; } = 1;      // Pl. 0.5 = fél adag, 2 = két adag

        // 100g-ra vetített értékek (OFF) VAGY 1 adagra vetített (recept)
        public double CaloriesPer100g { get; set; }
        public double ProteinPer100g { get; set; }
        public double CarbsPer100g { get; set; }
        public double FatPer100g { get; set; }

        public double CalculatedCalories => Receptbol
            ? Math.Round(CaloriesPer100g * AdagSzam, 1)
            : Math.Round((CaloriesPer100g * AmountGrams) / 100.0, 1);

        public double CalculatedProtein => Receptbol
            ? Math.Round(ProteinPer100g * AdagSzam, 1)
            : Math.Round((ProteinPer100g * AmountGrams) / 100.0, 1);

        public double CalculatedCarbs => Receptbol
            ? Math.Round(CarbsPer100g * AdagSzam, 1)
            : Math.Round((CarbsPer100g * AmountGrams) / 100.0, 1);

        public double CalculatedFat => Receptbol
            ? Math.Round(FatPer100g * AdagSzam, 1)
            : Math.Round((FatPer100g * AmountGrams) / 100.0, 1);
    }

    // Egy teljes nap étkezési összesítése (Ez a Yazio főképernyője)
    public class DailyNutritionSession
    {
        public DateTime Date { get; set; } = DateTime.Today;
        public double TargetCalories { get; set; } = 2000; // A kalkulátor által számolt cél
        public List<LoggedFood> EatenFoods { get; set; } = new List<LoggedFood>();

        // Élőben összegzi a nap folyamán bevitt makrókat (mint a Yazio körei felül)
        public double TotalCalories => Math.Round(EatenFoods.Sum(f => f.CalculatedCalories), 1);
        public double TotalProtein => Math.Round(EatenFoods.Sum(f => f.CalculatedProtein), 1);
        public double TotalCarbs => Math.Round(EatenFoods.Sum(f => f.CalculatedCarbs), 1);
        public double TotalFat => Math.Round(EatenFoods.Sum(f => f.CalculatedFat), 1);
        public double RemainingCalories => Math.Max(0, TargetCalories - TotalCalories);
    }
}