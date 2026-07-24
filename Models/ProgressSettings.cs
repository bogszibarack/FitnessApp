namespace FitnessBackend.Models
{
    public class ProgressSettings
    {
        public string Mode { get; set; } = "szazalek";
        public double Percent { get; set; } = 5.0;
        public double Kg { get; set; } = 2.5;
        public int RepBoost { get; set; } = 0;
    }

    public class NextWeekRequest
    {
        public int PreviousWorkoutId { get; set; }
        public ProgressSettings? ProgressSettings { get; set; }
    }

    public class ExerciseChange
    {
        public string ExerciseName { get; set; } = "";
        public int SetNumber { get; set; }
        public bool IsWarmup { get; set; }
        public double OldWeightKg { get; set; }
        public double NewWeightKg { get; set; }
        public int OldReps { get; set; }
        public int NewReps { get; set; }
    }

    public class NextWeekResponse
    {
        public WorkoutSession SuggestedWorkout { get; set; } = new();
        public List<ExerciseChange> Changes { get; set; } = new();
        public ProgressSettings UsedSettings { get; set; } = new();
    }
}
