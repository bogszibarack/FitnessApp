namespace FitnessBackend.Models
{
    // Recipe list card (Yazio-style home cards)
    public class RecipeListItem
    {
        public string Id { get; set; } = "";
        public string Name { get; set; } = "";
        public string Category { get; set; } = "";
        public string ImageUrl { get; set; } = "";
        public int EstimatedCalories { get; set; }
        public int IngredientCount { get; set; }
        public double EstimatedProtein { get; set; }
        public double EstimatedCarbs { get; set; }
        public double EstimatedFat { get; set; }
        public bool QuickToMake { get; set; }
        public List<string> Tags { get; set; } = new();
        public List<string> YazioTags { get; set; } = new();

        // Legacy JSON aliases (incoming only)
        public string Nev { set => Name = value; }
        public string Kategoria { set => Category = value; }
        public string KepUrl { set => ImageUrl = value; }
        public int BecsultKaloria { set => EstimatedCalories = value; }
        public int HozzavaloSzam { set => IngredientCount = value; }
        public double BecsultFeherje { set => EstimatedProtein = value; }
        public double BecsultSzenhidrat { set => EstimatedCarbs = value; }
        public double BecsultZsir { set => EstimatedFat = value; }
        public bool GyorsElkeszitheto { set => QuickToMake = value; }
        public List<string> Cimkek { set => Tags = value; }
        public List<string> YazioCimkek { set => YazioTags = value; }
    }

    // Recipe detail page
    public class RecipeDetail : RecipeListItem
    {
        public string Description { get; set; } = "";
        public string YoutubeUrl { get; set; } = "";
        public string Origin { get; set; } = "";
        public List<RecipeIngredient> Ingredients { get; set; } = new();

        public string Leiras { set => Description = value; }
        public string SzarmazasiTerulet { set => Origin = value; }
        public List<RecipeIngredient> Osszetevok { set => Ingredients = value; }
    }

    public class RecipeIngredient
    {
        public string Name { get; set; } = "";
        public string Amount { get; set; } = "";

        public string Nev { set => Name = value; }
        public string Mennyiseg { set => Amount = value; }
    }

    public class RecipeCategory
    {
        public string Id { get; set; } = "";
        public string Name { get; set; } = "";
        public string Icon { get; set; } = "";

        public string Nev { set => Name = value; }
        public string Ikon { set => Icon = value; }
    }

    public class CalorieRange
    {
        public int Min { get; set; }
        public int Max { get; set; }
        public string Name { get; set; } = "";

        public string Nev { set => Name = value; }
    }

    public static class RecipeStore
    {
        public static List<RecipeListItem> Favorites { get; } = new();
    }

    // Add recipe to nutrition log
    public class AddRecipeRequest
    {
        public string RecipeId { get; set; } = "";
        public double Servings { get; set; } = 1;
        public string MealType { get; set; } = "reggeli";
        public string? RecipeName { get; set; }
        public double? CaloriesPerServing { get; set; }
        public double? ProteinPerServing { get; set; }
        public double? CarbsPerServing { get; set; }
        public double? FatPerServing { get; set; }

        // Legacy JSON aliases
        public string ReceptId { set => RecipeId = value; }
        public double AdagSzam { set => Servings = value; }
        public string EtkezesTipus { set => MealType = value; }
        public string? ReceptNev { set => RecipeName = value; }
        public double? KaloriaAdagonkent { set => CaloriesPerServing = value; }
        public double? FeherjeAdagonkent { set => ProteinPerServing = value; }
        public double? SzenhidratAdagonkent { set => CarbsPerServing = value; }
        public double? ZsirAdagonkent { set => FatPerServing = value; }
    }
}
