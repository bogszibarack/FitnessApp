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

        /// <summary>Stable id from Strava/Health for dedupe on re-sync.</summary>
        public string ExternalId { get; set; } = "";
        /// <summary>strava | apple_health | health_connect | watch</summary>
        public string ExternalSource { get; set; } = "";
        public double? DistanceKm { get; set; }
        public string ActivityType { get; set; } = "";

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

    public class ExternalWorkoutImportRequest
    {
        public List<ExternalWorkoutImportItem> Items { get; set; } = new();
    }

    public class ExternalWorkoutImportItem
    {
        public string ExternalId { get; set; } = "";
        public string Source { get; set; } = "";
        public string Title { get; set; } = "";
        public DateTime? StartTime { get; set; }
        public int DurationSeconds { get; set; }
        public double? DistanceKm { get; set; }
        public string? ActivityType { get; set; }
    }
}
