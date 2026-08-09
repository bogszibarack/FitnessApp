namespace FitnessBackend.Services
{
    /// <summary>Hungarian food/search terms → English (FatSecret / Open Food Facts).</summary>
    public static class SearchQueryTranslator
    {
        /// <summary>Multi-word HU phrases (checked before single words).</summary>
        private static readonly Dictionary<string, string> Phrases = new(StringComparer.OrdinalIgnoreCase)
        {
            ["rántott hús"] = "schnitzel",
            ["rantott hus"] = "schnitzel",
            ["bécsi szelet"] = "wiener schnitzel",
            ["becsi szelet"] = "wiener schnitzel",
            ["rántott csirkemell"] = "breaded chicken breast",
            ["rantott csirkemell"] = "breaded chicken breast",
            ["rántott sajt"] = "breaded cheese",
            ["görög joghurt"] = "greek yogurt",
            ["gorog joghurt"] = "greek yogurt",
            ["túró rudi"] = "cottage cheese bar",
            ["turo rudi"] = "cottage cheese bar",
            ["főtt rizs"] = "cooked rice",
            ["fott rizs"] = "cooked rice",
            ["főtt tészta"] = "cooked pasta",
            ["fott teszta"] = "cooked pasta",
            ["főtt burgonya"] = "boiled potato",
            ["sült krumpli"] = "french fries",
            ["sult krumpli"] = "french fries",
            ["hasábburgonya"] = "french fries",
            ["hasabburgonya"] = "french fries",
            ["csirkemell filé"] = "chicken breast",
            ["csirkemell file"] = "chicken breast",
            ["marhahús"] = "beef",
            ["sertéshús"] = "pork",
            ["pulykamell"] = "turkey breast",
            ["rántott csirke"] = "breaded chicken",
            ["nokedli"] = "spaetzle",
            ["galuska"] = "spaetzle",
            ["meggyes pite"] = "cherry pie",
            ["almás pite"] = "apple pie",
            ["kakaós csiga"] = "cinnamon roll",
            ["tejbegríz"] = "semolina pudding",
            ["tejberizs"] = "rice pudding",
            ["zöldborsó"] = "green peas",
            ["zoldborso"] = "green peas",
            ["vörösbor"] = "red wine",
            ["fehérbor"] = "white wine",
        };

        private static readonly Dictionary<string, string> Dictionary = new(StringComparer.OrdinalIgnoreCase)
        {
            ["alma"] = "apple", ["banán"] = "banana", ["eper"] = "strawberry", ["áfonya"] = "blueberry",
            ["csirke"] = "chicken", ["marha"] = "beef", ["sertés"] = "pork", ["hal"] = "fish",
            ["lazac"] = "salmon", ["tonhal"] = "tuna", ["pulyka"] = "turkey", ["sonka"] = "ham",
            ["tojás"] = "egg", ["rizs"] = "rice", ["tészta"] = "pasta", ["kenyér"] = "bread",
            ["sajt"] = "cheese", ["túró"] = "cottage cheese", ["joghurt"] = "yogurt", ["tej"] = "milk",
            ["zab"] = "oats", ["zabkása"] = "oatmeal", ["zabpehely"] = "oats", ["müzli"] = "granola", ["palacsinta"] = "pancake",
            ["saláta"] = "salad", ["leves"] = "soup", ["pizza"] = "pizza", ["szendvics"] = "sandwich",
            ["brokkoli"] = "broccoli", ["paradicsom"] = "tomato", ["uborka"] = "cucumber", ["sárgarépa"] = "carrot",
            ["krumpli"] = "potato", ["burgonya"] = "potato", ["avokádó"] = "avocado", ["spenót"] = "spinach",
            ["bab"] = "beans", ["lencse"] = "lentil", ["csicseriborsó"] = "chickpea", ["gomba"] = "mushroom",
            ["sütőtök"] = "pumpkin", ["cukkini"] = "zucchini", ["paprika"] = "pepper", ["hagyma"] = "onion",
            ["fokhagyma"] = "garlic", ["csokoládé"] = "chocolate", ["csoki"] = "chocolate", ["méz"] = "honey",
            ["dió"] = "walnut", ["mandula"] = "almond", ["mogyoró"] = "peanut", ["smoothie"] = "smoothie",
            ["fehérje"] = "protein", ["zöldség"] = "vegetable", ["gyümölcs"] = "fruit", ["quinoa"] = "quinoa",
            ["gofri"] = "waffle", ["omlett"] = "omelette", ["rántotta"] = "scrambled eggs", ["wrap"] = "wrap",
            ["curry"] = "curry", ["chili"] = "chili", ["burger"] = "burger", ["taco"] = "taco",
            ["bárány"] = "lamb", ["kecske"] = "goat", ["tengeri"] = "seafood", ["garnéla"] = "prawn",
            ["répa"] = "carrot", ["cékla"] = "beetroot", ["édeskömény"] = "fennel", ["padlizsán"] = "aubergine",
            ["hús"] = "meat", ["hus"] = "meat", ["rántott"] = "breaded", ["rantott"] = "breaded",
            ["pörkölt"] = "stew", ["porkolt"] = "stew", ["gulyás"] = "goulash", ["gulyas"] = "goulash",
            ["fasírt"] = "meatball", ["fasirt"] = "meatball", ["kolbász"] = "sausage", ["kolbasz"] = "sausage",
            ["szalámi"] = "salami", ["szalami"] = "salami", ["bacon"] = "bacon", ["szalonna"] = "bacon",
            ["nokedli"] = "spaetzle", ["galuska"] = "spaetzle", ["tarhonya"] = "egg barley",
            ["főzelék"] = "vegetable stew", ["fozelek"] = "vegetable stew", ["pánkó"] = "breadcrumbs",
            ["zsemlemorzsa"] = "breadcrumbs", ["tejföl"] = "sour cream", ["tejfol"] = "sour cream",
            ["tejszín"] = "cream", ["tejszin"] = "cream", ["vaj"] = "butter", ["margarin"] = "margarine",
            ["olaj"] = "oil", ["cukor"] = "sugar", ["liszt"] = "flour", ["élesztő"] = "yeast",
            ["csirkemell"] = "chicken breast", ["csirkecomb"] = "chicken thigh", ["pulykamell"] = "turkey breast",
            ["marhahús"] = "beef", ["sertéshús"] = "pork", ["rizspehely"] = "rice cakes",
            ["görögjoghurt"] = "greek yogurt", ["fehérjepor"] = "protein powder",
            ["étcsokoládé"] = "dark chocolate", ["tejcsokoládé"] = "milk chocolate",
            ["édesburgonya"] = "sweet potato", ["vöröshagyma"] = "onion", ["olívaolaj"] = "olive oil",
            ["napraforgóolaj"] = "sunflower oil", ["mogyoróvaj"] = "peanut butter",
            ["rizspuding"] = "rice pudding", ["kukoricapehely"] = "corn flakes",
            ["schnitzel"] = "schnitzel", ["szelet"] = "cutlet",
        };

        public static string ToEnglish(string hungarian)
        {
            if (string.IsNullOrWhiteSpace(hungarian)) return hungarian;

            string remaining = hungarian.Trim();
            string normFull = StripAccents(remaining);

            foreach (var pair in Phrases.OrderByDescending(p => p.Key.Length))
            {
                if (remaining.Equals(pair.Key, StringComparison.OrdinalIgnoreCase) ||
                    normFull.Equals(StripAccents(pair.Key), StringComparison.OrdinalIgnoreCase))
                    return pair.Value;
            }

            // Replace known phrases inside longer queries.
            string working = remaining;
            foreach (var pair in Phrases.OrderByDescending(p => p.Key.Length))
            {
                working = ReplaceInsensitive(working, pair.Key, pair.Value);
                working = ReplaceInsensitive(working, StripAccents(pair.Key), pair.Value);
            }

            var words = working.Split(' ', StringSplitOptions.RemoveEmptyEntries);
            var result = words.Select(TranslateWord);
            return string.Join(' ', result);
        }

        /// <summary>Query variants to try against external food APIs (HU + EN + synonyms).</summary>
        public static IEnumerable<string> SearchExpressions(string query)
        {
            var seen = new HashSet<string>(StringComparer.OrdinalIgnoreCase);
            var list = new List<string>();
            void add(string? s)
            {
                if (string.IsNullOrWhiteSpace(s)) return;
                s = s.Trim();
                if (s.Length < 2) return;
                if (seen.Add(s)) list.Add(s);
            }

            string raw = query.Trim();
            add(raw);
            add(StripAccents(raw));

            string english = ToEnglish(raw);
            add(english);

            // Phrase synonym extras
            string norm = StripAccents(raw.ToLowerInvariant());
            if (norm.Contains("rantott") && (norm.Contains("hus") || norm.Contains("szelet") || norm.Contains("csirke")))
            {
                add("schnitzel");
                add("breaded");
                add("paniert");
            }
            if (norm.Contains("becsi") && norm.Contains("szelet"))
            {
                add("wiener schnitzel");
                add("schnitzel");
            }

            // Also try the strongest single HU token (e.g. "rántott" from "rántott hús")
            foreach (var token in raw.Split(' ', StringSplitOptions.RemoveEmptyEntries))
            {
                if (token.Length < 4) continue;
                add(token);
                add(TranslateWord(token));
            }

            return list;
        }

        private static string TranslateWord(string word)
        {
            if (Dictionary.TryGetValue(word, out var a1)) return a1;
            string norm = StripAccents(word);
            if (Dictionary.TryGetValue(norm, out var a2)) return a2;
            foreach (var pair in Dictionary.OrderByDescending(p => p.Key.Length))
            {
                string keyNorm = StripAccents(pair.Key);
                if (keyNorm.Equals(norm, StringComparison.OrdinalIgnoreCase))
                    return pair.Value;
                // Exact-ish stem: only if key is prefix and leftover is short inflection (max 3 chars)
                if (norm.Length >= 5 && keyNorm.Length >= 5 &&
                    norm.StartsWith(keyNorm, StringComparison.OrdinalIgnoreCase) &&
                    norm.Length - keyNorm.Length <= 3)
                    return pair.Value;
            }
            return word;
        }

        private static string ReplaceInsensitive(string input, string find, string replace)
        {
            if (string.IsNullOrEmpty(find) || string.IsNullOrEmpty(input)) return input;
            int idx = input.IndexOf(find, StringComparison.OrdinalIgnoreCase);
            if (idx < 0) return input;
            return input[..idx] + replace + input[(idx + find.Length)..];
        }

        private static string StripAccents(string s) =>
            s.Replace('á', 'a').Replace('é', 'e').Replace('í', 'i')
             .Replace('ó', 'o').Replace('ö', 'o').Replace('ő', 'o')
             .Replace('ú', 'u').Replace('ü', 'u').Replace('ű', 'u')
             .Replace('Á', 'A').Replace('É', 'E').Replace('Í', 'I')
             .Replace('Ó', 'O').Replace('Ö', 'O').Replace('Ő', 'O')
             .Replace('Ú', 'U').Replace('Ü', 'U').Replace('Ű', 'U');
    }
}
