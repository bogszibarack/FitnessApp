using System.Text.Json;
using FitnessBackend.Models;

namespace FitnessBackend.Services
{
    public static class ExerciseService
    {
        private static List<Exercise> _all = new();

        private const string GymJsonUrl =
            "https://raw.githubusercontent.com/yuhonas/free-exercise-db/main/dist/exercises.json";
        private const string GymImageBase =
            "https://raw.githubusercontent.com/yuhonas/free-exercise-db/main/exercises/";
        private const string YogaApiUrl = "https://yoga-api-nzy4.onrender.com/v1/poses";

        public static readonly List<string> MuscleGroups =
        [
            "All Muscles", "Abdominals", "Abductors", "Adductors", "Biceps", "Calves",
            "Cardio", "Chest", "Forearms", "Full Body", "Glutes", "Hamstrings",
            "Lats", "Lower Back", "Neck", "Quadriceps", "Shoulders", "Traps",
            "Triceps", "Upper Back", "Other"
        ];

        public static readonly List<string> EquipmentTypes =
        [
            "All Equipment", "None", "Barbell", "Dumbbell", "Kettlebell", "Machine",
            "Plate", "Resistance Band", "Suspension Band", "Other"
        ];

        private static readonly Dictionary<string, string> MuscleMap = new(StringComparer.OrdinalIgnoreCase)
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

        private static readonly Dictionary<string, string> EquipmentMap = new(StringComparer.OrdinalIgnoreCase)
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

        public static async Task<List<Exercise>> GetAllAsync()
        {
            if (_all.Count == 0)
                await DownloadAllAsync();
            return _all;
        }

        public static async Task<string> DownloadAllAsync()
        {
            using var client = new HttpClient();
            client.DefaultRequestHeaders.Add("User-Agent", "Flexio Fitness App");
            var opts = new JsonSerializerOptions { PropertyNameCaseInsensitive = true };

            _all.Clear();
            await LoadGymAsync(client, opts);
            await LoadYogaAsync(client);
            return $"Sikeres letoltes! Osszesen {_all.Count} db gyakorlat.";
        }

        public static async Task<List<Exercise>> SearchAsync(
            string? q = null,
            string? muscle = null,
            string? equipment = null,
            string? category = null)
        {
            var list = (await GetAllAsync()).AsEnumerable();

            if (!string.IsNullOrWhiteSpace(category) &&
                !category.Equals("all", StringComparison.OrdinalIgnoreCase))
            {
                list = list.Where(e => e.Category.Equals(category, StringComparison.OrdinalIgnoreCase));
            }

            if (!string.IsNullOrWhiteSpace(muscle) &&
                !muscle.Equals("All Muscles", StringComparison.OrdinalIgnoreCase))
            {
                list = list.Where(e => e.MuscleGroup.Equals(muscle, StringComparison.OrdinalIgnoreCase));
            }

            if (!string.IsNullOrWhiteSpace(equipment) &&
                !equipment.Equals("All Equipment", StringComparison.OrdinalIgnoreCase))
            {
                list = list.Where(e => e.Equipment.Equals(equipment, StringComparison.OrdinalIgnoreCase));
            }

            if (!string.IsNullOrWhiteSpace(q))
            {
                list = list.Where(e => MatchesQuery(e, q));
            }

            return list.ToList();
        }

        public static async Task<Exercise?> GetByIdAsync(string id)
        {
            var all = await GetAllAsync();
            return all.FirstOrDefault(e => e.Id.Equals(id, StringComparison.OrdinalIgnoreCase));
        }

        public static async Task<List<Exercise>> ByCategoryAsync(string category)
        {
            var all = await GetAllAsync();
            return all.Where(e => e.Category.Equals(category, StringComparison.OrdinalIgnoreCase)).ToList();
        }

        private static bool MatchesQuery(Exercise exercise, string q) =>
            exercise.Id.Contains(q, StringComparison.OrdinalIgnoreCase) ||
            exercise.Name.Contains(q, StringComparison.OrdinalIgnoreCase);

        private static async Task LoadGymAsync(HttpClient client, JsonSerializerOptions opts)
        {
            try
            {
                var json = await client.GetStringAsync(GymJsonUrl);
                var gym = JsonSerializer.Deserialize<List<Exercise>>(json, opts);
                if (gym == null) return;

                foreach (var item in gym)
                {
                    var originalCategory = item.Category ?? "";
                    item.MuscleGroup = MapMuscle(item, originalCategory);
                    item.Equipment = MapEquipment(item.Equipment);
                    item.Category = "gym";

                    if (item.Images != null)
                    {
                        item.Images = item.Images
                            .Select(img => img.StartsWith("http") ? img : GymImageBase + img)
                            .ToList();
                    }

                    _all.Add(item);
                }
            }
            catch { }
        }

        private static async Task LoadYogaAsync(HttpClient client)
        {
            try
            {
                var json = await client.GetStringAsync(YogaApiUrl);
                using var doc = JsonDocument.Parse(json);
                if (doc.RootElement.ValueKind != JsonValueKind.Array) return;

                foreach (var el in doc.RootElement.EnumerateArray())
                {
                    var id = el.TryGetProperty("id", out var idEl) ? idEl.GetInt32().ToString() : "0";
                    var en = el.TryGetProperty("english_name", out var enEl) ? enEl.GetString() ?? "" : "";
                    var sa = el.TryGetProperty("sanskrit_name_adapted", out var saEl) ? saEl.GetString() ?? "" : "";
                    var desc = el.TryGetProperty("pose_description", out var dEl) ? dEl.GetString() ?? "" : "";
                    var benefits = el.TryGetProperty("pose_benefits", out var bEl) ? bEl.GetString() ?? "" : "";
                    var level = el.TryGetProperty("difficulty_level", out var lEl) ? lEl.GetString() ?? "beginner" : "beginner";
                    var png = el.TryGetProperty("url_png", out var pEl) ? pEl.GetString() ?? "" : "";
                    var svg = el.TryGetProperty("url_svg", out var sEl) ? sEl.GetString() ?? "" : "";

                    var instructions = new List<string>();
                    if (!string.IsNullOrWhiteSpace(desc)) instructions.Add(desc);
                    if (!string.IsNullOrWhiteSpace(benefits)) instructions.Add(benefits);

                    var images = new List<string>();
                    if (!string.IsNullOrWhiteSpace(png)) images.Add(png);
                    if (!string.IsNullOrWhiteSpace(svg)) images.Add(svg);

                    _all.Add(new Exercise
                    {
                        Id = $"yoga_{id}",
                        Name = string.IsNullOrWhiteSpace(sa) ? en : $"{en} ({sa})",
                        Category = "yoga",
                        MuscleGroup = "Full Body",
                        Equipment = "None",
                        Level = level.ToLower(),
                        Instructions = instructions,
                        Images = images
                    });
                }
            }
            catch { }
        }

        private static string MapMuscle(Exercise gym, string originalCategory)
        {
            if (originalCategory.Equals("cardio", StringComparison.OrdinalIgnoreCase))
                return "Cardio";

            if (gym.PrimaryMuscles != null && gym.PrimaryMuscles.Count > 0)
            {
                var raw = gym.PrimaryMuscles[0];
                if (MuscleMap.TryGetValue(raw, out var mapped))
                    return mapped;
            }

            return "Other";
        }

        private static string MapEquipment(string? raw)
        {
            if (string.IsNullOrWhiteSpace(raw)) return "None";
            return EquipmentMap.TryGetValue(raw, out var mapped) ? mapped : "Other";
        }
    }
}
