namespace FitnessBackend.Services
{
    /// <summary>Spoonacular config — kept but no longer primary recipe source.</summary>
    public static class SpoonacularConfig
    {
        public static string ApiKey { get; set; } = "";
        public const string BaseUrl = "https://api.spoonacular.com";
        public static bool HasKey => !string.IsNullOrWhiteSpace(ApiKey);
    }
}
