namespace FitnessBackend.Models
{
    // User állítja a frontenden (csúszka) — NEM automatikus
    public class ProgresszioBeallitas
    {
        // "szazalek" vagy "kg" — melyik csúszkát használja
        public string NovelesModja { get; set; } = "szazalek";

        // Csúszka 1: százalékos növelés (0–15%, alapértelmezett 5%)
        public double SulySzazalek { get; set; } = 5.0;

        // Csúszka 2: fix kg növelés (0–10 kg, alapértelmezett 2.5 kg)
        public double SulyKg { get; set; } = 2.5;

        // Extra ismétlés növelés munka sorokra (0–2)
        public int IsmetlesNoveles { get; set; } = 0;
    }

    // Amit a telefon küld: melyik edzésből + aktuális csúszka értékek
    public class KovetkezoHetKeres
    {
        public int ElozoEdzesId { get; set; }
        public ProgresszioBeallitas? CsuszkaBeallitas { get; set; }
    }

    // Előnézet a frontenden: "60 kg → 63 kg" (user látja mielőtt indul)
    public class GyakorlatValtozas
    {
        public string ExerciseName { get; set; } = "";
        public int SorozatSzam { get; set; }
        public bool Bemelegites { get; set; }
        public double RegiSulyKg { get; set; }
        public double UjSulyKg { get; set; }
        public int RegiIsmetles { get; set; }
        public int UjIsmetles { get; set; }
    }

    public class KovetkezoHetValasz
    {
        public WorkoutSession JavasoltEdzes { get; set; } = new WorkoutSession();
        public List<GyakorlatValtozas> Valtozasok { get; set; } = new List<GyakorlatValtozas>();
        public ProgresszioBeallitas HasznaltBeallitas { get; set; } = new ProgresszioBeallitas();
    }
}
