namespace FitnessBackend.Models
{
    public static class EdzesTervTarolo
    {
        public static List<Routine> MentettRutinok { get; } = new List<Routine>();

        // User progresszió csúszka beállításai (mentve a telefonról)
        public static ProgresszioBeallitas ProgresszioBeallitas { get; set; } = new ProgresszioBeallitas();
    }
}
