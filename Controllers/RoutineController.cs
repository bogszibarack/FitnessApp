using Microsoft.AspNetCore.Mvc;
using FitnessBackend.Models;

namespace FitnessBackend.Controllers
{
    [ApiController]
    [Route("api/[controller]")]
    public class RoutineController : ControllerBase
    {
        // 1. AI GENERÁLÁS — minden gombnyomásra 3 friss variáció (Hevy: Explore / AI terv)
        [HttpPost("ai-generalas")]
        public async Task<ActionResult<List<Routine>>> AiGeneralo([FromBody] AiGeneraloKeres keres)
        {
            var exercise_controller = new ExerciseController();
            var osszes_gyakorlat = await exercise_controller.OsszesGyakorlat();

            var szurt_gyakorlatok = GyakorlatokSzuresre(osszes_gyakorlat, keres);

            if (szurt_gyakorlatok.Count < 3)
            {
                szurt_gyakorlatok = osszes_gyakorlat
                    .Where(g => g.Category.Equals(keres.SportCategory, StringComparison.OrdinalIgnoreCase))
                    .ToList();
            }

            if (szurt_gyakorlatok.Count == 0)
            {
                return BadRequest("Nincs gyakorlat ehhez a szureshez. Probald mas kategoriaval!");
            }

            var harom_variacio = HaromEgyediVariacioGeneralasa(szurt_gyakorlatok, keres);
            return Ok(harom_variacio);
        }

        // 2. ALAP SABLONOK — helyett üres (AI ajánlások használata a Flutterben)
        [HttpGet("alap-sablonok")]
        public ActionResult<List<Routine>> AlapSablonok()
        {
            return Ok(new List<Routine>());
        }

        // 2/b. RUTIN MÓDOSÍTÁSA (Mentéseim szerkesztése)
        [HttpPut("{rutin_id}")]
        public ActionResult<Routine> RutinModositasa(string rutin_id, [FromBody] Routine modositott)
        {
            var rutin = EdzesTervTarolo.MentettRutinok
                .FirstOrDefault(r => r.Id.Equals(rutin_id, StringComparison.OrdinalIgnoreCase));

            if (rutin == null)
            {
                return NotFound("Nincs ilyen mentett rutin.");
            }

            if (!string.IsNullOrWhiteSpace(modositott.Title))
            {
                rutin.Title = modositott.Title;
            }

            if (modositott.ExerciseIds != null && modositott.ExerciseIds.Count > 0)
            {
                rutin.ExerciseIds = modositott.ExerciseIds;
                rutin.ExerciseNames = modositott.ExerciseNames ?? modositott.ExerciseIds;
            }

            if (modositott.GyakorlatSablonok != null && modositott.GyakorlatSablonok.Count > 0)
            {
                rutin.GyakorlatSablonok = modositott.GyakorlatSablonok;
            }

            if (!string.IsNullOrWhiteSpace(modositott.Difficulty))
            {
                rutin.Difficulty = modositott.Difficulty;
            }

            if (!string.IsNullOrWhiteSpace(modositott.TargetMuscle))
            {
                rutin.TargetMuscle = modositott.TargetMuscle;
            }

            return Ok(rutin);
        }

        // 3. MENTÉS — ha megtetszik az egyik variáció (Hevy: rutin elmentése)
        [HttpPost("mentes")]
        public ActionResult<Routine> RutinMentes([FromBody] Routine uj_rutin)
        {
            uj_rutin.Id = $"rutin_{Random.Shared.Next(100000, 999999)}";
            if (string.IsNullOrWhiteSpace(uj_rutin.CreatorName) || uj_rutin.CreatorName == "Hevy AI Trainer")
            {
                uj_rutin.CreatorName = "Sajat terv";
            }

            EdzesTervTarolo.MentettRutinok.Add(uj_rutin);
            return Ok(uj_rutin);
        }

        // 4. MEGOSZTÁS / VISSZAKERESÉS ID alapján (havernak küldés)
        [HttpGet("megosztas/{rutin_id}")]
        public ActionResult<Routine> RutinLekeresIdAlapjan(string rutin_id)
        {
            var talalat = EdzesTervTarolo.MentettRutinok
                .FirstOrDefault(r => r.Id.Equals(rutin_id, StringComparison.OrdinalIgnoreCase));

            if (talalat == null)
            {
                return NotFound("Ez az edzesterv nem talalhato. Ellenorizd a megosztasi kodot!");
            }

            return Ok(talalat);
        }

        // 5. SAJÁT RUTINOK LISTÁJA (Hevy: Routines képernyő)
        [HttpGet("sajatok")]
        public List<Routine> SajatRutinok()
        {
            return EdzesTervTarolo.MentettRutinok;
        }

        // 6. RUTIN TÖRLÉSE
        [HttpDelete("{rutin_id}")]
        public ActionResult<string> RutinTorlese(string rutin_id)
        {
            var torlendo = EdzesTervTarolo.MentettRutinok
                .FirstOrDefault(r => r.Id.Equals(rutin_id, StringComparison.OrdinalIgnoreCase));

            if (torlendo == null)
            {
                return NotFound("Nincs ilyen mentett rutin.");
            }

            EdzesTervTarolo.MentettRutinok.Remove(torlendo);
            return Ok($"Rutin torolve: {torlendo.Title}");
        }

        private static readonly string[] PplPushIzomok = { "Chest", "Shoulders", "Triceps" };
        private static readonly string[] PplPullIzomok = { "Lats", "Upper Back", "Traps", "Biceps" };
        private static readonly string[] PplLegsIzomok = { "Quadriceps", "Hamstrings", "Glutes", "Calves" };

        private static List<Exercise> GyakorlatokSzuresre(List<Exercise> osszes_gyakorlat, AiGeneraloKeres keres)
        {
            if (keres.SportCategory.Equals("yoga", StringComparison.OrdinalIgnoreCase))
            {
                return osszes_gyakorlat
                    .Where(g => g.Category.Equals("yoga", StringComparison.OrdinalIgnoreCase))
                    .Where(g => SzintEgyezik(keres.Difficulty, g.Level))
                    .ToList();
            }

            var gym_gyakorlatok = osszes_gyakorlat
                .Where(g => g.Category.Equals("gym", StringComparison.OrdinalIgnoreCase))
                .ToList();

            if (keres.TargetMuscle.Equals("Push", StringComparison.OrdinalIgnoreCase))
            {
                return PplSzures(gym_gyakorlatok, PplPushIzomok, keres);
            }

            if (keres.TargetMuscle.Equals("Pull", StringComparison.OrdinalIgnoreCase))
            {
                return PplSzures(gym_gyakorlatok, PplPullIzomok, keres);
            }

            if (keres.TargetMuscle.Equals("Legs", StringComparison.OrdinalIgnoreCase))
            {
                return PplSzures(gym_gyakorlatok, PplLegsIzomok, keres);
            }

            if (keres.TargetMuscle.Equals("Bench", StringComparison.OrdinalIgnoreCase))
            {
                return PowerliftingSzures(gym_gyakorlatok, new[] { "bench" }, "Chest", keres);
            }

            if (keres.TargetMuscle.Equals("Squat", StringComparison.OrdinalIgnoreCase))
            {
                return PowerliftingSzures(gym_gyakorlatok, new[] { "squat" }, "Quadriceps", keres);
            }

            if (keres.TargetMuscle.Equals("Deadlift", StringComparison.OrdinalIgnoreCase))
            {
                return PowerliftingSzures(gym_gyakorlatok, new[] { "deadlift" }, "Hamstrings", keres);
            }

            return gym_gyakorlatok
                .Where(g => g.MuscleGroup.Equals(keres.TargetMuscle, StringComparison.OrdinalIgnoreCase)
                    || IzomEgyezik(keres.TargetMuscle, g.MuscleGroup))
                .Where(g => SzintEgyezik(keres.Difficulty, g.Level))
                .ToList();
        }

        private static List<Exercise> PplSzures(List<Exercise> gym_gyakorlatok, string[] izom_csoportok, AiGeneraloKeres keres)
        {
            return gym_gyakorlatok
                .Where(g => izom_csoportok.Any(izom => g.MuscleGroup.Equals(izom, StringComparison.OrdinalIgnoreCase)))
                .Where(g => SzintEgyezik(keres.Difficulty, g.Level))
                .ToList();
        }

        private static List<Exercise> PowerliftingSzures(
            List<Exercise> gym_gyakorlatok,
            string[] kulcsszavak,
            string tartalek_izom,
            AiGeneraloKeres keres)
        {
            var fo_gyakorlatok = gym_gyakorlatok
                .Where(g => kulcsszavak.Any(k => g.Name.Contains(k, StringComparison.OrdinalIgnoreCase)))
                .Where(g => SzintEgyezik(keres.Difficulty, g.Level))
                .ToList();

            if (fo_gyakorlatok.Count >= 3)
            {
                return fo_gyakorlatok;
            }

            var kiegeszito = gym_gyakorlatok
                .Where(g => g.MuscleGroup.Equals(tartalek_izom, StringComparison.OrdinalIgnoreCase))
                .Where(g => SzintEgyezik(keres.Difficulty, g.Level))
                .ToList();

            return fo_gyakorlatok
                .Concat(kiegeszito)
                .GroupBy(g => g.Id)
                .Select(csoport => csoport.First())
                .ToList();
        }

        private static bool IzomEgyezik(string keresett, string muscle_group)
        {
            return keresett.Equals(muscle_group, StringComparison.OrdinalIgnoreCase)
                || muscle_group.Contains(keresett, StringComparison.OrdinalIgnoreCase)
                || keresett.Contains(muscle_group, StringComparison.OrdinalIgnoreCase);
        }

        private static bool SzintEgyezik(string keresett_szint, string? gyakorlat_szint)
        {
            if (string.IsNullOrWhiteSpace(gyakorlat_szint)) return true;

            string tiszta_keres = keresett_szint.ToLower();
            string tiszta_gyak = gyakorlat_szint.ToLower();

            if (tiszta_keres == "beginner") return tiszta_gyak is "beginner" or "intermediate";
            if (tiszta_keres == "intermediate") return tiszta_gyak is "beginner" or "intermediate" or "expert";
            return true;
        }

        private static int GyakorlatSzamNehézségSzerint(string difficulty)
        {
            return difficulty.ToLower() switch
            {
                "intermediate" => 5,
                "advanced" or "expert" => 6,
                _ => 4
            };
        }

        private static List<Routine> HaromEgyediVariacioGeneralasa(List<Exercise> szurt_gyakorlatok, AiGeneraloKeres keres)
        {
            var variaciok = new List<Routine>();
            var mar_hasznalt_idk = new HashSet<string>();
            int gyakorlat_szam = GyakorlatSzamNehézségSzerint(keres.Difficulty);
            var ppl_izomok = PplIzomCsoportok(keres.TargetMuscle);

            for (int i = 1; i <= 3; i++)
            {
                List<Exercise> valasztott_gyakorlatok;

                if (ppl_izomok != null)
                {
                    valasztott_gyakorlatok = KiegyensulyozottValasztas(
                        szurt_gyakorlatok, ppl_izomok, gyakorlat_szam, mar_hasznalt_idk);
                }
                else
                {
                    valasztott_gyakorlatok = szurt_gyakorlatok
                        .Where(g => !mar_hasznalt_idk.Contains(g.Id))
                        .OrderBy(_ => Random.Shared.Next())
                        .Take(gyakorlat_szam)
                        .ToList();

                    if (valasztott_gyakorlatok.Count < gyakorlat_szam)
                    {
                        valasztott_gyakorlatok = szurt_gyakorlatok
                            .OrderBy(_ => Random.Shared.Next())
                            .Take(gyakorlat_szam)
                            .ToList();
                    }
                }

                foreach (var g in valasztott_gyakorlatok)
                {
                    mar_hasznalt_idk.Add(g.Id);
                }

                variaciok.Add(new Routine
                {
                    Id = $"AI_TEMP_{Random.Shared.Next(10000, 99999)}_{i}",
                    CreatorName = "AI Edzesterv",
                    Title = VariacioCim(keres, i),
                    Difficulty = keres.Difficulty,
                    TargetMuscle = keres.TargetMuscle,
                    SportCategory = keres.SportCategory,
                    ExerciseIds = valasztott_gyakorlatok.Select(g => g.Id).ToList(),
                    ExerciseNames = valasztott_gyakorlatok.Select(g => g.Name).ToList()
                });
            }

            return variaciok;
        }

        private static string[]? PplIzomCsoportok(string target_muscle)
        {
            if (target_muscle.Equals("Push", StringComparison.OrdinalIgnoreCase)) return PplPushIzomok;
            if (target_muscle.Equals("Pull", StringComparison.OrdinalIgnoreCase)) return PplPullIzomok;
            if (target_muscle.Equals("Legs", StringComparison.OrdinalIgnoreCase)) return PplLegsIzomok;
            return null;
        }

        private static List<Exercise> KiegyensulyozottValasztas(
            List<Exercise> pool,
            string[] izom_csoportok,
            int cel_szam,
            HashSet<string> mar_hasznalt_idk)
        {
            var valasztott = new List<Exercise>();
            int izomonkent = Math.Max(1, cel_szam / izom_csoportok.Length);

            foreach (var izom in izom_csoportok)
            {
                var csoportbol = pool
                    .Where(g => g.MuscleGroup.Equals(izom, StringComparison.OrdinalIgnoreCase))
                    .Where(g => !mar_hasznalt_idk.Contains(g.Id))
                    .Where(g => !valasztott.Any(v => v.Id == g.Id))
                    .OrderBy(_ => Random.Shared.Next())
                    .Take(izomonkent)
                    .ToList();

                valasztott.AddRange(csoportbol);
            }

            while (valasztott.Count < cel_szam)
            {
                var extra = pool
                    .Where(g => !mar_hasznalt_idk.Contains(g.Id))
                    .Where(g => !valasztott.Any(v => v.Id == g.Id))
                    .OrderBy(_ => Random.Shared.Next())
                    .FirstOrDefault();

                if (extra == null) break;
                valasztott.Add(extra);
            }

            return valasztott.Take(cel_szam).ToList();
        }

        private static string VariacioCim(AiGeneraloKeres keres, int sorszam)
        {
            string betu = char.ConvertFromUtf32(64 + sorszam);

            if (keres.SportCategory.Equals("yoga", StringComparison.OrdinalIgnoreCase))
            {
                return $"AI Yoga - Variacio {betu}";
            }

            string cimke = keres.TargetMuscle switch
            {
                "Push" => "Push",
                "Pull" => "Pull",
                "Legs" => "Legs",
                "Bench" => "Powerlifting Bench",
                "Squat" => "Powerlifting Squat",
                "Deadlift" => "Powerlifting Deadlift",
                _ => keres.TargetMuscle
            };

            return $"AI {cimke} - Variacio {betu}";
        }

        private static Routine SablonOsszeallitasa(
            string nev, string szint, string fo_izom, string sportag,
            string[] izom_csoportok, List<Exercise> gym_gyakorlatok)
        {
            var valasztott = new List<Exercise>();

            foreach (var izom in izom_csoportok)
            {
                var talalat = gym_gyakorlatok
                    .Where(g => g.MuscleGroup.Equals(izom, StringComparison.OrdinalIgnoreCase))
                    .OrderBy(_ => Random.Shared.Next())
                    .FirstOrDefault();

                if (talalat != null && !valasztott.Any(v => v.Id == talalat.Id))
                {
                    valasztott.Add(talalat);
                }
            }

            while (valasztott.Count < 4)
            {
                var extra = gym_gyakorlatok
                    .Where(g => g.MuscleGroup.Equals(fo_izom, StringComparison.OrdinalIgnoreCase))
                    .Where(g => !valasztott.Any(v => v.Id == g.Id))
                    .OrderBy(_ => Random.Shared.Next())
                    .FirstOrDefault();

                if (extra == null) break;
                valasztott.Add(extra);
            }

            return new Routine
            {
                Id = $"sablon_{nev.ToLower()}",
                CreatorName = "Fitness App",
                Title = $"Beginner {nev}",
                Difficulty = szint,
                TargetMuscle = fo_izom,
                SportCategory = sportag,
                ExerciseIds = valasztott.Select(g => g.Id).ToList(),
                ExerciseNames = valasztott.Select(g => g.Name).ToList()
            };
        }
    }
}
