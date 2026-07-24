namespace FitnessBackend.Services
{
    /// <summary>Hungarian food/search terms → English (TheMealDB / FatSecret are English).</summary>
    public static class SearchQueryTranslator
    {
        private static readonly Dictionary<string, string> Dictionary = new(StringComparer.OrdinalIgnoreCase)
        {
            ["alma"] = "apple", ["banán"] = "banana", ["eper"] = "strawberry", ["áfonya"] = "blueberry",
            ["csirke"] = "chicken", ["marha"] = "beef", ["sertés"] = "pork", ["hal"] = "fish",
            ["lazac"] = "salmon", ["tonhal"] = "tuna", ["pulyka"] = "turkey", ["sonka"] = "ham",
            ["tojás"] = "egg", ["rizs"] = "rice", ["tészta"] = "pasta", ["kenyér"] = "bread",
            ["sajt"] = "cheese", ["túró"] = "cottage cheese", ["joghurt"] = "yogurt", ["tej"] = "milk",
            ["zab"] = "oats", ["zabkása"] = "oatmeal", ["müzli"] = "granola", ["palacsinta"] = "pancake",
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
        };

        public static string ToEnglish(string hungarian)
        {
            if (string.IsNullOrWhiteSpace(hungarian)) return hungarian;

            var words = hungarian.Trim().Split(' ', StringSplitOptions.RemoveEmptyEntries);
            var result = words.Select(word =>
            {
                if (Dictionary.TryGetValue(word, out var a1)) return a1;
                string norm = StripAccents(word);
                if (Dictionary.TryGetValue(norm, out var a2)) return a2;
                foreach (var pair in Dictionary)
                {
                    if (StripAccents(pair.Key).Equals(norm, StringComparison.OrdinalIgnoreCase))
                        return pair.Value;
                }
                return word;
            });
            return string.Join(' ', result);
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
