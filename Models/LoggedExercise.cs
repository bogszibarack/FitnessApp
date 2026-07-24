namespace FitnessBackend.Models
{
    public class LoggedExercise
    {
        public string ExerciseId { get; set; } = "";
        public string ExerciseName { get; set; } = "";
        public List<LoggedSet> Sets { get; set; } = new();
    }

    public class LoggedSet
    {
        public int SetNumber { get; set; }
        public bool IsWarmup { get; set; }
        public double Weight { get; set; }
        public int Reps { get; set; }
        public string TargetReps { get; set; } = "";
        public int Rpe { get; set; }
        public bool IsDone { get; set; }
        public double PrevWeightKg { get; set; }
        public int PrevReps { get; set; }
    }
}
