namespace FitnessBackend.Models
{
    public class WorkoutSession
    {
        public int Id { get; set; }
        /// <summary>Owner username from JWT (empty = legacy pre–Phase 2 data).</summary>
        public string UserName { get; set; } = "";
        public string Title { get; set; } = "Empty Workout";
        public DateTime StartTime { get; set; }
        public int DurationSeconds { get; set; }
        public bool IsActive { get; set; }
        public List<LoggedExercise> Exercises { get; set; } = new();

        public double TotalVolumeKg => Exercises
            .SelectMany(exercise => exercise.Sets)
            .Where(set => set.IsDone)
            .Sum(set => set.Weight * set.Reps);

        public int CompletedSets => Exercises
            .SelectMany(exercise => exercise.Sets)
            .Count(set => set.IsDone);

        public int ElapsedSeconds => StartTime == DateTime.MinValue
            ? 0
            : (int)(DateTime.Now - StartTime).TotalSeconds;
    }
}
