namespace FitnessBackend.Models
{
    public static class PlanStore
    {
        public static List<Plan> SavedPlans { get; } = new();
        public static ProgressSettings Progress { get; set; } = new();
    }
}
