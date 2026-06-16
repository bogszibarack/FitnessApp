using Microsoft.AspNetCore.Mvc;
using System.Text.Json;
using FitnessBackend.Models;

namespace FitnessBackend.Controllers
{
    [ApiController]
    [Route("api/[controller]")]
    public class ExerciseController : ControllerBase
    {
        // Egy nagy lista: gym + yoga + hyrox + pilates (minden sportág itt van)
        private static List<Exercise> osszes_gyakorlat = new List<Exercise>();

        // --- API címek (ahonnan letöltjük az adatokat) ---
        private const string gym_json_url = "https://raw.githubusercontent.com/yuhonas/free-exercise-db/main/dist/exercises.json";
        private const string gym_kep_alap_url = "https://raw.githubusercontent.com/yuhonas/free-exercise-db/main/exercises/";
        private const string yoga_api_url = "https://yoga-api-nzy4.onrender.com/v1/poses";

        // --- Hevy-s szűrő listák (a képekről) ---
        private static readonly List<string> hevy_izomcsoport_lista = new List<string>
        {
            "All Muscles", "Abdominals", "Abductors", "Adductors", "Biceps", "Calves",
            "Cardio", "Chest", "Forearms", "Full Body", "Glutes", "Hamstrings",
            "Lats", "Lower Back", "Neck", "Quadriceps", "Shoulders", "Traps",
            "Triceps", "Upper Back", "Other"
        };

        private static readonly List<string> hevy_felszereles_lista = new List<string>
        {
            "All Equipment", "None", "Barbell", "Dumbbell", "Kettlebell", "Machine",
            "Plate", "Resistance Band", "Suspension Band", "Other"
        };

        // Gym API nyers izom → Hevy izomcsoport
        private static readonly Dictionary<string, string> gym_izom_atalakitas = new Dictionary<string, string>(StringComparer.OrdinalIgnoreCase)
        {
            { "abdominals", "Abdominals" },
            { "abductors", "Abductors" },
            { "adductors", "Adductors" },
            { "biceps", "Biceps" },
            { "calves", "Calves" },
            { "chest", "Chest" },
            { "forearms", "Forearms" },
            { "glutes", "Glutes" },
            { "hamstrings", "Hamstrings" },
            { "lats", "Lats" },
            { "lower back", "Lower Back" },
            { "middle back", "Upper Back" },
            { "neck", "Neck" },
            { "quadriceps", "Quadriceps" },
            { "shoulders", "Shoulders" },
            { "traps", "Traps" },
            { "triceps", "Triceps" }
        };

        // Gym API nyers felszerelés → Hevy felszerelés
        private static readonly Dictionary<string, string> gym_felszereles_atalakitas = new Dictionary<string, string>(StringComparer.OrdinalIgnoreCase)
        {
            { "body only", "None" },
            { "barbell", "Barbell" },
            { "dumbbell", "Dumbbell" },
            { "kettlebells", "Kettlebell" },
            { "machine", "Machine" },
            { "cable", "Machine" },
            { "bands", "Resistance Band" },
            { "plate", "Plate" },
            { "e-z curl bar", "Barbell" },
            { "exercise ball", "Other" },
            { "foam roll", "Other" },
            { "medicine ball", "Other" },
            { "other", "Other" }
        };

        // 1. FÜGGVÉNY: Letölti az összes sportág adatait, és beteszi az osszes_gyakorlat listába
        [HttpGet("download-all")]
        public async Task<string> LetoltesMinden()
        {
            using var kliens = new HttpClient();
            kliens.DefaultRequestHeaders.Add("User-Agent", "C# Fitness App");
            var json_beallitas = new JsonSerializerOptions { PropertyNameCaseInsensitive = true };

            osszes_gyakorlat.Clear();

            await GymGyakorlatokBetoltese(kliens, json_beallitas);
            await YogaGyakorlatokBetoltese(kliens);

            return $"Sikeres letoltes! Osszesen {osszes_gyakorlat.Count} db gyakorlat van az osszes_gyakorlat listaban!";
        }

        // Hevy: "Muscle Group" legördülő lista
        [HttpGet("izomcsoportok")]
        public List<string> IzomcsoportLista()
        {
            return hevy_izomcsoport_lista;
        }

        // Hevy: "Equipment" legördülő lista
        [HttpGet("felszereles-tipusok")]
        public List<string> FelszerelesLista()
        {
            return hevy_felszereles_lista;
        }

        // Telefon keresőmező: Id VAGY Név alapján keres (Hevy: "Search exercise")
        [HttpGet("kereso")]
        public async Task<List<Exercise>> KeresoMezo(string keresoszó)
        {
            if (osszes_gyakorlat.Count == 0)
            {
                await LetoltesMinden();
            }

            if (string.IsNullOrWhiteSpace(keresoszó))
            {
                return osszes_gyakorlat;
            }

            return osszes_gyakorlat
                .Where(gyakorlat => IlleszkedikKeresoszore(gyakorlat, keresoszó))
                .ToList();
        }

        // Hevy: kereső + izom + felszerelés + sportág szűrés együtt (Add Exercise képernyő)
        [HttpGet("kereses")]
        public async Task<List<Exercise>> GyakorlatKereses(
            string? kereses = null,
            string? izomcsoport = null,
            string? felszereles = null,
            string? kategoria = null)
        {
            if (osszes_gyakorlat.Count == 0)
            {
                await LetoltesMinden();
            }

            var szurt_lista = osszes_gyakorlat.AsEnumerable();

            // Sportág szűrés: gym / yoga / hyrox / pilates
            if (!string.IsNullOrWhiteSpace(kategoria) && !kategoria.Equals("all", StringComparison.OrdinalIgnoreCase))
            {
                szurt_lista = szurt_lista.Where(g =>
                    g.Category.Equals(kategoria, StringComparison.OrdinalIgnoreCase));
            }

            // Izomcsoport szűrés (Hevy: Muscle Group)
            if (!string.IsNullOrWhiteSpace(izomcsoport) &&
                !izomcsoport.Equals("All Muscles", StringComparison.OrdinalIgnoreCase))
            {
                szurt_lista = szurt_lista.Where(g =>
                    g.MuscleGroup.Equals(izomcsoport, StringComparison.OrdinalIgnoreCase));
            }

            // Felszerelés szűrés (Hevy: Equipment)
            if (!string.IsNullOrWhiteSpace(felszereles) &&
                !felszereles.Equals("All Equipment", StringComparison.OrdinalIgnoreCase))
            {
                szurt_lista = szurt_lista.Where(g =>
                    g.Equipment.Equals(felszereles, StringComparison.OrdinalIgnoreCase));
            }

            // Keresőszó: Id VAGY Név (Hevy: Search exercise)
            if (!string.IsNullOrWhiteSpace(kereses))
            {
                szurt_lista = szurt_lista.Where(g => IlleszkedikKeresoszore(g, kereses));
            }

            return szurt_lista.ToList();
        }

        // Megnézi: a keresőszó benne van-e a gyakorlat Id-jában VAGY a Nevében
        private static bool IlleszkedikKeresoszore(Exercise gyakorlat, string keresoszó)
        {
            return gyakorlat.Id.Contains(keresoszó, StringComparison.OrdinalIgnoreCase)
                || gyakorlat.Name.Contains(keresoszó, StringComparison.OrdinalIgnoreCase);
        }

        private async Task GymGyakorlatokBetoltese(HttpClient kliens, JsonSerializerOptions json_beallitas)
        {
            try
            {
                string gym_nyers_json = await kliens.GetStringAsync(gym_json_url);
                var gym_gyakorlat_kinyert = JsonSerializer.Deserialize<List<Exercise>>(gym_nyers_json, json_beallitas);

                if (gym_gyakorlat_kinyert == null) return;

                foreach (var egy_gym_gyakorlat in gym_gyakorlat_kinyert)
                {
                    string eredeti_tipus = egy_gym_gyakorlat.Category ?? "";

                    egy_gym_gyakorlat.MuscleGroup = GymIzomcsoportKinyerese(egy_gym_gyakorlat, eredeti_tipus);
                    egy_gym_gyakorlat.Equipment = GymFelszerelesKinyerese(egy_gym_gyakorlat.Equipment);
                    egy_gym_gyakorlat.Category = "gym";

                    if (egy_gym_gyakorlat.Images != null)
                    {
                        egy_gym_gyakorlat.Images = egy_gym_gyakorlat.Images
                            .Select(kep_utvonal => kep_utvonal.StartsWith("http") ? kep_utvonal : gym_kep_alap_url + kep_utvonal)
                            .ToList();
                    }

                    osszes_gyakorlat.Add(egy_gym_gyakorlat);
                }
            }
            catch (Exception)
            {
                // Hiba esetén a gym adatok kimaradnak
            }
        }

        private async Task YogaGyakorlatokBetoltese(HttpClient kliens)
        {
            try
            {
                string yoga_nyers_json = await kliens.GetStringAsync(yoga_api_url);

                using JsonDocument yoga_dokumentum = JsonDocument.Parse(yoga_nyers_json);
                if (yoga_dokumentum.RootElement.ValueKind != JsonValueKind.Array) return;

                foreach (JsonElement yoga_elem in yoga_dokumentum.RootElement.EnumerateArray())
                {
                    string yoga_azonosito = yoga_elem.TryGetProperty("id", out var id_elem) ? id_elem.GetInt32().ToString() : "0";
                    string yoga_angol_nev = yoga_elem.TryGetProperty("english_name", out var angol_elem) ? angol_elem.GetString() ?? "" : "";
                    string yoga_szanszkrit_nev = yoga_elem.TryGetProperty("sanskrit_name_adapted", out var szansz_elem) ? szansz_elem.GetString() ?? "" : "";
                    string yoga_leiras = yoga_elem.TryGetProperty("pose_description", out var leiras_elem) ? leiras_elem.GetString() ?? "" : "";
                    string yoga_elonyok = yoga_elem.TryGetProperty("pose_benefits", out var elony_elem) ? elony_elem.GetString() ?? "" : "";
                    string yoga_szint = yoga_elem.TryGetProperty("difficulty_level", out var szint_elem) ? szint_elem.GetString() ?? "beginner" : "beginner";
                    string yoga_png_kep = yoga_elem.TryGetProperty("url_png", out var png_elem) ? png_elem.GetString() ?? "" : "";
                    string yoga_svg_kep = yoga_elem.TryGetProperty("url_svg", out var svg_elem) ? svg_elem.GetString() ?? "" : "";

                    var yoga_utasitasok = new List<string>();
                    if (!string.IsNullOrWhiteSpace(yoga_leiras)) yoga_utasitasok.Add(yoga_leiras);
                    if (!string.IsNullOrWhiteSpace(yoga_elonyok)) yoga_utasitasok.Add(yoga_elonyok);

                    var yoga_kepek = new List<string>();
                    if (!string.IsNullOrWhiteSpace(yoga_png_kep)) yoga_kepek.Add(yoga_png_kep);
                    if (!string.IsNullOrWhiteSpace(yoga_svg_kep)) yoga_kepek.Add(yoga_svg_kep);

                    var yoga_gyakorlat_kinyert = new Exercise
                    {
                        Id = $"yoga_{yoga_azonosito}",
                        Name = string.IsNullOrWhiteSpace(yoga_szanszkrit_nev) ? yoga_angol_nev : $"{yoga_angol_nev} ({yoga_szanszkrit_nev})",
                        Category = "yoga",
                        MuscleGroup = "Full Body",
                        Equipment = "None",
                        Level = yoga_szint.ToLower(),
                        Instructions = yoga_utasitasok,
                        Images = yoga_kepek
                    };

                    osszes_gyakorlat.Add(yoga_gyakorlat_kinyert);
                }
            }
            catch (Exception)
            {
                // Hiba esetén a yoga adatok kimaradnak
            }
        }

        private static string GymIzomcsoportKinyerese(Exercise gym_gyakorlat, string eredeti_tipus)
        {
            if (eredeti_tipus.Equals("cardio", StringComparison.OrdinalIgnoreCase))
            {
                return "Cardio";
            }

            if (gym_gyakorlat.PrimaryMuscles != null && gym_gyakorlat.PrimaryMuscles.Count > 0)
            {
                string nyers_izom = gym_gyakorlat.PrimaryMuscles[0];
                if (gym_izom_atalakitas.TryGetValue(nyers_izom, out string? hevy_izom))
                {
                    return hevy_izom;
                }
            }

            return "Other";
        }

        private static string GymFelszerelesKinyerese(string? nyers_felszereles)
        {
            if (string.IsNullOrWhiteSpace(nyers_felszereles))
            {
                return "None";
            }

            if (gym_felszereles_atalakitas.TryGetValue(nyers_felszereles, out string? hevy_felszereles))
            {
                return hevy_felszereles;
            }

            return "Other";
        }

        [HttpGet]
        public async Task<List<Exercise>> OsszesGyakorlat()
        {
            if (osszes_gyakorlat.Count == 0)
            {
                await LetoltesMinden();
            }
            return osszes_gyakorlat;
        }

        [HttpGet("kategoria/{valasztott_kategoria}")]
        public async Task<List<Exercise>> GyakorlatokKategoriaSzerint(string valasztott_kategoria)
        {
            if (osszes_gyakorlat.Count == 0)
            {
                await LetoltesMinden();
            }

            return osszes_gyakorlat
                .Where(gyakorlat => gyakorlat.Category.Equals(valasztott_kategoria, StringComparison.OrdinalIgnoreCase))
                .ToList();
        }
    }
}
