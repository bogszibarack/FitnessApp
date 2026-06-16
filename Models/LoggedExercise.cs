namespace FitnessBackend.Models
{
    public class LoggedExercise
    {
        public string ExerciseId { get; set; } = "";
        public string ExerciseName { get; set; } = "";
        public List<LoggedSet> Sets { get; set; } = new List<LoggedSet>();
    }

    // Egy széria sora (Hevy: SET | PREVIOUS | KG | REPS | pipa)
    public class LoggedSet
    {
        public int SetNumber { get; set; }           // Munka sor: 1, 2, 3...
        public bool Bemelegites { get; set; }        // true = "W" sor a képernyőn
        public double Weight { get; set; }           // KG oszlop
        public int Reps { get; set; }              // REPS oszlop (kitöltött érték)
        public string CelIsmetles { get; set; } = ""; // Cél: pl. "10-12" (szürke, még nincs kitöltve)
        public int Rpe { get; set; }
        public bool Elvegezve { get; set; }          // Pipa: true = zöld pipa ✓

        // PREVIOUS oszlop — előző edzésből
        public double ElozoSulyKg { get; set; }
        public int ElozoIsmetles { get; set; }
    }
}
