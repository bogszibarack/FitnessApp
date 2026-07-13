namespace FitnessBackend.Models
{
    public class Exercise
    {
        public required string Id { get; set; }
        public required string Name { get; set; }
        public string? Force { get; set; }
        public string? Level { get; set; }
        public string? Mechanic { get; set; }
        public string? Equipment { get; set; }
        public string MuscleGroup { get; set; } = "";
        public List<string> PrimaryMuscles { get; set; } = [];
        public List<string> SecondaryMuscles { get; set; } = [];
        public List<string> Instructions { get; set; } = [];
        public string? Category { get; set; }
        public List<string> Images { get; set; } = [];
    }
}