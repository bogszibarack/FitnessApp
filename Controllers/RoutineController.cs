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

        // 2. ALAP SABLONOK — Hevy: "Beginner Push/Pull/Legs"
        [HttpGet("alap-sablonok")]
        public async Task<ActionResult<List<Routine>>> AlapSablonok()
        {
            var exercise_controller = new ExerciseController();
            var osszes_gyakorlat = await exercise_controller.OsszesGyakorlat();

            var gym_gyakorlatok = osszes_gyakorlat
                .Where(g => g.Category.Equals("gym", StringComparison.OrdinalIgnoreCase))
                .ToList();

            var sablonok = new List<Routine>
            {
                SablonOsszeallitasa("Push", "beginner", "Chest", "gym",
                    new[] { "Chest", "Shoulders", "Triceps" }, gym_gyakorlatok),
                SablonOsszeallitasa("Pull", "beginner", "Upper Back", "gym",
                    new[] { "Lats", "Upper Back", "Biceps" }, gym_gyakorlatok),
                SablonOsszeallitasa("Legs", "beginner", "Quadriceps", "gym",
                    new[] { "Quadriceps", "Hamstrings", "Glutes" }, gym_gyakorlatok)
            };

            return Ok(sablonok);
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

        private static List<Exercise> GyakorlatokSzuresre(List<Exercise> osszes_gyakorlat, AiGeneraloKeres keres)
        {
            return osszes_gyakorlat
                .Where(g => g.Category.Equals(keres.SportCategory, StringComparison.OrdinalIgnoreCase))
                .Where(g => g.MuscleGroup.Equals(keres.TargetMuscle, StringComparison.OrdinalIgnoreCase)
                    || IzomEgyezik(keres.TargetMuscle, g.MuscleGroup))
                .Where(g => SzintEgyezik(keres.Difficulty, g.Level))
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

            for (int i = 1; i <= 3; i++)
            {
                var valasztott_gyakorlatok = szurt_gyakorlatok
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

                foreach (var g in valasztott_gyakorlatok)
                {
                    mar_hasznalt_idk.Add(g.Id);
                }

                variaciok.Add(new Routine
                {
                    Id = $"AI_TEMP_{Random.Shared.Next(10000, 99999)}_{i}",
                    CreatorName = "AI Edzesterv",
                    Title = $"AI {keres.TargetMuscle} - Variacio {char.ConvertFromUtf32(64 + i)}",
                    Difficulty = keres.Difficulty,
                    TargetMuscle = keres.TargetMuscle,
                    SportCategory = keres.SportCategory,
                    ExerciseIds = valasztott_gyakorlatok.Select(g => g.Id).ToList(),
                    ExerciseNames = valasztott_gyakorlatok.Select(g => g.Name).ToList()
                });
            }

            return variaciok;
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
