namespace FitnessBackend.Models
{
    public class Routine
    {
        public string Id { get; set; } = "";
        public string CreatorName { get; set; } = "Anonim";
        public string Title { get; set; } = "";
        public string Difficulty { get; set; } = "beginner";
        public string TargetMuscle { get; set; } = "";
        public string SportCategory { get; set; } = "gym";

        // Valódi gyakorlat ID-k (összekötés az Exercise API-val)
        public List<string> ExerciseIds { get; set; } = new List<string>();

        // Megjelenítéshez (Hevy: "Bench Press, Shoulder Press...")
        public List<string> ExerciseNames { get; set; } = new List<string>();

        // Közösségi posztból mentve: teljes gyakorlat + sorozat sablon
        public List<LoggedExercise> GyakorlatSablonok { get; set; } = new List<LoggedExercise>();
        public string ForrasPostId { get; set; } = "";

        public static Routine LetrehozasKozossegPosztbol(CommunityPost poszt, string userName)
        {
            var sablonok = poszt.Edzes.Exercises
                .Select(gyakorlat => new LoggedExercise
                {
                    ExerciseId = gyakorlat.ExerciseId,
                    ExerciseName = gyakorlat.ExerciseName,
                    Sets = gyakorlat.Sets
                        .Select(sorozat => new LoggedSet
                        {
                            SetNumber = sorozat.SetNumber,
                            Bemelegites = sorozat.Bemelegites,
                            Weight = sorozat.Weight,
                            Reps = sorozat.Reps,
                            CelIsmetles = sorozat.CelIsmetles,
                            Rpe = sorozat.Rpe,
                            Elvegezve = sorozat.Elvegezve,
                            ElozoSulyKg = sorozat.ElozoSulyKg,
                            ElozoIsmetles = sorozat.ElozoIsmetles
                        })
                        .ToList()
                })
                .ToList();

            return new Routine
            {
                Id = $"rutin_{Random.Shared.Next(100000, 999999)}",
                CreatorName = string.IsNullOrWhiteSpace(userName) ? "Sajat terv" : userName,
                Title = $"{poszt.UserName} edzese - {poszt.Megye}",
                Difficulty = "beginner",
                TargetMuscle = "Full Body",
                SportCategory = "gym",
                ExerciseIds = sablonok.Select(g => g.ExerciseId).ToList(),
                ExerciseNames = sablonok.Select(g => g.ExerciseName).ToList(),
                GyakorlatSablonok = sablonok,
                ForrasPostId = poszt.Id
            };
        }

        public static List<LoggedExercise> GyakorlatokInditashoz(Routine rutin)
        {
            if (rutin.GyakorlatSablonok.Count == 0)
            {
                return rutin.ExerciseIds.Select((id, index) => new LoggedExercise
                {
                    ExerciseId = id,
                    ExerciseName = index < rutin.ExerciseNames.Count ? rutin.ExerciseNames[index] : id,
                    Sets = new List<LoggedSet>()
                }).ToList();
            }

            return rutin.GyakorlatSablonok.Select(sablon => new LoggedExercise
            {
                ExerciseId = sablon.ExerciseId,
                ExerciseName = sablon.ExerciseName,
                Sets = sablon.Sets.Select(sorozat => new LoggedSet
                {
                    SetNumber = sorozat.SetNumber,
                    Bemelegites = sorozat.Bemelegites,
                    Weight = 0,
                    Reps = 0,
                    CelIsmetles = SorozatCelMeghatarozasa(sorozat),
                    Rpe = 0,
                    Elvegezve = false,
                    ElozoSulyKg = sorozat.Elvegezve ? sorozat.Weight : sorozat.ElozoSulyKg,
                    ElozoIsmetles = sorozat.Elvegezve ? sorozat.Reps : sorozat.ElozoIsmetles
                }).ToList()
            }).ToList();
        }

        private static string SorozatCelMeghatarozasa(LoggedSet sorozat)
        {
            if (!string.IsNullOrWhiteSpace(sorozat.CelIsmetles))
            {
                return sorozat.CelIsmetles;
            }

            if (sorozat.Elvegezve && sorozat.Reps > 0)
            {
                return sorozat.Reps.ToString();
            }

            return "10-12";
        }
    }

    // Amit a user kiválaszt a telefonon (nehézség + izom + sportág)
    public class AiGeneraloKeres
    {
        public string Difficulty { get; set; } = "beginner";
        public string TargetMuscle { get; set; } = "Chest";
        public string SportCategory { get; set; } = "gym";
    }
}
