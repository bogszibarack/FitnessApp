using System.Text.Json;

namespace FitnessBackend.Models
{
    public static class DataPersistence
    {
        private static readonly string DataDir = Path.Combine(AppContext.BaseDirectory, "data");
        private static readonly string WorkoutHistoryFile = Path.Combine(AppContext.BaseDirectory, "data", "workout_history.json");
        private static readonly string AktivEdzesFile = Path.Combine(AppContext.BaseDirectory, "data", "aktiv_edzes.json");
        private static readonly string RutinokFile = Path.Combine(AppContext.BaseDirectory, "data", "rutinok.json");
        private static readonly string NutritionFile = Path.Combine(AppContext.BaseDirectory, "data", "nutrition_naplok.json");

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

                if (File.Exists(WorkoutHistoryFile))
                {
                    var json = File.ReadAllText(WorkoutHistoryFile);
                    var lista = JsonSerializer.Deserialize<List<WorkoutSession>>(json, Opts);
                    if (lista != null)
                    {
                        edzesTortenet.AddRange(lista);
                    }
                }

                if (File.Exists(AktivEdzesFile))
                {
                    var json = File.ReadAllText(AktivEdzesFile);
                    var mentett = JsonSerializer.Deserialize<WorkoutSession>(json, Opts);
                    if (mentett != null && mentett.IsActive)
                    {
                        aktivEdzes = mentett;
                        aktivEdzes.StartTime = DateTime.Now;
                    }
                }

                if (File.Exists(RutinokFile))
                {
                    var json = File.ReadAllText(RutinokFile);
                    var rutinok = JsonSerializer.Deserialize<List<Routine>>(json, Opts);
                    if (rutinok != null)
                    {
                        EdzesTervTarolo.MentettRutinok.AddRange(rutinok);
                    }
                }

                if (File.Exists(NutritionFile))
                {
                    var json = File.ReadAllText(NutritionFile);
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
    }
}
