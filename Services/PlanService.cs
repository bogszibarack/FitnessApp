using FitnessBackend.Models;

namespace FitnessBackend.Services
{
    public static class PlanService
    {
        private static readonly string[] PplPushMuscles = { "Chest", "Shoulders", "Triceps" };
        private static readonly string[] PplPullMuscles = { "Lats", "Upper Back", "Traps", "Biceps" };
        private static readonly string[] PplLegsMuscles = { "Quadriceps", "Hamstrings", "Glutes", "Calves" };

        public static async Task<List<Plan>> GenerateAiPlansAsync(AiGenerateRequest request)
        {
            var allExercises = await ExerciseService.GetAllAsync();

            var filtered = FilterExercises(allExercises, request);

            if (filtered.Count < 3)
            {
                filtered = allExercises
                    .Where(g => g.Category.Equals(request.SportCategory, StringComparison.OrdinalIgnoreCase))
                    .ToList();
            }

            if (filtered.Count == 0)
                return new List<Plan>();

            return GenerateVariations(filtered, request);
        }

        public static List<Exercise> FilterExercises(List<Exercise> allExercises, AiGenerateRequest request)
        {
            if (request.SportCategory.Equals("yoga", StringComparison.OrdinalIgnoreCase))
            {
                return allExercises
                    .Where(g => g.Category.Equals("yoga", StringComparison.OrdinalIgnoreCase))
                    .Where(g => LevelMatches(request.Difficulty, g.Level))
                    .ToList();
            }

            var gymExercises = allExercises
                .Where(g => g.Category.Equals("gym", StringComparison.OrdinalIgnoreCase))
                .ToList();

            if (request.TargetMuscle.Equals("Push", StringComparison.OrdinalIgnoreCase))
                return FilterPpl(gymExercises, PplPushMuscles, request);

            if (request.TargetMuscle.Equals("Pull", StringComparison.OrdinalIgnoreCase))
                return FilterPpl(gymExercises, PplPullMuscles, request);

            if (request.TargetMuscle.Equals("Legs", StringComparison.OrdinalIgnoreCase))
                return FilterPpl(gymExercises, PplLegsMuscles, request);

            if (request.TargetMuscle.Equals("Bench", StringComparison.OrdinalIgnoreCase))
                return FilterPowerlifting(gymExercises, new[] { "bench" }, "Chest", request);

            if (request.TargetMuscle.Equals("Squat", StringComparison.OrdinalIgnoreCase))
                return FilterPowerlifting(gymExercises, new[] { "squat" }, "Quadriceps", request);

            if (request.TargetMuscle.Equals("Deadlift", StringComparison.OrdinalIgnoreCase))
                return FilterPowerlifting(gymExercises, new[] { "deadlift" }, "Hamstrings", request);

            return gymExercises
                .Where(g => g.MuscleGroup.Equals(request.TargetMuscle, StringComparison.OrdinalIgnoreCase)
                    || MusclesMatch(request.TargetMuscle, g.MuscleGroup))
                .Where(g => LevelMatches(request.Difficulty, g.Level))
                .ToList();
        }

        private static List<Exercise> FilterPpl(List<Exercise> gymExercises, string[] muscleGroups, AiGenerateRequest request)
        {
            return gymExercises
                .Where(g => muscleGroups.Any(m => g.MuscleGroup.Equals(m, StringComparison.OrdinalIgnoreCase)))
                .Where(g => LevelMatches(request.Difficulty, g.Level))
                .ToList();
        }

        private static List<Exercise> FilterPowerlifting(
            List<Exercise> gymExercises,
            string[] keywords,
            string fallbackMuscle,
            AiGenerateRequest request)
        {
            var mainExercises = gymExercises
                .Where(g => keywords.Any(k => g.Name.Contains(k, StringComparison.OrdinalIgnoreCase)))
                .Where(g => LevelMatches(request.Difficulty, g.Level))
                .ToList();

            if (mainExercises.Count >= 3)
                return mainExercises;

            var supplemental = gymExercises
                .Where(g => g.MuscleGroup.Equals(fallbackMuscle, StringComparison.OrdinalIgnoreCase))
                .Where(g => LevelMatches(request.Difficulty, g.Level))
                .ToList();

            return mainExercises
                .Concat(supplemental)
                .GroupBy(g => g.Id)
                .Select(group => group.First())
                .ToList();
        }

        private static bool MusclesMatch(string requested, string muscleGroup)
        {
            return requested.Equals(muscleGroup, StringComparison.OrdinalIgnoreCase)
                || muscleGroup.Contains(requested, StringComparison.OrdinalIgnoreCase)
                || requested.Contains(muscleGroup, StringComparison.OrdinalIgnoreCase);
        }

        private static bool LevelMatches(string requestedLevel, string? exerciseLevel)
        {
            if (string.IsNullOrWhiteSpace(exerciseLevel)) return true;

            string cleanRequest = requestedLevel.ToLower();
            string cleanExercise = exerciseLevel.ToLower();

            if (cleanRequest == "beginner") return cleanExercise is "beginner" or "intermediate";
            if (cleanRequest == "intermediate") return cleanExercise is "beginner" or "intermediate" or "expert";
            return true;
        }

        private static int ExerciseCountForDifficulty(string difficulty)
        {
            return difficulty.ToLower() switch
            {
                "intermediate" => 5,
                "advanced" or "expert" => 6,
                _ => 4
            };
        }

        public static List<Plan> GenerateVariations(List<Exercise> filteredExercises, AiGenerateRequest request)
        {
            var variations = new List<Plan>();
            var usedIds = new HashSet<string>();
            int exerciseCount = ExerciseCountForDifficulty(request.Difficulty);
            var pplMuscles = PplMuscleGroups(request.TargetMuscle);

            for (int i = 1; i <= 3; i++)
            {
                List<Exercise> selected;

                if (pplMuscles != null)
                {
                    selected = PickBalanced(filteredExercises, pplMuscles, exerciseCount, usedIds);
                }
                else
                {
                    selected = filteredExercises
                        .Where(g => !usedIds.Contains(g.Id))
                        .OrderBy(_ => Random.Shared.Next())
                        .Take(exerciseCount)
                        .ToList();

                    if (selected.Count < exerciseCount)
                    {
                        selected = filteredExercises
                            .OrderBy(_ => Random.Shared.Next())
                            .Take(exerciseCount)
                            .ToList();
                    }
                }

                foreach (var exercise in selected)
                    usedIds.Add(exercise.Id);

                variations.Add(new Plan
                {
                    Id = $"AI_TEMP_{Random.Shared.Next(10000, 99999)}_{i}",
                    CreatorName = "AI Edzesterv",
                    Title = VariationTitle(request, i),
                    Difficulty = request.Difficulty,
                    TargetMuscle = request.TargetMuscle,
                    SportCategory = request.SportCategory,
                    ExerciseIds = selected.Select(g => g.Id).ToList(),
                    ExerciseNames = selected.Select(g => g.Name).ToList()
                });
            }

            return variations;
        }

        private static string[]? PplMuscleGroups(string targetMuscle)
        {
            if (targetMuscle.Equals("Push", StringComparison.OrdinalIgnoreCase)) return PplPushMuscles;
            if (targetMuscle.Equals("Pull", StringComparison.OrdinalIgnoreCase)) return PplPullMuscles;
            if (targetMuscle.Equals("Legs", StringComparison.OrdinalIgnoreCase)) return PplLegsMuscles;
            return null;
        }

        public static List<Exercise> PickBalanced(
            List<Exercise> pool,
            string[] muscleGroups,
            int targetCount,
            HashSet<string> usedIds)
        {
            var selected = new List<Exercise>();
            int perMuscle = Math.Max(1, targetCount / muscleGroups.Length);

            foreach (var muscle in muscleGroups)
            {
                var fromGroup = pool
                    .Where(g => g.MuscleGroup.Equals(muscle, StringComparison.OrdinalIgnoreCase))
                    .Where(g => !usedIds.Contains(g.Id))
                    .Where(g => !selected.Any(v => v.Id == g.Id))
                    .OrderBy(_ => Random.Shared.Next())
                    .Take(perMuscle)
                    .ToList();

                selected.AddRange(fromGroup);
            }

            while (selected.Count < targetCount)
            {
                var extra = pool
                    .Where(g => !usedIds.Contains(g.Id))
                    .Where(g => !selected.Any(v => v.Id == g.Id))
                    .OrderBy(_ => Random.Shared.Next())
                    .FirstOrDefault();

                if (extra == null) break;
                selected.Add(extra);
            }

            return selected.Take(targetCount).ToList();
        }

        private static string VariationTitle(AiGenerateRequest request, int index)
        {
            string letter = char.ConvertFromUtf32(64 + index);

            if (request.SportCategory.Equals("yoga", StringComparison.OrdinalIgnoreCase))
                return $"AI Yoga - Variacio {letter}";

            string label = request.TargetMuscle switch
            {
                "Push" => "Push",
                "Pull" => "Pull",
                "Legs" => "Legs",
                "Bench" => "Powerlifting Bench",
                "Squat" => "Powerlifting Squat",
                "Deadlift" => "Powerlifting Deadlift",
                _ => request.TargetMuscle
            };

            return $"AI {label} - Variacio {letter}";
        }
    }
}
