namespace FitnessBackend.Models
{
    public class WorkoutSession
    {
        public int Id { get; set; }
        public string Title { get; set; } = "Empty Workout";
        public DateTime StartTime { get; set; }
        public int DurationSeconds { get; set; }
        public bool IsActive { get; set; }

        // Egy edzésen belül sok elvégzett gyakorlat van (Hevy: Log Workout lista)
        public List<LoggedExercise> Exercises { get; set; } = new List<LoggedExercise>();

        // Hevy fejléc: csak a pipált (elvégzett) sorok számítanak
        public double OsszTomegKg => Exercises
            .SelectMany(gyakorlat => gyakorlat.Sets)
            .Where(sorozat => sorozat.Elvegezve)
            .Sum(sorozat => sorozat.Weight * sorozat.Reps);

        public int OsszSorozatSzam => Exercises
            .SelectMany(gyakorlat => gyakorlat.Sets)
            .Count(sorozat => sorozat.Elvegezve);

        // Futó stopper: hány másodperc telt el a kezdés óta
        public int ElteltMasodperc => StartTime == DateTime.MinValue
            ? 0
            : (int)(DateTime.Now - StartTime).TotalSeconds;
    }
}