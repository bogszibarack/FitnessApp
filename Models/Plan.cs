namespace FitnessBackend.Models
{
    public class Plan
    {
        public string Id { get; set; } = "";
        public string CreatorName { get; set; } = "Anonim";
        public string Title { get; set; } = "";
        public string Difficulty { get; set; } = "beginner";
        public string TargetMuscle { get; set; } = "";
        public string SportCategory { get; set; } = "gym";
        public List<string> ExerciseIds { get; set; } = new();
        public List<string> ExerciseNames { get; set; } = new();
        public List<LoggedExercise> ExerciseTemplates { get; set; } = new();
        public string SourcePostId { get; set; } = "";

        public static Plan FromCommunityPost(CommunityPost post, string userName)
        {
            var templates = post.Workout.Exercises
                .Select(exercise => new LoggedExercise
                {
                    ExerciseId = exercise.ExerciseId,
                    ExerciseName = exercise.ExerciseName,
                    Sets = exercise.Sets
                        .Select(set => new LoggedSet
                        {
                            SetNumber = set.SetNumber,
                            IsWarmup = set.IsWarmup,
                            Weight = set.Weight,
                            Reps = set.Reps,
                            TargetReps = set.TargetReps,
                            Rpe = set.Rpe,
                            IsDone = set.IsDone,
                            PrevWeightKg = set.PrevWeightKg,
                            PrevReps = set.PrevReps
                        })
                        .ToList()
                })
                .ToList();

            return new Plan
            {
                Id = $"plan_{Random.Shared.Next(100000, 999999)}",
                CreatorName = string.IsNullOrWhiteSpace(userName) ? "Sajat terv" : userName,
                Title = $"{post.UserName} edzese - {post.County}",
                Difficulty = "beginner",
                TargetMuscle = "Full Body",
                SportCategory = "gym",
                ExerciseIds = templates.Select(g => g.ExerciseId).ToList(),
                ExerciseNames = templates.Select(g => g.ExerciseName).ToList(),
                ExerciseTemplates = templates,
                SourcePostId = post.Id
            };
        }

        public static List<LoggedExercise> ExercisesForStart(Plan plan)
        {
            if (plan.ExerciseTemplates.Count == 0)
            {
                return plan.ExerciseIds.Select((id, index) => new LoggedExercise
                {
                    ExerciseId = id,
                    ExerciseName = index < plan.ExerciseNames.Count ? plan.ExerciseNames[index] : id,
                    Sets = new List<LoggedSet>()
                }).ToList();
            }

            return plan.ExerciseTemplates.Select(template => new LoggedExercise
            {
                ExerciseId = template.ExerciseId,
                ExerciseName = template.ExerciseName,
                Sets = template.Sets.Select(set => new LoggedSet
                {
                    SetNumber = set.SetNumber,
                    IsWarmup = set.IsWarmup,
                    Weight = set.Weight,
                    Reps = set.Reps,
                    TargetReps = set.TargetReps.Length > 0 ? set.TargetReps : ResolveTargetReps(set),
                    Rpe = 0,
                    IsDone = false,
                    PrevWeightKg = set.PrevWeightKg,
                    PrevReps = set.PrevReps
                }).ToList()
            }).ToList();
        }

        private static string ResolveTargetReps(LoggedSet set)
        {
            if (!string.IsNullOrWhiteSpace(set.TargetReps))
                return set.TargetReps;

            if (set.IsDone && set.Reps > 0)
                return set.Reps.ToString();

            return "10-12";
        }
    }

    public class AiGenerateRequest
    {
        public string Difficulty { get; set; } = "beginner";
        public string TargetMuscle { get; set; } = "Chest";
        public string SportCategory { get; set; } = "gym";
    }
}
