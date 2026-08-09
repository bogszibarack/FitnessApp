using System.Collections.Concurrent;
using System.Text.Json;
using FitnessBackend.Models;

namespace FitnessBackend.Services
{
    public static class NutritionService
    {
        private static readonly ConcurrentDictionary<string, (DateTime At, List<FoodItem> Items)> _searchCache = new();
        private static readonly TimeSpan CacheTtl = TimeSpan.FromMinutes(30);

        private const string OffApiBase = "https://world.openfoodfacts.org";
        private const string OffSearchApi = "https://search.openfoodfacts.org/search";
        private const string OffUserAgent = "FitnessBackend/1.0 (flexio; food-search)";

        private static readonly List<FoodItem> OfflineDb = new()
        {
            new() { Id="off_alma",       Name="Alma",            Calories=52,  Protein=0.3, Carbs=14,  Fat=0.2 },
            new() { Id="off_koerte",     Name="Körte",           Calories=57,  Protein=0.4, Carbs=15,  Fat=0.1 },
            new() { Id="off_banan",      Name="Banán",           Calories=89,  Protein=1.1, Carbs=23,  Fat=0.3 },
            new() { Id="off_narancs",    Name="Narancs",         Calories=47,  Protein=0.9, Carbs=12,  Fat=0.1 },
            new() { Id="off_szilva",     Name="Szilva",          Calories=46,  Protein=0.7, Carbs=11,  Fat=0.3 },
            new() { Id="off_eper",       Name="Eper",            Calories=32,  Protein=0.7, Carbs=8,   Fat=0.3 },
            new() { Id="off_afonya",     Name="Áfonya",          Calories=57,  Protein=0.7, Carbs=14,  Fat=0.3 },
            new() { Id="off_grapefrui", Name="Grapefruit",      Calories=42,  Protein=0.8, Carbs=11,  Fat=0.1 },
            new() { Id="off_meggy",      Name="Meggy",           Calories=50,  Protein=1.0, Carbs=12,  Fat=0.3 },
            new() { Id="off_dinnye",     Name="Görögdinnye",     Calories=30,  Protein=0.6, Carbs=8,   Fat=0.2 },
            new() { Id="off_szolo",      Name="Szőlő",           Calories=67,  Protein=0.6, Carbs=17,  Fat=0.4 },
            new() { Id="off_kivi",       Name="Kivi",            Calories=61,  Protein=1.1, Carbs=15,  Fat=0.5 },
            new() { Id="off_mango",      Name="Mangó",           Calories=60,  Protein=0.8, Carbs=15,  Fat=0.4 },
            new() { Id="off_ananas",     Name="Ananász",         Calories=50,  Protein=0.5, Carbs=13,  Fat=0.1 },
            new() { Id="off_citrom",     Name="Citrom",          Calories=29,  Protein=1.1, Carbs=9,   Fat=0.3 },
            new() { Id="off_csirke",     Name="Csirkemell",      Calories=165, Protein=31,  Carbs=0,   Fat=3.6 },
            new() { Id="off_csirkecomb", Name="Csirkecomb",      Calories=215, Protein=26,  Carbs=0,   Fat=12 },
            new() { Id="off_marha",      Name="Marhahús",        Calories=250, Protein=26,  Carbs=0,   Fat=17 },
            new() { Id="off_sertes",     Name="Sertéshús",       Calories=242, Protein=27,  Carbs=0,   Fat=14 },
            new() { Id="off_pulyka",     Name="Pulykamell",      Calories=189, Protein=29,  Carbs=0,   Fat=7.5 },
            new() { Id="off_lazac",      Name="Lazac",           Calories=208, Protein=20,  Carbs=0,   Fat=13 },
            new() { Id="off_tonhal",     Name="Tonhal (konzerv)",Calories=116, Protein=26,  Carbs=0,   Fat=1.0 },
            new() { Id="off_ponty",      Name="Ponty",           Calories=162, Protein=18,  Carbs=0,   Fat=9.0 },
            new() { Id="off_sonka",      Name="Sonka",           Calories=145, Protein=21,  Carbs=1.5, Fat=6.0 },
            new() { Id="off_szalamitmp", Name="Szalámi",         Calories=406, Protein=22,  Carbs=2,   Fat=35 },
            new() { Id="off_tojas",      Name="Tojás (egész)",   Calories=155, Protein=13,  Carbs=1.1, Fat=11 },
            new() { Id="off_tojasfeh",   Name="Tojásfehérje",    Calories=52,  Protein=11,  Carbs=0.7, Fat=0.2 },
            new() { Id="off_tojassarg",  Name="Tojássárgája",    Calories=322, Protein=16,  Carbs=3.6, Fat=27 },
            new() { Id="off_tej",        Name="Tej (2,8%)",      Calories=50,  Protein=3.4, Carbs=4.8, Fat=2.0 },
            new() { Id="off_joghurt",    Name="Joghurt (natúr)", Calories=61,  Protein=3.5, Carbs=4.7, Fat=3.3 },
            new() { Id="off_gorog",      Name="Görög joghurt",   Calories=97,  Protein=9.0, Carbs=3.6, Fat=5.0 },
            new() { Id="off_sajt",       Name="Trappista sajt",  Calories=356, Protein=26,  Carbs=1.3, Fat=28 },
            new() { Id="off_mozzarella", Name="Mozzarella",      Calories=280, Protein=28,  Carbs=2.2, Fat=17 },
            new() { Id="off_turo",       Name="Túró (sovány)",   Calories=98,  Protein=11,  Carbs=3.4, Fat=4.3 },
            new() { Id="off_vaj",        Name="Vaj",             Calories=717, Protein=0.9, Carbs=0.1, Fat=81 },
            new() { Id="off_tejszin",    Name="Tejszín (30%)",   Calories=300, Protein=2.3, Carbs=3.0, Fat=30 },
            new() { Id="off_rizs",       Name="Rizs (főtt)",     Calories=130, Protein=2.7, Carbs=28,  Fat=0.3 },
            new() { Id="off_rizzsnyers", Name="Rizs (nyers)",    Calories=361, Protein=7.0, Carbs=80,  Fat=0.7 },
            new() { Id="off_teszta",     Name="Tészta (főtt)",   Calories=158, Protein=5.8, Carbs=31,  Fat=0.9 },
            new() { Id="off_kenyer",     Name="Kenyér (fehér)",  Calories=265, Protein=9.0, Carbs=49,  Fat=3.2 },
            new() { Id="off_barnaken",   Name="Kenyér (barna)",  Calories=247, Protein=8.9, Carbs=45,  Fat=3.4 },
            new() { Id="off_zab",        Name="Zabpehely",       Calories=389, Protein=17,  Carbs=66,  Fat=7.0 },
            new() { Id="off_zabkasa",    Name="Zabkása (főtt)",  Calories=71,  Protein=2.5, Carbs=12,  Fat=1.4 },
            new() { Id="off_kukoricap",  Name="Kukoricapehely",  Calories=356, Protein=7.5, Carbs=78,  Fat=1.9 },
            new() { Id="off_quinoa",     Name="Quinoa (főtt)",   Calories=120, Protein=4.4, Carbs=22,  Fat=1.9 },
            new() { Id="off_lencse",     Name="Lencse (főtt)",   Calories=116, Protein=9.0, Carbs=20,  Fat=0.4 },
            new() { Id="off_bab",        Name="Bab (főtt)",      Calories=127, Protein=8.7, Carbs=23,  Fat=0.5 },
            new() { Id="off_csicseribo", Name="Csicseriborsó",   Calories=164, Protein=8.9, Carbs=27,  Fat=2.6 },
            new() { Id="off_krumpli",    Name="Burgonya (főtt)", Calories=87,  Protein=1.9, Carbs=20,  Fat=0.1 },
            new() { Id="off_edesburgo",  Name="Édesburgonya",    Calories=86,  Protein=1.6, Carbs=20,  Fat=0.1 },
            new() { Id="off_mogyoro",    Name="Mogyoró",         Calories=607, Protein=14,  Carbs=16,  Fat=56 },
            new() { Id="off_dio",        Name="Dió",             Calories=654, Protein=15,  Carbs=14,  Fat=65 },
            new() { Id="off_mandula",    Name="Mandula",         Calories=579, Protein=21,  Carbs=22,  Fat=50 },
            new() { Id="off_kesudio",    Name="Kesüdió",         Calories=553, Protein=18,  Carbs=30,  Fat=44 },
            new() { Id="off_mogyorova",  Name="Mogyoróvaj",      Calories=588, Protein=25,  Carbs=20,  Fat=50 },
            new() { Id="off_olaj",       Name="Napraforgóolaj",  Calories=884, Protein=0,   Carbs=0,   Fat=100},
            new() { Id="off_olivaolaj",  Name="Olívaolaj",       Calories=884, Protein=0,   Carbs=0,   Fat=100},
            new() { Id="off_avokado",    Name="Avokádó",         Calories=160, Protein=2.0, Carbs=9.0, Fat=15 },
            new() { Id="off_brokkoli",   Name="Brokkoli",        Calories=34,  Protein=2.8, Carbs=7.0, Fat=0.4 },
            new() { Id="off_spenot",     Name="Spenót",          Calories=23,  Protein=2.9, Carbs=3.6, Fat=0.4 },
            new() { Id="off_paradicsom", Name="Paradicsom",      Calories=18,  Protein=0.9, Carbs=3.9, Fat=0.2 },
            new() { Id="off_uborka",     Name="Uborka",          Calories=16,  Protein=0.7, Carbs=3.6, Fat=0.1 },
            new() { Id="off_paprika",    Name="Paprika (piros)", Calories=31,  Protein=1.0, Carbs=6.0, Fat=0.3 },
            new() { Id="off_sarrep",     Name="Sárgarépa",       Calories=41,  Protein=0.9, Carbs=10,  Fat=0.2 },
            new() { Id="off_hagyma",     Name="Vöröshagyma",     Calories=40,  Protein=1.1, Carbs=9.3, Fat=0.1 },
            new() { Id="off_fokhag",     Name="Fokhagyma",       Calories=149, Protein=6.4, Carbs=33,  Fat=0.5 },
            new() { Id="off_cukkini",    Name="Cukkini",         Calories=17,  Protein=1.2, Carbs=3.1, Fat=0.3 },
            new() { Id="off_sutotok",    Name="Sütőtök",         Calories=26,  Protein=1.0, Carbs=6.5, Fat=0.1 },
            new() { Id="off_gomba",      Name="Csiperkegomba",   Calories=22,  Protein=3.1, Carbs=3.3, Fat=0.3 },
            new() { Id="off_salatafej",  Name="Saláta (fejes)",  Calories=15,  Protein=1.4, Carbs=2.9, Fat=0.2 },
            new() { Id="off_kelbimbo",   Name="Kelbimbó",        Calories=43,  Protein=3.4, Carbs=9.0, Fat=0.3 },
            new() { Id="off_karfiol",    Name="Karfiol",         Calories=25,  Protein=1.9, Carbs=5.0, Fat=0.3 },
            new() { Id="off_csokolade",  Name="Étcsokoládé (70%)",Calories=598, Protein=7.8,Carbs=46, Fat=43 },
            new() { Id="off_tejcsoki",   Name="Tejcsokoládé",    Calories=535, Protein=7.7, Carbs=60,  Fat=30 },
            new() { Id="off_mez",        Name="Méz",             Calories=304, Protein=0.3, Carbs=82,  Fat=0 },
            new() { Id="off_cukor",      Name="Cukor",           Calories=387, Protein=0,   Carbs=100, Fat=0 },
            new() { Id="off_lekvár",     Name="Lekvár",          Calories=250, Protein=0.4, Carbs=62,  Fat=0.1 },
            new() { Id="off_feherje_p",  Name="Fehérjepor (vanília)", Calories=380, Protein=77, Carbs=10, Fat=4 },
            new() { Id="off_kreatin",    Name="Kreatin",         Calories=0,   Protein=0,   Carbs=0,   Fat=0 },
            new() { Id="off_rizstejes",  Name="Rizs+tejszín",    Calories=190, Protein=3.5, Carbs=37,  Fat=4 },
            new() { Id="off_rizzspud",   Name="Rizspuding",      Calories=110, Protein=3.2, Carbs=21,  Fat=1.5 },
            // Frequent HU home-cooked / menu items (per 100 g)
            new() { Id="off_rantott_hus", Name="Rántott hús", Calories=280, Protein=18, Carbs=14, Fat=17 },
            new() { Id="off_becsi", Name="Bécsi szelet", Calories=297, Protein=19, Carbs=15, Fat=18 },
            new() { Id="off_rantott_csirk", Name="Rántott csirkemell", Calories=220, Protein=24, Carbs=10, Fat=9 },
            new() { Id="off_rantott_sajt", Name="Rántott sajt", Calories=310, Protein=14, Carbs=18, Fat=20 },
            new() { Id="off_fasirt", Name="Fasírt", Calories=240, Protein=16, Carbs=8, Fat=16 },
            new() { Id="off_porkolt_mar", Name="Marhapörkölt", Calories=180, Protein=18, Carbs=4, Fat=10 },
            new() { Id="off_porkolt_ser", Name="Sertéspörkölt", Calories=195, Protein=17, Carbs=4, Fat=12 },
            new() { Id="off_csirkepapr", Name="Csirkepaprikás", Calories=160, Protein=16, Carbs=5, Fat=8 },
            new() { Id="off_gulyaslev", Name="Gulyásleves", Calories=75, Protein=6, Carbs=6, Fat=3 },
            new() { Id="off_halaszle", Name="Halászlé", Calories=70, Protein=8, Carbs=3, Fat=2.5 },
            new() { Id="off_toltottpap", Name="Töltött paprika", Calories=120, Protein=8, Carbs=10, Fat=5 },
            new() { Id="off_rakottkru", Name="Rakott krumpli", Calories=150, Protein=8, Carbs=14, Fat=7 },
            new() { Id="off_lecso", Name="Lecsó", Calories=55, Protein=1.5, Carbs=7, Fat=2.5 },
            new() { Id="off_nokedli", Name="Nokedli / galuska", Calories=145, Protein=4.5, Carbs=28, Fat=2 },
            new() { Id="off_husleves", Name="Húsleves", Calories=40, Protein=4, Carbs=3, Fat=1.2 },
            new() { Id="off_frankfurti", Name="Frankfurti leves", Calories=55, Protein=3, Carbs=5, Fat=2.5 },
            new() { Id="off_borsoleves", Name="Borsóleves", Calories=55, Protein=3, Carbs=8, Fat=1.5 },
            new() { Id="off_krumplifo", Name="Krumplifőzelék", Calories=80, Protein=2, Carbs=14, Fat=2 },
            new() { Id="off_tokefo", Name="Tökfőzelék", Calories=70, Protein=2, Carbs=10, Fat=2.5 },
            new() { Id="off_spenotfo", Name="Spenótfőzelék", Calories=75, Protein=3.5, Carbs=8, Fat=3.5 },
            new() { Id="off_sultkrum", Name="Sült krumpli / hasáb", Calories=280, Protein=3.5, Carbs=36, Fat=14 },
            new() { Id="off_pizza_sze", Name="Pizza (szelet)", Calories=266, Protein=11, Carbs=33, Fat=10 },
            new() { Id="off_hamburger", Name="Hamburger", Calories=250, Protein=13, Carbs=25, Fat=11 },
            new() { Id="off_hotdog", Name="Hot dog", Calories=290, Protein=11, Carbs=25, Fat=16 },
            new() { Id="off_szendvics", Name="Szendvics (sonkás)", Calories=230, Protein=12, Carbs=25, Fat=9 },
            new() { Id="off_granola", Name="Granola / müzli", Calories=420, Protein=10, Carbs=65, Fat=14 },
            new() { Id="off_smoothie", Name="Gyümölcssmoothie", Calories=60, Protein=1, Carbs=13, Fat=0.5 },
            new() { Id="off_kave_tej", Name="Tejeskávé", Calories=45, Protein=2, Carbs=5, Fat=1.5 },
            new() { Id="off_narancsle", Name="Narancslé", Calories=45, Protein=0.7, Carbs=10, Fat=0.2 },
            new() { Id="off_coca", Name="Üdítő (cola)", Calories=42, Protein=0, Carbs=10.6, Fat=0 },
            new() { Id="off_sor", Name="Sör", Calories=43, Protein=0.5, Carbs=3.6, Fat=0 },
            new() { Id="off_bor_voros", Name="Vörösbor", Calories=85, Protein=0.1, Carbs=2.6, Fat=0 },
            new() { Id="off_langos", Name="Lángos", Calories=310, Protein=6, Carbs=40, Fat=14 },
            new() { Id="off_kurtos", Name="Kürtőskalács", Calories=360, Protein=6, Carbs=55, Fat=13 },
            new() { Id="off_kremes", Name="Krémes", Calories=280, Protein=4, Carbs=35, Fat=14 },
            new() { Id="off_somloi", Name="Somlói galuska", Calories=290, Protein=5, Carbs=40, Fat=12 },
        };

        private static List<FoodItem> SearchOffline(string query)
        {
            string norm = StripAccents(query.Trim().ToLowerInvariant());
            if (norm.Length < 2) return [];

            var tokens = norm.Split(' ', StringSplitOptions.RemoveEmptyEntries | StringSplitOptions.TrimEntries);
            string english = StripAccents(SearchQueryTranslator.ToEnglish(query).ToLowerInvariant());
            var engTokens = english.Split(' ', StringSplitOptions.RemoveEmptyEntries);

            return OfflineDb
                .Select(f =>
                {
                    string nameNorm = StripAccents(f.Name.ToLowerInvariant());
                    int score = 0;
                    if (nameNorm == norm || nameNorm == english) score = 100;
                    else if (nameNorm.StartsWith(norm, StringComparison.Ordinal) ||
                             nameNorm.StartsWith(english, StringComparison.Ordinal)) score = 80;
                    else if (nameNorm.Contains(norm, StringComparison.Ordinal) ||
                             (english.Length >= 3 && nameNorm.Contains(english, StringComparison.Ordinal))) score = 60;
                    else if (tokens.Length > 0 && tokens.All(t => nameNorm.Contains(t, StringComparison.Ordinal)))
                        score = 50;
                    else if (engTokens.Length > 0 &&
                             engTokens.All(t => t.Length < 3 || nameNorm.Contains(t, StringComparison.Ordinal)) &&
                             engTokens.Any(t => t.Length >= 3))
                        score = 45;
                    return (Food: f, Score: score);
                })
                .Where(x => x.Score >= 40)
                .OrderByDescending(x => x.Score)
                .ThenBy(x => x.Food.Name.Length)
                .Select(x => x.Food)
                .Take(10)
                .ToList();
        }

        private static string StripAccents(string s) =>
            s.Replace('á', 'a').Replace('é', 'e').Replace('í', 'i')
             .Replace('ó', 'o').Replace('ö', 'o').Replace('ő', 'o')
             .Replace('ú', 'u').Replace('ü', 'u').Replace('ű', 'u');

        public static async Task<List<FoodItem>> SearchFoodAsync(string query)
        {
            string key = query.Trim().ToLowerInvariant();
            if (key.Length < 2) return [];

            if (_searchCache.TryGetValue(key, out var cached) &&
                DateTime.UtcNow - cached.At < CacheTtl &&
                cached.Items.Count > 0)
                return cached.Items;

            var results = new List<FoodItem>();
            var seen = new HashSet<string>(StringComparer.OrdinalIgnoreCase);

            void AddRange(IEnumerable<FoodItem> items)
            {
                foreach (var item in items)
                {
                    if (string.IsNullOrWhiteSpace(item.Id) || !seen.Add(item.Id)) continue;
                    results.Add(item);
                }
            }

            AddRange(SearchOffline(query));

            if (FatSecretConfig.HasCredentials)
            {
                try
                {
                    AddRange(await FatSecretApi.SearchAsync(query, 15));
                }
                catch (Exception ex)
                {
                    Console.WriteLine($"[Nutrition] FatSecret search failed: {ex.Message}");
                }
            }

            // FatSecret creds are often missing/invalid on Render — OFF fills the gap.
            if (results.Count < 12)
            {
                try
                {
                    var off = await SearchOpenFoodFactsAsync(query, 12);
                    Console.WriteLine($"[Nutrition] OFF '{query}' → {off.Count} hits (before merge had {results.Count})");
                    AddRange(off);
                }
                catch (Exception ex)
                {
                    Console.WriteLine($"[Nutrition] OpenFoodFacts search failed: {ex.Message}");
                }
            }

            // Re-rank merged list by token overlap with the user query.
            results = RankFoodResults(query, results).Take(20).ToList();

            // Cache even small curated hits (e.g. single offline "Rántott hús").
            if (results.Count > 0)
                _searchCache[key] = (DateTime.UtcNow, results);

            return results;
        }

        private static List<FoodItem> RankFoodResults(string query, List<FoodItem> items)
        {
            string norm = StripAccents(query.Trim().ToLowerInvariant());
            var tokens = norm.Split(' ', StringSplitOptions.RemoveEmptyEntries)
                .Where(t => t.Length >= 2)
                .ToArray();
            string english = StripAccents(SearchQueryTranslator.ToEnglish(query).ToLowerInvariant());
            var engTokens = english.Split(' ', StringSplitOptions.RemoveEmptyEntries)
                .Where(t => t.Length >= 2)
                .ToArray();

            var ranked = items
                .Select(item =>
                {
                    string name = StripAccents(item.Name.ToLowerInvariant());
                    int score = 0;
                    if (name == norm || name == english) score += 100;
                    if (name.StartsWith(norm, StringComparison.Ordinal) ||
                        name.StartsWith(english, StringComparison.Ordinal)) score += 50;
                    if (name.Contains(norm, StringComparison.Ordinal) ||
                        (english.Length >= 3 && name.Contains(english, StringComparison.Ordinal))) score += 25;
                    int huHits = tokens.Count(t => name.Contains(t, StringComparison.Ordinal));
                    int enHits = engTokens.Count(t => name.Contains(t, StringComparison.Ordinal));
                    score += Math.Max(huHits, enHits) * 12;
                    if (item.Id.StartsWith("off_", StringComparison.Ordinal)) score += 8; // curated offline
                    return (Item: item, Score: score, Hits: Math.Max(huHits, enHits));
                })
                .Where(x => x.Score > 0)
                // Drop OFF noise with zero token overlap when we have better matches
                .Where(x => x.Hits > 0 || x.Item.Id.StartsWith("off_", StringComparison.Ordinal) || x.Score >= 25)
                .OrderByDescending(x => x.Score)
                .Select(x => x.Item)
                .ToList();

            return ranked;
        }

        private static async Task<List<FoodItem>> SearchOpenFoodFactsAsync(string query, int max)
        {
            using var client = new HttpClient();
            client.DefaultRequestHeaders.TryAddWithoutValidation("User-Agent", OffUserAgent);
            client.Timeout = TimeSpan.FromSeconds(12);

            var results = new List<FoodItem>();
            var seen = new HashSet<string>(StringComparer.OrdinalIgnoreCase);

            void AddProduct(JsonElement product)
            {
                if (results.Count >= max) return;
                var food = FromOffProduct(product);
                if (food == null || food.Calories <= 0) return;
                if (!seen.Add(food.Id)) return;
                results.Add(food);
            }

            // 1) search-a-licious (more reliable than cgi/search.pl from cloud IPs)
            foreach (string term in SearchQueryTranslator.SearchExpressions(query).Take(4))
            {
                if (results.Count >= max) break;
                try
                {
                    string url =
                        $"{OffSearchApi}?q={Uri.EscapeDataString(term)}&page_size={Math.Min(max, 12)}&langs=hu";
                    using var resp = await client.GetAsync(url);
                    if (!resp.IsSuccessStatusCode) continue;
                    string raw = await resp.Content.ReadAsStringAsync();
                    using var doc = JsonDocument.Parse(raw);
                    if (!doc.RootElement.TryGetProperty("hits", out var hits) ||
                        hits.ValueKind != JsonValueKind.Array)
                        continue;
                    foreach (var hit in hits.EnumerateArray())
                        AddProduct(hit);
                }
                catch (Exception ex)
                {
                    Console.WriteLine($"[Nutrition] OFF search-a-licious '{term}' failed: {ex.Message}");
                }
            }

            // 2) Legacy cgi/search.pl fallback if still thin
            if (results.Count < 4)
            {
                foreach (string term in SearchQueryTranslator.SearchExpressions(query).Take(3))
                {
                    if (results.Count >= max) break;
                    try
                    {
                        string url =
                            $"{OffApiBase}/cgi/search.pl?search_terms={Uri.EscapeDataString(term)}" +
                            "&search_simple=1&action=process&json=1" +
                            $"&page_size={Math.Min(max, 12)}";
                        using var resp = await client.GetAsync(url);
                        if (!resp.IsSuccessStatusCode) continue;
                        string raw = await resp.Content.ReadAsStringAsync();
                        using var doc = JsonDocument.Parse(raw);
                        if (!doc.RootElement.TryGetProperty("products", out var products) ||
                            products.ValueKind != JsonValueKind.Array)
                            continue;
                        foreach (var product in products.EnumerateArray())
                            AddProduct(product);
                    }
                    catch
                    {
                        // ignore — search-a-licious is primary
                    }
                }
            }

            return results;
        }

        public static async Task<(FoodItem? Food, string? Error, int Status)> LookupBarcodeAsync(string barcode)
        {
            try
            {
                if (FatSecretConfig.HasCredentials)
                {
                    var fs = await FatSecretApi.LookupBarcodeAsync(barcode);
                    if (fs != null) return (fs, null, 200);
                }

                using var client = new HttpClient();
                client.DefaultRequestHeaders.Add("User-Agent", OffUserAgent);

                string url = $"{OffApiBase}/api/v2/product/{barcode}.json" +
                             "?fields=code,product_name,product_name_hu,product_name_en,brands,nutriments,image_front_thumb_url";
                string raw = await client.GetStringAsync(url);

                using JsonDocument doc = JsonDocument.Parse(raw);
                int status = doc.RootElement.TryGetProperty("status", out var s) ? s.GetInt32() : 0;

                if (status != 1 || !doc.RootElement.TryGetProperty("product", out var product))
                    return (null, "Nem talalhato termek ehhez a vonalkodhoz.", 404);

                var food = FromOffProduct(product);
                if (food == null) return (null, "A termek adatai hianyosak.", 404);

                return (food, null, 200);
            }
            catch (Exception)
            {
                return (null, "A vonalkod-adatbazis nem elerheto. Probald ujra kesobb!", 503);
            }
        }

        public static DailyNutritionSession GetLog(DateTime date) =>
            NutritionStore.GetOrCreateLog(date);

        public static object MealSummary(string mealType)
        {
            var log = GetLog(DateTime.Today);
            var foods = log.EatenFoods
                .Where(e => e.MealType.Equals(mealType, StringComparison.OrdinalIgnoreCase))
                .ToList();

            return new
            {
                meal = mealType,
                foods,
                totalCalories = Math.Round(foods.Sum(e => e.CalculatedCalories), 1),
                totalProtein = Math.Round(foods.Sum(e => e.CalculatedProtein), 1),
                etkezes = mealType,
                etelek = foods,
                ossz_kaloria = Math.Round(foods.Sum(e => e.CalculatedCalories), 1),
                ossz_feherje = Math.Round(foods.Sum(e => e.CalculatedProtein), 1),
            };
        }

        public static DailyNutritionSession SetTargetCalories(double target)
        {
            var log = GetLog(DateTime.Today);
            log.TargetCalories = target;
            DataStore.SaveNutrition();
            return log;
        }

        public static (DailyNutritionSession? Log, string? Error) AddFood(LoggedFood food)
        {
            if (!food.FromRecipe && food.AmountGrams <= 0)
                return (null, "Az AmountGrams (gramm) kotelezo es nagyobb mint 0.");

            var log = GetLog(DateTime.Today);
            log.EatenFoods.Add(food);
            DataStore.SaveNutrition();
            return (log, null);
        }

        public static Task<(DailyNutritionSession? log, LoggedFood? entry, string? error)> AddRecipeAsync(AddRecipeRequest request) =>
            NutritionStore.AddRecipeAsync(request);

        public static List<LoggedFood> TodaysRecipes() =>
            GetLog(DateTime.Today).EatenFoods.Where(e => e.FromRecipe).ToList();

        public static (DailyNutritionSession? Log, string? Error) UpdateFood(int index, LoggedFood food)
        {
            var log = GetLog(DateTime.Today);
            if (index < 0 || index >= log.EatenFoods.Count)
                return (null, "Nincs ilyen etel a mai naploban.");
            log.EatenFoods[index] = food;
            DataStore.SaveNutrition();
            return (log, null);
        }

        public static (DailyNutritionSession? Log, string? Error) DeleteFood(int index)
        {
            var log = GetLog(DateTime.Today);
            if (index < 0 || index >= log.EatenFoods.Count)
                return (null, "Nincs ilyen etel a mai naploban.");
            log.EatenFoods.RemoveAt(index);
            DataStore.SaveNutrition();
            return (log, null);
        }

        private static FoodItem? FromOffProduct(JsonElement product)
        {
            string name = OffProductName(product);
            if (string.IsNullOrWhiteSpace(name)) return null;

            string brand = product.TryGetProperty("brands", out var m) ? m.GetString() ?? "" : "";
            string fullName = string.IsNullOrWhiteSpace(brand) ? name : $"[{brand}] {name}";
            string id = product.TryGetProperty("code", out var c) ? c.GetString() ?? "0" : "0";
            string image = "";
            foreach (var imgField in new[] { "image_front_thumb_url", "image_front_small_url", "image_thumb_url" })
            {
                if (product.TryGetProperty(imgField, out var k) && k.ValueKind == JsonValueKind.String)
                {
                    image = k.GetString() ?? "";
                    if (!string.IsNullOrWhiteSpace(image)) break;
                }
            }

            double kcal = 0, protein = 0, carbs = 0, fat = 0;

            if (product.TryGetProperty("nutriments", out var nu))
            {
                kcal = OffNutrient(nu, "energy-kcal_100g");
                if (kcal <= 0)
                {
                    double kj = OffNutrient(nu, "energy-kj_100g");
                    if (kj > 0) kcal = kj / 4.184;
                }
                protein = OffNutrient(nu, "proteins_100g");
                carbs = OffNutrient(nu, "carbohydrates_100g");
                fat = OffNutrient(nu, "fat_100g");
            }

            return new FoodItem
            {
                Id = id,
                Name = fullName,
                Calories = Math.Round(kcal, 1),
                Protein = Math.Round(protein, 1),
                Carbs = Math.Round(carbs, 1),
                Fat = Math.Round(fat, 1),
                ImageUrl = image
            };
        }

        private static string OffProductName(JsonElement product)
        {
            foreach (var field in new[] { "product_name_hu", "product_name_en", "product_name" })
            {
                if (product.TryGetProperty(field, out var v) && v.ValueKind == JsonValueKind.String)
                {
                    string s = v.GetString() ?? "";
                    if (!string.IsNullOrWhiteSpace(s)) return s;
                }
            }
            return "";
        }

        private static double OffNutrient(JsonElement nu, string field)
        {
            if (!nu.TryGetProperty(field, out var e)) return 0;
            if (e.ValueKind == JsonValueKind.Number) return e.GetDouble();
            if (e.ValueKind == JsonValueKind.String &&
                double.TryParse(e.GetString(), System.Globalization.NumberStyles.Any,
                    System.Globalization.CultureInfo.InvariantCulture, out var v))
                return v;
            return 0;
        }
    }
}
