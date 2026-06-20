using System.Collections.Concurrent;
using System.Text.Json;

namespace FitnessBackend.Models
{
    /// <summary>
    /// Angol → magyar fordítás a MyMemory ingyenes API-val (kulcs nélkül).
    /// Cache-el és hibatűrő: ha a fordítás nem sikerül, az eredeti szöveg marad.
    /// </summary>
    public static class ForditoSeged
    {
        public static bool Bekapcsolva { get; set; } = true;

        private const string api = "https://api.mymemory.translated.net/get";
        private static readonly HttpClient kliens = new HttpClient { Timeout = TimeSpan.FromSeconds(6) };
        private static readonly ConcurrentDictionary<string, string> cache = new();

        /// <summary>Egy recept-lista címeit fordítja magyarra (párhuzamosan).</summary>
        public static async Task CimekForditasa(List<ReceptListaElem> receptek)
        {
            if (!Bekapcsolva || receptek.Count == 0) return;

            var feladatok = receptek.Select(async r =>
            {
                r.Nev = await Forditas(r.Nev);
            });

            await Task.WhenAll(feladatok);
        }

        /// <summary>Rövid szöveg (cím) fordítása, cache-eléssel.</summary>
        public static async Task<string> Forditas(string angol)
        {
            if (!Bekapcsolva || string.IsNullOrWhiteSpace(angol)) return angol;

            if (cache.TryGetValue(angol, out var kesz)) return kesz;

            try
            {
                string url = $"{api}?q={Uri.EscapeDataString(angol)}&langpair=en|hu";
                string nyers = await kliens.GetStringAsync(url);

                using JsonDocument doc = JsonDocument.Parse(nyers);
                if (doc.RootElement.TryGetProperty("responseData", out var rd) &&
                    rd.TryGetProperty("translatedText", out var tt))
                {
                    string magyar = tt.GetString() ?? angol;
                    if (!string.IsNullOrWhiteSpace(magyar))
                    {
                        cache[angol] = magyar;
                        return magyar;
                    }
                }
            }
            catch (Exception)
            {
                // Hiba esetén marad az eredeti
            }

            cache[angol] = angol;
            return angol;
        }

        /// <summary>Hosszú szöveg (elkészítés) fordítása mondatonként darabolva.</summary>
        public static async Task<string> HosszuForditas(string angol)
        {
            if (!Bekapcsolva || string.IsNullOrWhiteSpace(angol)) return angol;
            if (cache.TryGetValue(angol, out var kesz)) return kesz;

            // MyMemory ~500 karakteres limit — mondatokba darabolunk
            var darabok = DarabolasMondatokra(angol, 450);
            var leforditott = new List<string>();

            foreach (var darab in darabok)
            {
                leforditott.Add(await Forditas(darab));
            }

            string eredmeny = string.Join(" ", leforditott);
            cache[angol] = eredmeny;
            return eredmeny;
        }

        private static List<string> DarabolasMondatokra(string szoveg, int max)
        {
            var darabok = new List<string>();
            var mondatok = szoveg.Split('.', StringSplitOptions.RemoveEmptyEntries);
            var jelenlegi = new System.Text.StringBuilder();

            foreach (var m in mondatok)
            {
                var mondat = m.Trim() + ".";
                if (jelenlegi.Length + mondat.Length > max && jelenlegi.Length > 0)
                {
                    darabok.Add(jelenlegi.ToString());
                    jelenlegi.Clear();
                }
                jelenlegi.Append(mondat).Append(' ');
            }

            if (jelenlegi.Length > 0) darabok.Add(jelenlegi.ToString().Trim());
            return darabok;
        }
    }
}
