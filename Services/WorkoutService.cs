using FitnessBackend.Models;

namespace FitnessBackend.Services
{
    public static class WorkoutService
    {
        public static List<LoggedSet> CreateDefaultSets(string difficulty)
        {
            var sets = new List<LoggedSet>();
            int setCounter = 1;

            sets.Add(new LoggedSet
            {
                SetNumber = setCounter++,
                IsWarmup = true,
                Weight = 0,
                TargetReps = "10",
                IsDone = false
            });

            sets.Add(new LoggedSet
            {
                SetNumber = setCounter++,
                IsWarmup = true,
                Weight = 0,
                TargetReps = "4-6",
                IsDone = false
            });

            int workingSets = difficulty.ToLower() switch
            {
                "intermediate" => 3,
                "advanced" or "expert" => 4,
                _ => 2
            };

            for (int i = 1; i <= workingSets; i++)
            {
                sets.Add(new LoggedSet
                {
                    SetNumber = setCounter++,
                    IsWarmup = false,
                    TargetReps = "10-12",
                    IsDone = false
                });
            }

            return sets;
        }

        public static void FillPreviousData(LoggedExercise exercise, List<WorkoutSession> workoutHistory)
        {
            var previousExercise = workoutHistory
                .OrderByDescending(session => session.StartTime)
                .SelectMany(session => session.Exercises)
                .FirstOrDefault(g => g.ExerciseId == exercise.ExerciseId);

            if (previousExercise == null) return;

            foreach (var set in exercise.Sets)
            {
                var previousSet = previousExercise.Sets.FirstOrDefault(s =>
                    s.SetNumber == set.SetNumber && s.IsWarmup == set.IsWarmup);

                if (previousSet != null && previousSet.IsDone)
                {
                    set.PrevWeightKg = previousSet.Weight;
                    set.PrevReps = previousSet.Reps;
                }
            }
        }

        public static NextWeekResponse GenerateNextWeek(WorkoutSession previousWorkout, ProgressSettings settings)
        {
            var changes = new List<ExerciseChange>();
            var newExercises = new List<LoggedExercise>();

            foreach (var previousExercise in previousWorkout.Exercises)
            {
                var newExercise = new LoggedExercise
                {
                    ExerciseId = previousExercise.ExerciseId,
                    ExerciseName = previousExercise.ExerciseName,
                    Sets = new List<LoggedSet>()
                };

                foreach (var previousSet in previousExercise.Sets)
                {
                    double newWeight = previousSet.Weight;
                    int newReps = previousSet.Reps;

                    if (!previousSet.IsWarmup && previousSet.IsDone)
                    {
                        newWeight = CalculateNewWeight(previousSet.Weight, settings);
                        newReps = previousSet.Reps + settings.RepBoost;
                    }

                    newExercise.Sets.Add(new LoggedSet
                    {
                        SetNumber = previousSet.SetNumber,
                        IsWarmup = previousSet.IsWarmup,
                        Weight = newWeight,
                        Reps = 0,
                        TargetReps = newReps > 0 ? newReps.ToString() : previousSet.TargetReps,
                        IsDone = false,
                        PrevWeightKg = previousSet.Weight,
                        PrevReps = previousSet.Reps
                    });

                    if (!previousSet.IsWarmup && previousSet.IsDone)
                    {
                        changes.Add(new ExerciseChange
                        {
                            ExerciseName = previousExercise.ExerciseName,
                            SetNumber = previousSet.SetNumber,
                            IsWarmup = previousSet.IsWarmup,
                            OldWeightKg = previousSet.Weight,
                            NewWeightKg = newWeight,
                            OldReps = previousSet.Reps,
                            NewReps = newReps
                        });
                    }
                }

                newExercises.Add(newExercise);
            }

            return new NextWeekResponse
            {
                SuggestedWorkout = new WorkoutSession
                {
                    Title = $"{previousWorkout.Title} (Kovetkezo het)",
                    Exercises = newExercises
                },
                Changes = changes,
                UsedSettings = settings
            };
        }

        public static double CalculateNewWeight(double oldWeight, ProgressSettings settings)
        {
            double newWeight = settings.Mode == "kg"
                ? oldWeight + settings.Kg
                : oldWeight * (1 + settings.Percent / 100.0);

            return RoundTo2Point5Kg(Math.Max(0, newWeight));
        }

        private static double RoundTo2Point5Kg(double weight)
        {
            return Math.Round(weight / 2.5) * 2.5;
        }
    }
}
