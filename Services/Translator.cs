using System.Collections.Concurrent;
using System.Text.Json;
using FitnessBackend.Models;

namespace FitnessBackend.Services
{
    /// <summary>
    /// English → Hungarian via MyMemory free API (no key).
    /// Cached and fault-tolerant: on failure the original text is kept.
    /// </summary>
    public static class Translator
    {
        public static bool Enabled { get; set; } = true;

        private const string ApiUrl = "https://api.mymemory.translated.net/get";
        private static readonly HttpClient Http = new() { Timeout = TimeSpan.FromSeconds(6) };
        private static readonly ConcurrentDictionary<string, string> Cache = new();

        public static async Task TranslateTitlesAsync(List<RecipeListItem> recipes)
        {
            if (!Enabled || recipes.Count == 0) return;

            var tasks = recipes.Select(async r =>
            {
                r.Name = await TranslateAsync(r.Name);
            });

            await Task.WhenAll(tasks);
        }

        public static async Task<string> TranslateAsync(string english)
        {
            if (!Enabled || string.IsNullOrWhiteSpace(english)) return english;

            if (Cache.TryGetValue(english, out var cached)) return cached;

            try
            {
                string url = $"{ApiUrl}?q={Uri.EscapeDataString(english)}&langpair=en|hu";
                string raw = await Http.GetStringAsync(url);

                using JsonDocument doc = JsonDocument.Parse(raw);
                if (doc.RootElement.TryGetProperty("responseData", out var rd) &&
                    rd.TryGetProperty("translatedText", out var tt))
                {
                    string hungarian = tt.GetString() ?? english;
                    if (!string.IsNullOrWhiteSpace(hungarian))
                    {
                        Cache[english] = hungarian;
                        return hungarian;
                    }
                }
            }
            catch (Exception)
            {
                // Keep original on failure
            }

            Cache[english] = english;
            return english;
        }

        public static async Task<string> TranslateLongAsync(string english)
        {
            if (!Enabled || string.IsNullOrWhiteSpace(english)) return english;
            if (Cache.TryGetValue(english, out var cached)) return cached;

            var chunks = SplitIntoSentences(english, 450);
            var translated = new List<string>();

            foreach (var chunk in chunks)
                translated.Add(await TranslateAsync(chunk));

            string result = string.Join(" ", translated);
            Cache[english] = result;
            return result;
        }

        private static List<string> SplitIntoSentences(string text, int maxLen)
        {
            var chunks = new List<string>();
            var sentences = text.Split('.', StringSplitOptions.RemoveEmptyEntries);
            var current = new System.Text.StringBuilder();

            foreach (var s in sentences)
            {
                var sentence = s.Trim() + ".";
                if (current.Length + sentence.Length > maxLen && current.Length > 0)
                {
                    chunks.Add(current.ToString());
                    current.Clear();
                }
                current.Append(sentence).Append(' ');
            }

            if (current.Length > 0) chunks.Add(current.ToString().Trim());
            return chunks;
        }
    }
}
