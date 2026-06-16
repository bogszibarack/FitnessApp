namespace FitnessBackend.Models
{
    public class Exercise
    {
        public string Id { get; set; } // Itt most string lett, mert szöveg az ID (pl. "Alternate_Incline_Dumbbell_Curl")
        public string Name { get; set; }
        public string Force { get; set; } // pull / push
        public string Level { get; set; } // beginner / intermediate
        public string Mechanic { get; set; } // isolation / compound
        public string Equipment { get; set; } // Hevy: Barbell, Dumbbell, None...
        public string MuscleGroup { get; set; } = ""; // Hevy: Chest, Biceps, Full Body...
        
        // C#-ban a JSON tömbökből (mint a ["biceps"]) listák lesznek:
        public List<string> PrimaryMuscles { get; set; } = new List<string>();
        public List<string> SecondaryMuscles { get; set; } = new List<string>();
        public List<string> Instructions { get; set; } = new List<string>();
        
        public string Category { get; set; } // strength / cardio
        public List<string> Images { get; set; } = new List<string>();
    }
}