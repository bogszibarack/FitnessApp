namespace FitnessBackend.Models
{
    // A telefon küldi, ha az edzés nevét akarja átírni (pl. "Empty Workout" → "Mell edzés")
    public class EdzesModositasKeres
    {
        public string Title { get; set; } = "";
    }
}
