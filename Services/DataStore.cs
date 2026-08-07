using System.Text.Json;
using FitnessBackend.Models;

namespace FitnessBackend.Services
{
    public static class DataStore
    {
        private static readonly string DataDir = ResolveDataDirectory();
        private static readonly string LegacyDataDir = Path.Combine(AppContext.BaseDirectory, "data");

        private static readonly string WorkoutHistoryFile = Path.Combine(DataDir, "workout_history.json");
        private static readonly string ActiveWorkoutFile = Path.Combine(DataDir, "aktiv_edzes.json");
        private static readonly string PlansFile = Path.Combine(DataDir, "rutinok.json");
        private static readonly string NutritionFile = Path.Combine(DataDir, "nutrition_naplok.json");
        private static readonly string AccountsFile = Path.Combine(DataDir, "felhasznalok.json");
        private static readonly string ProgressFile = Path.Combine(DataDir, "progresszio.json");
        private static readonly string StreakFile = Path.Combine(DataDir, "naplo_streak.json");

        public static string LastError { get; private set; } = "";

        private static readonly JsonSerializerOptions Opts = new()
        {
            PropertyNamingPolicy = JsonNamingPolicy.CamelCase,
            PropertyNameCaseInsensitive = true,
            WriteIndented = false
        };

        private static string ResolveDataDirectory()
        {
            // Render / Docker: mount a persistent disk and set DATA_DIR (e.g. /var/data).
            // Without this, container restarts wipe JSON files under /app/data.
            var fromEnv = Environment.GetEnvironmentVariable("DATA_DIR");
            if (!string.IsNullOrWhiteSpace(fromEnv))
            {
                Directory.CreateDirectory(fromEnv);
                Console.WriteLine($"[DataStore] DATA_DIR={fromEnv}");
                return fromEnv;
            }

            try
            {
                var cwd = Directory.GetCurrentDirectory();
                if (Directory.GetFiles(cwd, "*.csproj").Length > 0)
                    return Path.Combine(cwd, "data");
            }
            catch { }
            return Path.Combine(AppContext.BaseDirectory, "data");
        }

        private static string? ReadableFile(string newPath)
        {
            if (File.Exists(newPath)) return newPath;
            var legacy = Path.Combine(LegacyDataDir, Path.GetFileName(newPath));
            if (File.Exists(legacy)) return legacy;
            return null;
        }

        /// <summary>Maps old Hungarian JSON keys to English before deserialize.</summary>
        private static string MigrateJson(string json) => json
            .Replace("\"bemelegites\"", "\"isWarmup\"")
            .Replace("\"celIsmetles\"", "\"targetReps\"")
            .Replace("\"elvegezve\"", "\"isDone\"")
            .Replace("\"elozoSulyKg\"", "\"prevWeightKg\"")
            .Replace("\"elozoIsmetles\"", "\"prevReps\"")
            .Replace("\"gyakorlatSablonok\"", "\"exerciseTemplates\"")
            .Replace("\"forrasPostId\"", "\"sourcePostId\"")
            .Replace("\"novelesModja\"", "\"mode\"")
            .Replace("\"sulySzazalek\"", "\"percent\"")
            .Replace("\"sulyKg\"", "\"kg\"")
            .Replace("\"ismetlesNoveles\"", "\"repBoost\"")
            .Replace("\"utolsoDatum\"", "\"lastDate\"")
            .Replace("\"vanMaiEtel\"", "\"hasFoodToday\"")
            .Replace("\"jelszoHash\"", "\"passwordHash\"")
            .Replace("\"regisztraltAt\"", "\"registeredAt\"")
            .Replace("\"felhasznalok\"", "\"users\"")
            .Replace("\"kepUrl\"", "\"imageUrl\"")
            .Replace("\"receptbol\"", "\"fromRecipe\"")
            .Replace("\"receptId\"", "\"recipeId\"")
            .Replace("\"adagSzam\"", "\"servings\"");

        public static void Load(
            List<WorkoutSession> workoutHistory,
            Dictionary<string, WorkoutSession> activeByUser)
        {
            try
            {
                Directory.CreateDirectory(DataDir);

                var historyPath = ReadableFile(WorkoutHistoryFile);
                if (historyPath != null)
                {
                    var json = MigrateJson(File.ReadAllText(historyPath));
                    var list = JsonSerializer.Deserialize<List<WorkoutSession>>(json, Opts);
                    if (list != null)
                        workoutHistory.AddRange(list);
                }

                var activePath = ReadableFile(ActiveWorkoutFile);
                if (activePath != null)
                {
                    var json = MigrateJson(File.ReadAllText(activePath));
                    LoadActiveMap(json, activeByUser);
                }

                var plansPath = ReadableFile(PlansFile);
                if (plansPath != null)
                {
                    var json = MigrateJson(File.ReadAllText(plansPath));
                    var plans = JsonSerializer.Deserialize<List<Plan>>(json, Opts);
                    if (plans != null)
                        PlanStore.SavedPlans.AddRange(plans);
                }

                var nutritionPath = ReadableFile(NutritionFile);
                if (nutritionPath != null)
                {
                    var json = MigrateJson(File.ReadAllText(nutritionPath));
                    var logs = JsonSerializer.Deserialize<List<DailyNutritionSession>>(json, Opts);
                    if (logs != null)
                    {
                        var cutoff = DateTime.Today.AddDays(-30);
                        foreach (var log in logs.Where(n => n.Date >= cutoff))
                            NutritionStore.DailyLogs.Add(log);
                    }
                }

                var progressPath = ReadableFile(ProgressFile);
                if (progressPath != null)
                {
                    var json = MigrateJson(File.ReadAllText(progressPath));
                    var settings = JsonSerializer.Deserialize<ProgressSettings>(json, Opts);
                    if (settings != null)
                        PlanStore.Progress = settings;
                }

                var streakPath = ReadableFile(StreakFile);
                if (streakPath != null)
                {
                    var json = MigrateJson(File.ReadAllText(streakPath));
                    var streaks = JsonSerializer.Deserialize<Dictionary<string, StreakState>>(json, Opts);
                    if (streaks != null)
                    {
                        StreakStore.ByUser.Clear();
                        foreach (var (key, value) in streaks)
                            StreakStore.ByUser[key] = value;
                    }
                }

                LoadAccounts();
            }
            catch (Exception ex)
            {
                LastError = $"Betöltés: {ex.Message}";
                Console.WriteLine($"[DataStore] Betöltési hiba: {ex.Message}");
            }
        }

        private static void SafeWrite(string path, string json)
        {
            Directory.CreateDirectory(DataDir);
            var tmp = path + ".tmp";
            File.WriteAllText(tmp, json);
            File.Move(tmp, path, overwrite: true);
        }

        public static void SaveHistory(List<WorkoutSession> workoutHistory)
        {
            try
            {
                var json = JsonSerializer.Serialize(workoutHistory, Opts);
                SafeWrite(WorkoutHistoryFile, json);
            }
            catch (Exception ex)
            {
                LastError = $"Edzéstörténet mentés: {ex.Message}";
                Console.WriteLine($"[DataStore] Edzés mentési hiba: {ex.Message}");
            }
        }

        private static void LoadActiveMap(string json, Dictionary<string, WorkoutSession> activeByUser)
        {
            // New format: { "userName": { session... }, ... }
            try
            {
                using var doc = JsonDocument.Parse(json);
                if (doc.RootElement.ValueKind == JsonValueKind.Object)
                {
                    var looksLikeSession = doc.RootElement.TryGetProperty("isActive", out _)
                        || doc.RootElement.TryGetProperty("exercises", out _)
                        || doc.RootElement.TryGetProperty("title", out _);

                    if (!looksLikeSession)
                    {
                        var map = JsonSerializer.Deserialize<Dictionary<string, WorkoutSession>>(json, Opts);
                        if (map != null)
                        {
                            foreach (var (key, session) in map)
                            {
                                if (session == null || !session.IsActive) continue;
                                session.StartTime = DateTime.Now;
                                if (string.IsNullOrWhiteSpace(session.UserName))
                                    session.UserName = key;
                                activeByUser[key] = session;
                            }
                            return;
                        }
                    }
                }
            }
            catch { /* fall through to legacy single-session format */ }

            var saved = JsonSerializer.Deserialize<WorkoutSession>(json, Opts);
            if (saved != null && saved.IsActive)
            {
                saved.StartTime = DateTime.Now;
                var key = string.IsNullOrWhiteSpace(saved.UserName) ? "_legacy" : saved.UserName;
                activeByUser[key] = saved;
            }
        }

        public static void SaveActiveMap(Dictionary<string, WorkoutSession> activeByUser)
        {
            try
            {
                Directory.CreateDirectory(DataDir);
                if (activeByUser.Count == 0)
                {
                    if (File.Exists(ActiveWorkoutFile)) File.Delete(ActiveWorkoutFile);
                    return;
                }

                var json = JsonSerializer.Serialize(activeByUser, Opts);
                SafeWrite(ActiveWorkoutFile, json);
            }
            catch (Exception ex)
            {
                LastError = $"Aktív edzés mentés: {ex.Message}";
                Console.WriteLine($"[DataStore] Aktív edzés mentési hiba: {ex.Message}");
            }
        }

        /// <summary>Legacy single-session API — prefer SaveActiveMap.</summary>
        public static void ClearActive()
        {
            try
            {
                if (File.Exists(ActiveWorkoutFile)) File.Delete(ActiveWorkoutFile);
            }
            catch { }
        }

        public static void SaveActive(WorkoutSession? active)
        {
            if (active == null)
            {
                ClearActive();
                return;
            }

            var key = string.IsNullOrWhiteSpace(active.UserName) ? "_legacy" : active.UserName;
            SaveActiveMap(new Dictionary<string, WorkoutSession>(StringComparer.OrdinalIgnoreCase)
            {
                [key] = active
            });
        }

        public static void SavePlans()
        {
            try
            {
                var json = JsonSerializer.Serialize(PlanStore.SavedPlans, Opts);
                SafeWrite(PlansFile, json);
            }
            catch (Exception ex)
            {
                LastError = $"Rutin mentés: {ex.Message}";
                Console.WriteLine($"[DataStore] Rutinok mentési hiba: {ex.Message}");
            }
        }

        public static void SaveProgress()
        {
            try
            {
                var json = JsonSerializer.Serialize(PlanStore.Progress, Opts);
                SafeWrite(ProgressFile, json);
            }
            catch (Exception ex)
            {
                LastError = $"Progresszió mentés: {ex.Message}";
                Console.WriteLine($"[DataStore] Progresszió mentési hiba: {ex.Message}");
            }
        }

        public static void SaveStreak()
        {
            try
            {
                var json = JsonSerializer.Serialize(StreakStore.ByUser, Opts);
                SafeWrite(StreakFile, json);
            }
            catch (Exception ex)
            {
                LastError = $"Streak mentés: {ex.Message}";
                Console.WriteLine($"[DataStore] Streak mentési hiba: {ex.Message}");
            }
        }

        public static void SaveNutrition()
        {
            try
            {
                var json = JsonSerializer.Serialize(NutritionStore.DailyLogs, Opts);
                SafeWrite(NutritionFile, json);
            }
            catch (Exception ex)
            {
                LastError = $"Nutrition mentés: {ex.Message}";
                Console.WriteLine($"[DataStore] Nutrition mentési hiba: {ex.Message}");
            }
        }

        public static void LoadAccounts()
        {
            try
            {
                var path = ReadableFile(AccountsFile);
                if (path == null) return;

                var json = MigrateJson(File.ReadAllText(path));
                var package = JsonSerializer.Deserialize<AccountExport>(json, Opts);
                if (package?.Users == null) return;

                AccountStore.Users.Clear();
                AccountStore.Users.AddRange(package.Users);
            }
            catch (Exception ex)
            {
                Console.WriteLine($"[DataStore] Accounts load error: {ex.Message}");
            }
        }

        public static void SaveAccounts()
        {
            try
            {
                var package = new AccountExport
                {
                    Users = AccountStore.Users.ToList()
                };
                var json = JsonSerializer.Serialize(package, Opts);
                SafeWrite(AccountsFile, json);
            }
            catch (Exception ex)
            {
                LastError = $"Accounts save: {ex.Message}";
                Console.WriteLine($"[DataStore] Accounts save error: {ex.Message}");
            }
        }

        public static object Diagnostics(int historyCount, bool hasActiveWorkout)
        {
            string writeTest;
            try
            {
                Directory.CreateDirectory(DataDir);
                var testPath = Path.Combine(DataDir, "iras_teszt.tmp");
                File.WriteAllText(testPath, DateTime.Now.ToString("O"));
                File.Delete(testPath);
                writeTest = "OK";
            }
            catch (Exception ex)
            {
                writeTest = $"HIBA: {ex.Message}";
            }

            static object FileInfo(string path)
            {
                var f = new FileInfo(path);
                return f.Exists
                    ? new { letezik = true, meretByte = f.Length, utolsoIras = f.LastWriteTime }
                    : (object)new { letezik = false, meretByte = 0L, utolsoIras = (DateTime?)null };
            }

            return new
            {
                dataDir = DataDir,
                baseDirectory = AppContext.BaseDirectory,
                currentDirectory = Directory.GetCurrentDirectory(),
                irasTeszt = writeTest,
                utolsoHiba = LastError,
                memoriaban = new
                {
                    edzesTortenet = historyCount,
                    vanAktivEdzes = hasActiveWorkout,
                    rutinok = PlanStore.SavedPlans.Count,
                    progresszio = PlanStore.Progress
                },
                fajlok = new
                {
                    workoutHistory = FileInfo(WorkoutHistoryFile),
                    aktivEdzes = FileInfo(ActiveWorkoutFile),
                    rutinok = FileInfo(PlansFile),
                    progresszio = FileInfo(ProgressFile),
                    nutrition = FileInfo(NutritionFile),
                    felhasznalok = FileInfo(AccountsFile),
                    streak = FileInfo(StreakFile)
                }
            };
        }
    }
}
