using Microsoft.AspNetCore.Mvc;
using FitnessBackend.Models;

namespace FitnessBackend.Controllers
{
    [ApiController]
    [Route("api/[controller]")]
    public class WorkoutController : ControllerBase
    {
        // Éppen futó edzés (Hevy: "Log Workout" képernyő)
        private static WorkoutSession? aktiv_edzes = null;

        // Befejezett edzések (Hevy: profil / előzmények)
        private static List<WorkoutSession> edzes_tortenet = new List<WorkoutSession>();

        // 1/b. START ROUTINE — rutinból induló edzés (Hevy: "Start Routine" gomb)
        [HttpPost("inditas-rutinbol")]
        public ActionResult<WorkoutSession> RutinInditasa([FromBody] Routine rutin)
        {
            if (aktiv_edzes != null)
            {
                return BadRequest("Mar fut egy edzes! Eloszor fejezd be vagy dobd el.");
            }

            aktiv_edzes = new WorkoutSession
            {
                Id = 0,
                Title = rutin.Title,
                StartTime = DateTime.Now,
                IsActive = true,
                Exercises = Routine.GyakorlatokInditashoz(rutin).Select(gyakorlat =>
                {
                    if (gyakorlat.Sets.Count == 0)
                    {
                        gyakorlat.Sets = AlapSorozatokLetrehozasa(rutin.Difficulty);
                    }

                    if (rutin.GyakorlatSablonok.Count == 0)
                    {
                        ElozoAdatokKitoltese(gyakorlat);
                    }

                    return gyakorlat;
                }).ToList()
            };

            return Ok(aktiv_edzes);
        }

        // 1/c. MENTETT RUTIN INDÍTÁSA ID alapján
        [HttpPost("inditas-rutinbol/{rutin_id}")]
        public ActionResult<WorkoutSession> MentettRutinInditasa(string rutin_id)
        {
            var rutin = EdzesTervTarolo.MentettRutinok
                .FirstOrDefault(r => r.Id.Equals(rutin_id, StringComparison.OrdinalIgnoreCase));

            if (rutin == null)
            {
                return NotFound("Nincs ilyen mentett rutin.");
            }

            return RutinInditasa(rutin);
        }

        // 1. START EMPTY WORKOUT — üres edzés indítása (Hevy: "+ Start Empty Workout")
        [HttpPost("uj-ures-edzes")]
        public ActionResult<WorkoutSession> UjUresEdzes()
        {
            if (aktiv_edzes != null)
            {
                return BadRequest("Mar fut egy edzes! Eloszor fejezd be vagy dobd el.");
            }

            aktiv_edzes = new WorkoutSession
            {
                Id = 0,
                Title = "Empty Workout",
                StartTime = DateTime.Now,
                IsActive = true,
                Exercises = new List<LoggedExercise>()
            };

            return Ok(aktiv_edzes);
        }

        // 2. AKTÍV EDZÉS LEKÉRÉSE — stopper, volume, sets frissítéshez (Hevy: "Log Workout" fejléc)
        [HttpGet("aktiv")]
        public ActionResult<WorkoutSession> AktivEdzes()
        {
            if (aktiv_edzes == null)
            {
                return NotFound("Nincs futó edzés. Indíts egyet: POST /api/workout/uj-ures-edzes");
            }

            return Ok(aktiv_edzes);
        }

        // 2/b. EDZÉS CÍMÉNEK MÓDOSÍTÁSA (Hevy: edzés átnevezése)
        [HttpPut("aktiv")]
        public ActionResult<WorkoutSession> EdzesModositasa([FromBody] EdzesModositasKeres modositas)
        {
            if (aktiv_edzes == null)
            {
                return NotFound("Nincs futó edzés.");
            }

            if (!string.IsNullOrWhiteSpace(modositas.Title))
            {
                aktiv_edzes.Title = modositas.Title;
            }

            return Ok(aktiv_edzes);
        }

        // 2/c. EGY GYAKORLAT LEKÉRÉSE a futó edzésből
        [HttpGet("aktiv/gyakorlat/{gyakorlat_id}")]
        public ActionResult<LoggedExercise> GyakorlatLekerdezese(string gyakorlat_id)
        {
            if (aktiv_edzes == null)
            {
                return NotFound("Nincs futó edzés.");
            }

            var gyakorlat = aktiv_edzes.Exercises
                .FirstOrDefault(g => g.ExerciseId == gyakorlat_id);

            if (gyakorlat == null)
            {
                return NotFound($"Nincs ilyen gyakorlat az edzesben: {gyakorlat_id}");
            }

            return Ok(gyakorlat);
        }

        // 3. GYAKORLAT HOZZÁADÁSA — (Hevy: "+ Add Exercise" → kiválasztás)
        [HttpPost("aktiv/gyakorlat-hozzaadas")]
        public ActionResult<LoggedExercise> GyakorlatHozzaadas([FromBody] LoggedExercise uj_gyakorlat)
        {
            if (aktiv_edzes == null)
            {
                return NotFound("Nincs futó edzés.");
            }

            if (string.IsNullOrWhiteSpace(uj_gyakorlat.ExerciseId))
            {
                return BadRequest("ExerciseId kötelező.");
            }

            // Ha már benne van, ne duplikáljuk
            var meglevo = aktiv_edzes.Exercises
                .FirstOrDefault(g => g.ExerciseId == uj_gyakorlat.ExerciseId);

            if (meglevo != null)
            {
                return Ok(meglevo);
            }

            var hozzaadott_gyakorlat = new LoggedExercise
            {
                ExerciseId = uj_gyakorlat.ExerciseId,
                ExerciseName = uj_gyakorlat.ExerciseName,
                Sets = uj_gyakorlat.Sets ?? new List<LoggedSet>()
            };

            aktiv_edzes.Exercises.Add(hozzaadott_gyakorlat);
            return Ok(hozzaadott_gyakorlat);
        }

        // 3/b. GYAKORLAT TÖRLÉSE a futó edzésből (Hevy: gyakorlat eltávolítása)
        [HttpDelete("aktiv/gyakorlat/{gyakorlat_id}")]
        public ActionResult<string> GyakorlatTorlese(string gyakorlat_id)
        {
            if (aktiv_edzes == null)
            {
                return NotFound("Nincs futó edzés.");
            }

            var torlendo_gyakorlat = aktiv_edzes.Exercises
                .FirstOrDefault(g => g.ExerciseId == gyakorlat_id);

            if (torlendo_gyakorlat == null)
            {
                return NotFound($"Nincs ilyen gyakorlat az edzesben: {gyakorlat_id}");
            }

            aktiv_edzes.Exercises.Remove(torlendo_gyakorlat);
            return Ok($"Gyakorlat torolve: {torlendo_gyakorlat.ExerciseName}");
        }

        // 3/c. GYAKORLAT MÓDOSÍTÁSA — név vagy szériák egyszerre (Hevy: gyakorlat szerkesztése)
        [HttpPut("aktiv/gyakorlat/{gyakorlat_id}")]
        public ActionResult<LoggedExercise> GyakorlatModositasa(string gyakorlat_id, [FromBody] LoggedExercise modositott_gyakorlat)
        {
            if (aktiv_edzes == null)
            {
                return NotFound("Nincs futó edzés.");
            }

            var gyakorlat = aktiv_edzes.Exercises
                .FirstOrDefault(g => g.ExerciseId == gyakorlat_id);

            if (gyakorlat == null)
            {
                return NotFound($"Nincs ilyen gyakorlat az edzesben: {gyakorlat_id}");
            }

            if (!string.IsNullOrWhiteSpace(modositott_gyakorlat.ExerciseName))
            {
                gyakorlat.ExerciseName = modositott_gyakorlat.ExerciseName;
            }

            if (modositott_gyakorlat.Sets != null)
            {
                gyakorlat.Sets = modositott_gyakorlat.Sets;
            }

            return Ok(gyakorlat);
        }

        // 4. SOROZATOK FRISSÍTÉSE — teljes szérialista cseréje (Hevy: összes sor egyszerre)
        [HttpPut("aktiv/gyakorlat/{gyakorlat_id}/sorozatok")]
        public ActionResult<LoggedExercise> SorozatokFrissitese(string gyakorlat_id, [FromBody] List<LoggedSet> uj_sorozatok)
        {
            if (aktiv_edzes == null)
            {
                return NotFound("Nincs futó edzés.");
            }

            var gyakorlat = aktiv_edzes.Exercises
                .FirstOrDefault(g => g.ExerciseId == gyakorlat_id);

            if (gyakorlat == null)
            {
                return NotFound($"Nincs ilyen gyakorlat az edzesben: {gyakorlat_id}");
            }

            gyakorlat.Sets = uj_sorozatok;
            return Ok(gyakorlat);
        }

        // 4/b. EGY SOROZAT HOZZÁADÁSA (Hevy: "+ Add Set")
        [HttpPost("aktiv/gyakorlat/{gyakorlat_id}/sorozat")]
        public ActionResult<LoggedSet> SorozatHozzaadasa(string gyakorlat_id, [FromBody] LoggedSet uj_sorozat)
        {
            if (aktiv_edzes == null)
            {
                return NotFound("Nincs futó edzés.");
            }

            var gyakorlat = aktiv_edzes.Exercises
                .FirstOrDefault(g => g.ExerciseId == gyakorlat_id);

            if (gyakorlat == null)
            {
                return NotFound($"Nincs ilyen gyakorlat az edzesben: {gyakorlat_id}");
            }

            if (uj_sorozat.SetNumber == 0)
            {
                uj_sorozat.SetNumber = gyakorlat.Sets.Count + 1;
            }

            gyakorlat.Sets.Add(uj_sorozat);
            return Ok(uj_sorozat);
        }

        // 4/c. EGY SOROZAT MÓDOSÍTÁSA (Hevy: kg / ismétlés átírása egy sorban)
        [HttpPut("aktiv/gyakorlat/{gyakorlat_id}/sorozat/{sorozat_szam}")]
        public ActionResult<LoggedSet> SorozatModositasa(string gyakorlat_id, int sorozat_szam, [FromBody] LoggedSet modositott_sorozat)
        {
            if (aktiv_edzes == null)
            {
                return NotFound("Nincs futó edzés.");
            }

            var gyakorlat = aktiv_edzes.Exercises
                .FirstOrDefault(g => g.ExerciseId == gyakorlat_id);

            if (gyakorlat == null)
            {
                return NotFound($"Nincs ilyen gyakorlat az edzesben: {gyakorlat_id}");
            }

            var sorozat = gyakorlat.Sets.FirstOrDefault(s => s.SetNumber == sorozat_szam);

            if (sorozat == null)
            {
                return NotFound($"Nincs ilyen sorozat: {sorozat_szam}");
            }

            sorozat.Weight = modositott_sorozat.Weight;
            sorozat.Reps = modositott_sorozat.Reps;
            sorozat.Rpe = modositott_sorozat.Rpe;
            sorozat.CelIsmetles = modositott_sorozat.CelIsmetles;

            return Ok(sorozat);
        }

        // 4/e. PIPA — széria kipipálása ✓ (Hevy: zöld pipa gomb)
        [HttpPost("aktiv/gyakorlat/{gyakorlat_id}/sorozat/{sorozat_szam}/pipa")]
        public ActionResult<LoggedSet> SorozatPipalasa(
            string gyakorlat_id,
            int sorozat_szam,
            [FromBody] LoggedSet? beirt_adatok = null)
        {
            if (aktiv_edzes == null)
            {
                return NotFound("Nincs futó edzés.");
            }

            var gyakorlat = aktiv_edzes.Exercises
                .FirstOrDefault(g => g.ExerciseId == gyakorlat_id);

            if (gyakorlat == null)
            {
                return NotFound($"Nincs ilyen gyakorlat az edzesben: {gyakorlat_id}");
            }

            var sorozat = gyakorlat.Sets.FirstOrDefault(s => s.SetNumber == sorozat_szam);

            if (sorozat == null)
            {
                return NotFound($"Nincs ilyen sorozat: {sorozat_szam}");
            }

            if (beirt_adatok != null)
            {
                sorozat.Weight = beirt_adatok.Weight;
                sorozat.Reps = beirt_adatok.Reps;
                sorozat.Rpe = beirt_adatok.Rpe;
            }

            sorozat.Elvegezve = true;
            return Ok(sorozat);
        }

        // 4/f. PIPA VISSZAVONÁSA — téves pipa visszavonása
        [HttpDelete("aktiv/gyakorlat/{gyakorlat_id}/sorozat/{sorozat_szam}/pipa")]
        public ActionResult<LoggedSet> SorozatPipaVisszavonasa(string gyakorlat_id, int sorozat_szam)
        {
            if (aktiv_edzes == null)
            {
                return NotFound("Nincs futó edzés.");
            }

            var gyakorlat = aktiv_edzes.Exercises
                .FirstOrDefault(g => g.ExerciseId == gyakorlat_id);

            if (gyakorlat == null)
            {
                return NotFound($"Nincs ilyen gyakorlat az edzesben: {gyakorlat_id}");
            }

            var sorozat = gyakorlat.Sets.FirstOrDefault(s => s.SetNumber == sorozat_szam);

            if (sorozat == null)
            {
                return NotFound($"Nincs ilyen sorozat: {sorozat_szam}");
            }

            sorozat.Elvegezve = false;
            return Ok(sorozat);
        }

        // Rutin indításkor előre kitöltött sorok (Hevy: W + munka sorok)
        private static List<LoggedSet> AlapSorozatokLetrehozasa(string nehezseg)
        {
            var sorozatok = new List<LoggedSet>();
            int sor_szamlalo = 1;

            sorozatok.Add(new LoggedSet
            {
                SetNumber = sor_szamlalo++,
                Bemelegites = true,
                Weight = 0,
                CelIsmetles = "10",
                Elvegezve = false
            });

            sorozatok.Add(new LoggedSet
            {
                SetNumber = sor_szamlalo++,
                Bemelegites = true,
                Weight = 0,
                CelIsmetles = "4-6",
                Elvegezve = false
            });

            int munka_sorok = nehezseg.ToLower() switch
            {
                "intermediate" => 3,
                "advanced" or "expert" => 4,
                _ => 2
            };

            for (int i = 1; i <= munka_sorok; i++)
            {
                sorozatok.Add(new LoggedSet
                {
                    SetNumber = sor_szamlalo++,
                    Bemelegites = false,
                    CelIsmetles = "10-12",
                    Elvegezve = false
                });
            }

            return sorozatok;
        }

        // PREVIOUS oszlop kitöltése az előző edzésből
        private static void ElozoAdatokKitoltese(LoggedExercise gyakorlat)
        {
            var elozo_gyakorlat = edzes_tortenet
                .OrderByDescending(edzes => edzes.StartTime)
                .SelectMany(edzes => edzes.Exercises)
                .FirstOrDefault(g => g.ExerciseId == gyakorlat.ExerciseId);

            if (elozo_gyakorlat == null) return;

            foreach (var sorozat in gyakorlat.Sets)
            {
                var elozo_sorozat = elozo_gyakorlat.Sets.FirstOrDefault(s =>
                    s.SetNumber == sorozat.SetNumber && s.Bemelegites == sorozat.Bemelegites);

                if (elozo_sorozat != null && elozo_sorozat.Elvegezve)
                {
                    sorozat.ElozoSulyKg = elozo_sorozat.Weight;
                    sorozat.ElozoIsmetles = elozo_sorozat.Reps;
                }
            }
        }

        // 4/d. EGY SOROZAT TÖRLÉSE (Hevy: sor törlése)
        [HttpDelete("aktiv/gyakorlat/{gyakorlat_id}/sorozat/{sorozat_szam}")]
        public ActionResult<string> SorozatTorlese(string gyakorlat_id, int sorozat_szam)
        {
            if (aktiv_edzes == null)
            {
                return NotFound("Nincs futó edzés.");
            }

            var gyakorlat = aktiv_edzes.Exercises
                .FirstOrDefault(g => g.ExerciseId == gyakorlat_id);

            if (gyakorlat == null)
            {
                return NotFound($"Nincs ilyen gyakorlat az edzesben: {gyakorlat_id}");
            }

            var torlendo_sorozat = gyakorlat.Sets.FirstOrDefault(s => s.SetNumber == sorozat_szam);

            if (torlendo_sorozat == null)
            {
                return NotFound($"Nincs ilyen sorozat: {sorozat_szam}");
            }

            gyakorlat.Sets.Remove(torlendo_sorozat);
            return Ok($"Sorozat torolve: #{sorozat_szam}");
        }

        // 5. FINISH — edzés mentése (Hevy: kék "Finish" gomb)
        [HttpPost("aktiv/befejezes")]
        public ActionResult<WorkoutSession> AktivEdzesBefejezese()
        {
            if (aktiv_edzes == null)
            {
                return NotFound("Nincs futó edzés.");
            }

            aktiv_edzes.DurationSeconds = aktiv_edzes.ElteltMasodperc;
            aktiv_edzes.IsActive = false;
            aktiv_edzes.Id = edzes_tortenet.Count + 1;

            edzes_tortenet.Add(aktiv_edzes);
            var mentett_edzes = aktiv_edzes;
            aktiv_edzes = null;

            return Ok(mentett_edzes);
        }

        // 5/b. FINISH + COMMUNITY MEGOSZTÁS egy lépésben (szelfi + megye)
        [HttpPost("aktiv/befejezes-es-megosztas")]
        public ActionResult<object> BefejezesEsMegosztas([FromBody] MegosztasKeres megosztas)
        {
            if (aktiv_edzes == null)
            {
                return NotFound("Nincs futó edzés.");
            }

            aktiv_edzes.DurationSeconds = aktiv_edzes.ElteltMasodperc;
            aktiv_edzes.IsActive = false;
            aktiv_edzes.Id = edzes_tortenet.Count + 1;
            edzes_tortenet.Add(aktiv_edzes);

            megosztas.Edzes = aktiv_edzes;
            aktiv_edzes = null;

            var (poszt, hiba) = CommunityTarolo.UjPosztLetrehozasa(megosztas);

            if (hiba != null)
            {
                return BadRequest(hiba);
            }

            return Ok(new
            {
                uzenet = "Edzes mentve es megosztva a kozossegiben!",
                edzes = megosztas.Edzes,
                poszt
            });
        }

        // 7. EDZÉSTÖRTÉNET MEGOSZTÁSA a közösségben (már befejezett edzés)
        [HttpPost("history/{edzes_id:int}/megosztas")]
        public ActionResult<object> TortenetMegosztasa(int edzes_id, [FromBody] MegosztasKeres megosztas)
        {
            var edzes = edzes_tortenet.FirstOrDefault(e => e.Id == edzes_id);
            if (edzes == null)
            {
                return NotFound("Nincs ilyen befejezett edzes.");
            }

            megosztas.Edzes = edzes;
            var (poszt, hiba) = CommunityTarolo.UjPosztLetrehozasa(megosztas);

            if (hiba != null)
            {
                return BadRequest(hiba);
            }

            return Ok(new
            {
                uzenet = "Befejezett edzes megosztva a kozossegiben!",
                edzes,
                poszt
            });
        }

        // 8. DISCARD — edzés elvetése (Hevy: "Discard Workout")
        [HttpDelete("aktiv")]
        public string AktivEdzesElvetese()
        {
            if (aktiv_edzes == null)
            {
                return "Nincs futó edzés, amit el lehetne vetni.";
            }

            aktiv_edzes = null;
            return "Az edzés elvetve.";
        }

        // 7. EDZÉSTÖRTÉNET (Hevy: profil / korábbi edzések)
        [HttpGet("history")]
        public List<WorkoutSession> EdzesTortenet()
        {
            return edzes_tortenet;
        }

        // 7/b. BEFEJEZETT EDZÉS MÓDOSÍTÁSA
        [HttpPut("history/{edzes_id:int}")]
        public ActionResult<WorkoutSession> EdzesTortenetModositasa(int edzes_id, [FromBody] WorkoutSession modositott)
        {
            var edzes = edzes_tortenet.FirstOrDefault(e => e.Id == edzes_id);
            if (edzes == null)
            {
                return NotFound("Nincs ilyen befejezett edzes.");
            }

            if (!string.IsNullOrWhiteSpace(modositott.Title))
            {
                edzes.Title = modositott.Title;
            }

            if (modositott.Exercises != null)
            {
                edzes.Exercises = modositott.Exercises;
            }

            return Ok(edzes);
        }

        // 7/c. BEFEJEZETT EDZÉS TÖRLÉSE
        [HttpDelete("history/{edzes_id:int}")]
        public ActionResult<string> EdzesTortenetTorlese(int edzes_id)
        {
            var edzes = edzes_tortenet.FirstOrDefault(e => e.Id == edzes_id);
            if (edzes == null)
            {
                return NotFound("Nincs ilyen befejezett edzes.");
            }

            edzes_tortenet.Remove(edzes);
            return Ok($"Edzes torolve: {edzes.Title}");
        }

        // 8. PROGRESSZIÓ BEÁLLÍTÁS — user csúszka mentése (alapértelmezett)
        [HttpGet("progresszio-beallitas")]
        public ProgresszioBeallitas ProgresszioBeallitasLekerdezese()
        {
            return EdzesTervTarolo.ProgresszioBeallitas;
        }

        [HttpPut("progresszio-beallitas")]
        public ProgresszioBeallitas ProgresszioBeallitasMentese([FromBody] ProgresszioBeallitas uj_beallitas)
        {
            EdzesTervTarolo.ProgresszioBeallitas = uj_beallitas;
            return EdzesTervTarolo.ProgresszioBeallitas;
        }

        // 9. KÖVETKEZŐ HÉT ELŐNÉZET — csúszka mozgatásakor élőben frissül (még NEM indul edzés)
        [HttpPost("kovetkezo-het/elonezet")]
        public ActionResult<KovetkezoHetValasz> KovetkezoHetElonezet([FromBody] KovetkezoHetKeres keres)
        {
            var elozo_edzes = edzes_tortenet.FirstOrDefault(e => e.Id == keres.ElozoEdzesId);
            if (elozo_edzes == null)
            {
                return NotFound("Nincs ilyen befejezett edzes az elozmenyekben.");
            }

            var beallitas = keres.CsuszkaBeallitas ?? EdzesTervTarolo.ProgresszioBeallitas;
            var valasz = KovetkezoHetGeneralasa(elozo_edzes, beallitas);
            return Ok(valasz);
        }

        // 10. KÖVETKEZŐ HÉT INDÍTÁSA — user megerősíti az előnézetet, indul az edzés
        [HttpPost("kovetkezo-het/inditas")]
        public ActionResult<WorkoutSession> KovetkezoHetInditasa([FromBody] KovetkezoHetKeres keres)
        {
            if (aktiv_edzes != null)
            {
                return BadRequest("Mar fut egy edzes! Eloszor fejezd be vagy dobd el.");
            }

            var elozo_edzes = edzes_tortenet.FirstOrDefault(e => e.Id == keres.ElozoEdzesId);
            if (elozo_edzes == null)
            {
                return NotFound("Nincs ilyen befejezett edzes az elozmenyekben.");
            }

            var beallitas = keres.CsuszkaBeallitas ?? EdzesTervTarolo.ProgresszioBeallitas;
            var generalas = KovetkezoHetGeneralasa(elozo_edzes, beallitas);

            aktiv_edzes = generalas.JavasoltEdzes;
            aktiv_edzes.IsActive = true;
            aktiv_edzes.StartTime = DateTime.Now;

            return Ok(aktiv_edzes);
        }

        private static KovetkezoHetValasz KovetkezoHetGeneralasa(WorkoutSession elozo_edzes, ProgresszioBeallitas beallitas)
        {
            var valtozasok = new List<GyakorlatValtozas>();
            var uj_gyakorlatok = new List<LoggedExercise>();

            foreach (var elozo_gyakorlat in elozo_edzes.Exercises)
            {
                var uj_gyakorlat = new LoggedExercise
                {
                    ExerciseId = elozo_gyakorlat.ExerciseId,
                    ExerciseName = elozo_gyakorlat.ExerciseName,
                    Sets = new List<LoggedSet>()
                };

                foreach (var elozo_sor in elozo_gyakorlat.Sets)
                {
                    double uj_suly = elozo_sor.Weight;
                    int uj_ismetles = elozo_sor.Reps;

                    if (!elozo_sor.Bemelegites && elozo_sor.Elvegezve)
                    {
                        uj_suly = UjSulySzamitasa(elozo_sor.Weight, beallitas);
                        uj_ismetles = elozo_sor.Reps + beallitas.IsmetlesNoveles;
                    }

                    uj_gyakorlat.Sets.Add(new LoggedSet
                    {
                        SetNumber = elozo_sor.SetNumber,
                        Bemelegites = elozo_sor.Bemelegites,
                        Weight = uj_suly,
                        Reps = 0,
                        CelIsmetles = uj_ismetles > 0 ? uj_ismetles.ToString() : elozo_sor.CelIsmetles,
                        Elvegezve = false,
                        ElozoSulyKg = elozo_sor.Weight,
                        ElozoIsmetles = elozo_sor.Reps
                    });

                    if (!elozo_sor.Bemelegites && elozo_sor.Elvegezve)
                    {
                        valtozasok.Add(new GyakorlatValtozas
                        {
                            ExerciseName = elozo_gyakorlat.ExerciseName,
                            SorozatSzam = elozo_sor.SetNumber,
                            Bemelegites = elozo_sor.Bemelegites,
                            RegiSulyKg = elozo_sor.Weight,
                            UjSulyKg = uj_suly,
                            RegiIsmetles = elozo_sor.Reps,
                            UjIsmetles = uj_ismetles
                        });
                    }
                }

                uj_gyakorlatok.Add(uj_gyakorlat);
            }

            return new KovetkezoHetValasz
            {
                JavasoltEdzes = new WorkoutSession
                {
                    Title = $"{elozo_edzes.Title} (Kovetkezo het)",
                    Exercises = uj_gyakorlatok
                },
                Valtozasok = valtozasok,
                HasznaltBeallitas = beallitas
            };
        }

        private static double UjSulySzamitasa(double regi_suly, ProgresszioBeallitas beallitas)
        {
            double uj_suly = beallitas.NovelesModja == "kg"
                ? regi_suly + beallitas.SulyKg
                : regi_suly * (1 + beallitas.SulySzazalek / 100.0);

            return Kerekites2EsFeleKg(Math.Max(0, uj_suly));
        }

        private static double Kerekites2EsFeleKg(double suly)
        {
            return Math.Round(suly / 2.5) * 2.5;
        }

        // Régi végpont: a telefon egyben küldi a teljes edzést (offline módra is jó)
        [HttpPost("finish")]
        public string FinishWorkout([FromBody] WorkoutSession uj_edzes)
        {
            uj_edzes.Id = edzes_tortenet.Count + 1;
            uj_edzes.IsActive = false;

            if (uj_edzes.StartTime == DateTime.MinValue)
            {
                uj_edzes.StartTime = DateTime.Now;
            }

            if (uj_edzes.DurationSeconds == 0)
            {
                uj_edzes.DurationSeconds = uj_edzes.ElteltMasodperc;
            }

            edzes_tortenet.Add(uj_edzes);
            return $"Sikeres mentés! Az edzésed elmentve {uj_edzes.Id} azonosítóval. Összesen {uj_edzes.Exercises.Count} gyakorlatot végeztél.";
        }
    }
}
