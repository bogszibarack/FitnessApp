using System.Text.Json;

namespace FitnessBackend.Models
{
    public static class DataPersistence
    {
        // Stabil adatmappa: fejlesztésnél a projekt gyökere (dotnet run munkakönyvtára),
        // hosztolt környezetben az app mappája. Így a bin/Debug ↔ Release ↔ publish
        // váltás nem "veszíti el" az elmentett edzéseket.
        private static readonly string DataDir = AdatMappaFeloldasa();
        private static readonly string LegacyDataDir = Path.Combine(AppContext.BaseDirectory, "data");

        private static readonly string WorkoutHistoryFile = Path.Combine(DataDir, "workout_history.json");
        private static readonly string AktivEdzesFile = Path.Combine(DataDir, "aktiv_edzes.json");
        private static readonly string RutinokFile = Path.Combine(DataDir, "rutinok.json");
        private static readonly string NutritionFile = Path.Combine(DataDir, "nutrition_naplok.json");
        private static readonly string FelhasznalokFile = Path.Combine(DataDir, "felhasznalok.json");
        private static readonly string ProgresszioFile = Path.Combine(DataDir, "progresszio.json");

        // Utolsó mentési hiba — a diagnosztika végponton keresztül kiolvasható,
        // mert a hosztolt szerveren a konzol log nem elérhető.
        public static string UtolsoHiba { get; private set; } = "";

        private static string AdatMappaFeloldasa()
        {
            try
            {
                var cwd = Directory.GetCurrentDirectory();
                if (Directory.GetFiles(cwd, "*.csproj").Length > 0)
                    return Path.Combine(cwd, "data");
            }
            catch { }
            return Path.Combine(AppContext.BaseDirectory, "data");
        }

        /// <summary>Ha az új helyen nincs fájl, de a régi (bin-mappás) helyen van, azt olvassuk.</summary>
        private static string? OlvasandoFajl(string ujUt)
        {
            if (File.Exists(ujUt)) return ujUt;
            var legacy = Path.Combine(LegacyDataDir, Path.GetFileName(ujUt));
            if (File.Exists(legacy)) return legacy;
            return null;
        }

        private static readonly JsonSerializerOptions Opts = new JsonSerializerOptions
        {
            PropertyNamingPolicy = JsonNamingPolicy.CamelCase,
            PropertyNameCaseInsensitive = true,
            WriteIndented = false
        };

        public static void Betoltes(List<WorkoutSession> edzesTortenet, ref WorkoutSession? aktivEdzes)
        {
            try
            {
                Directory.CreateDirectory(DataDir);

                var historyUt = OlvasandoFajl(WorkoutHistoryFile);
                if (historyUt != null)
                {
                    var json = File.ReadAllText(historyUt);
                    var lista = JsonSerializer.Deserialize<List<WorkoutSession>>(json, Opts);
                    if (lista != null)
                    {
                        edzesTortenet.AddRange(lista);
                    }
                }

                var aktivUt = OlvasandoFajl(AktivEdzesFile);
                if (aktivUt != null)
                {
                    var json = File.ReadAllText(aktivUt);
                    var mentett = JsonSerializer.Deserialize<WorkoutSession>(json, Opts);
                    if (mentett != null && mentett.IsActive)
                    {
                        aktivEdzes = mentett;
                        aktivEdzes.StartTime = DateTime.Now;
                    }
                }

                var rutinUt = OlvasandoFajl(RutinokFile);
                if (rutinUt != null)
                {
                    var json = File.ReadAllText(rutinUt);
                    var rutinok = JsonSerializer.Deserialize<List<Routine>>(json, Opts);
                    if (rutinok != null)
                    {
                        EdzesTervTarolo.MentettRutinok.AddRange(rutinok);
                    }
                }

                var nutritionUt = OlvasandoFajl(NutritionFile);
                if (nutritionUt != null)
                {
                    var json = File.ReadAllText(nutritionUt);
                    var naplok = JsonSerializer.Deserialize<List<DailyNutritionSession>>(json, Opts);
                    if (naplok != null)
                    {
                        var maElott = DateTime.Today.AddDays(-30);
                        foreach (var naplo in naplok.Where(n => n.Date >= maElott))
                        {
                            NutritionTarolo.NapiNaplok.Add(naplo);
                        }
                    }
                }

                var progresszioUt = OlvasandoFajl(ProgresszioFile);
                if (progresszioUt != null)
                {
                    var json = File.ReadAllText(progresszioUt);
                    var beallitas = JsonSerializer.Deserialize<ProgresszioBeallitas>(json, Opts);
                    if (beallitas != null)
                    {
                        EdzesTervTarolo.ProgresszioBeallitas = beallitas;
                    }
                }

                FelhasznalokBetoltese();
            }
            catch (Exception ex)
            {
                UtolsoHiba = $"Betöltés: {ex.Message}";
                Console.WriteLine($"[DataPersistence] Betöltési hiba: {ex.Message}");
            }
        }

        /// <summary>Biztonságos írás: előbb temp fájlba, aztán átnevezés — így félbeszakadt
        /// írásnál sem sérül a korábbi adat.</summary>
        private static void BiztonsagosIras(string ut, string json)
        {
            Directory.CreateDirectory(DataDir);
            var tmp = ut + ".tmp";
            File.WriteAllText(tmp, json);
            File.Move(tmp, ut, overwrite: true);
        }

        public static void EdzesTortenetMentese(List<WorkoutSession> edzesTortenet)
        {
            try
            {
                var json = JsonSerializer.Serialize(edzesTortenet, Opts);
                BiztonsagosIras(WorkoutHistoryFile, json);
            }
            catch (Exception ex)
            {
                UtolsoHiba = $"Edzéstörténet mentés: {ex.Message}";
                Console.WriteLine($"[DataPersistence] Edzés mentési hiba: {ex.Message}");
            }
        }

        public static void AktivEdzesTorlese()
        {
            try
            {
                if (File.Exists(AktivEdzesFile)) File.Delete(AktivEdzesFile);
            }
            catch { }
        }

        public static void AktivEdzesMentese(WorkoutSession? aktiv)
        {
            try
            {
                Directory.CreateDirectory(DataDir);
                if (aktiv == null)
                {
                    AktivEdzesTorlese();
                    return;
                }
                var json = JsonSerializer.Serialize(aktiv, Opts);
                BiztonsagosIras(AktivEdzesFile, json);
            }
            catch (Exception ex)
            {
                UtolsoHiba = $"Aktív edzés mentés: {ex.Message}";
                Console.WriteLine($"[DataPersistence] Aktív edzés mentési hiba: {ex.Message}");
            }
        }

        public static void RutinokMentese()
        {
            try
            {
                var json = JsonSerializer.Serialize(EdzesTervTarolo.MentettRutinok, Opts);
                BiztonsagosIras(RutinokFile, json);
            }
            catch (Exception ex)
            {
                UtolsoHiba = $"Rutin mentés: {ex.Message}";
                Console.WriteLine($"[DataPersistence] Rutinok mentési hiba: {ex.Message}");
            }
        }

        public static void ProgresszioMentese()
        {
            try
            {
                var json = JsonSerializer.Serialize(EdzesTervTarolo.ProgresszioBeallitas, Opts);
                BiztonsagosIras(ProgresszioFile, json);
            }
            catch (Exception ex)
            {
                UtolsoHiba = $"Progresszió mentés: {ex.Message}";
                Console.WriteLine($"[DataPersistence] Progresszió mentési hiba: {ex.Message}");
            }
        }

        public static void NutritionMentese()
        {
            try
            {
                var json = JsonSerializer.Serialize(NutritionTarolo.NapiNaplok, Opts);
                BiztonsagosIras(NutritionFile, json);
            }
            catch (Exception ex)
            {
                UtolsoHiba = $"Nutrition mentés: {ex.Message}";
                Console.WriteLine($"[DataPersistence] Nutrition mentési hiba: {ex.Message}");
            }
        }

        public static void FelhasznalokBetoltese()
        {
            try
            {
                var ut = OlvasandoFajl(FelhasznalokFile);
                if (ut == null) return;

                var json = File.ReadAllText(ut);
                var csomag = JsonSerializer.Deserialize<FelhasznaloFiokExport>(json, Opts);
                if (csomag?.Felhasznalok == null) return;

                FelhasznaloFiok.Felhasznalok.Clear();
                FelhasznaloFiok.Felhasznalok.AddRange(csomag.Felhasznalok);
            }
            catch (Exception ex)
            {
                Console.WriteLine($"[DataPersistence] Felhasználók betöltési hiba: {ex.Message}");
            }
        }

        public static void FelhasznalokMentese()
        {
            try
            {
                var csomag = new FelhasznaloFiokExport
                {
                    Felhasznalok = FelhasznaloFiok.Felhasznalok.ToList()
                };
                var json = JsonSerializer.Serialize(csomag, Opts);
                BiztonsagosIras(FelhasznalokFile, json);
            }
            catch (Exception ex)
            {
                UtolsoHiba = $"Felhasználók mentés: {ex.Message}";
                Console.WriteLine($"[DataPersistence] Felhasználók mentési hiba: {ex.Message}");
            }
        }

        /// <summary>Diagnosztika a hosztolt szerverhez: hova ír, mi van lemezen, működik-e az írás.</summary>
        public static object Diagnosztika(int tortenetDarab, bool vanAktivEdzes)
        {
            string irasTeszt;
            try
            {
                Directory.CreateDirectory(DataDir);
                var tesztUt = Path.Combine(DataDir, "iras_teszt.tmp");
                File.WriteAllText(tesztUt, DateTime.Now.ToString("O"));
                File.Delete(tesztUt);
                irasTeszt = "OK";
            }
            catch (Exception ex)
            {
                irasTeszt = $"HIBA: {ex.Message}";
            }

            static object FajlInfo(string ut)
            {
                var f = new FileInfo(ut);
                return f.Exists
                    ? new { letezik = true, meretByte = f.Length, utolsoIras = f.LastWriteTime }
                    : (object)new { letezik = false, meretByte = 0L, utolsoIras = (DateTime?)null };
            }

            return new
            {
                dataDir = DataDir,
                baseDirectory = AppContext.BaseDirectory,
                currentDirectory = Directory.GetCurrentDirectory(),
                irasTeszt,
                utolsoHiba = UtolsoHiba,
                memoriaban = new
                {
                    edzesTortenet = tortenetDarab,
                    vanAktivEdzes,
                    rutinok = EdzesTervTarolo.MentettRutinok.Count,
                    progresszio = EdzesTervTarolo.ProgresszioBeallitas
                },
                fajlok = new
                {
                    workoutHistory = FajlInfo(WorkoutHistoryFile),
                    aktivEdzes = FajlInfo(AktivEdzesFile),
                    rutinok = FajlInfo(RutinokFile),
                    progresszio = FajlInfo(ProgresszioFile),
                    nutrition = FajlInfo(NutritionFile),
                    felhasznalok = FajlInfo(FelhasznalokFile)
                }
            };
        }
    }
}
