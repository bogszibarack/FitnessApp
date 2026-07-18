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

                FelhasznalokBetoltese();
            }
            catch (Exception ex)
            {
                Console.WriteLine($"[DataPersistence] Betöltési hiba: {ex.Message}");
            }
        }

        public static void EdzesTortenetMentese(List<WorkoutSession> edzesTortenet)
        {
            try
            {
                Directory.CreateDirectory(DataDir);
                var json = JsonSerializer.Serialize(edzesTortenet, Opts);
                File.WriteAllText(WorkoutHistoryFile, json);
            }
            catch (Exception ex)
            {
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
                File.WriteAllText(AktivEdzesFile, json);
            }
            catch (Exception ex)
            {
                Console.WriteLine($"[DataPersistence] Aktív edzés mentési hiba: {ex.Message}");
            }
        }

        public static void RutinokMentese()
        {
            try
            {
                Directory.CreateDirectory(DataDir);
                var json = JsonSerializer.Serialize(EdzesTervTarolo.MentettRutinok, Opts);
                File.WriteAllText(RutinokFile, json);
            }
            catch (Exception ex)
            {
                Console.WriteLine($"[DataPersistence] Rutinok mentési hiba: {ex.Message}");
            }
        }

        public static void NutritionMentese()
        {
            try
            {
                Directory.CreateDirectory(DataDir);
                var json = JsonSerializer.Serialize(NutritionTarolo.NapiNaplok, Opts);
                File.WriteAllText(NutritionFile, json);
            }
            catch (Exception ex)
            {
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
                Directory.CreateDirectory(DataDir);
                var csomag = new FelhasznaloFiokExport
                {
                    Felhasznalok = FelhasznaloFiok.Felhasznalok.ToList()
                };
                var json = JsonSerializer.Serialize(csomag, Opts);
                File.WriteAllText(FelhasznalokFile, json);
            }
            catch (Exception ex)
            {
                Console.WriteLine($"[DataPersistence] Felhasználók mentési hiba: {ex.Message}");
            }
        }
    }
}
