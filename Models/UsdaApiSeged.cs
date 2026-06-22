using System.Collections.Concurrent;
using System.Text.Json;

namespace FitnessBackend.Models
{
    public static class UsdaConfig
    {
        public static string ApiKey { get; set; } = "";
        public const string BaseUrl = "https://api.nal.usda.gov/fdc/v1";
        public static bool VanKulcs => !string.IsNullOrWhiteSpace(ApiKey);
    }

    /// <summary>
    /// USDA FoodData Central integráció — ingyenes, korlátlan (3600 lekérdezés/óra).
    /// Étel keresés: Foundation + SR Legacy adatbázis (pontos tudományos tápértékek).
    /// Magyar fordítás: szótár + MyMemory API fallback, cache-eléssel.
    /// </summary>
    public static class UsdaApiSeged
    {
        private static readonly HttpClient kliens = new();
        private static readonly ConcurrentDictionary<string, List<FoodItem>> kereses_cache = new();
        private static readonly ConcurrentDictionary<string, string> forditas_cache = new();

        // USDA nutrient ID-k
        private const int ID_KCAL       = 1008;
        private const int ID_FEHERJE    = 1003;
        private const int ID_SZENHIDRAT = 1005;
        private const int ID_ZSIR       = 1004;

        // ── Magyar ételszótár (USDA angol nevek → természetes magyar nevek) ──────────────
        private static readonly Dictionary<string, string> szotar = new(StringComparer.OrdinalIgnoreCase)
        {
            // Gyümölcsök
            ["apple"] = "Alma", ["apples"] = "Alma",
            ["banana"] = "Banán", ["bananas"] = "Banán",
            ["orange"] = "Narancs", ["oranges"] = "Narancs",
            ["strawberry"] = "Eper", ["strawberries"] = "Eper",
            ["grape"] = "Szőlő", ["grapes"] = "Szőlő",
            ["peach"] = "Őszibarack", ["peaches"] = "Őszibarack",
            ["pear"] = "Körte", ["pears"] = "Körte",
            ["cherry"] = "Cseresznye", ["cherries"] = "Cseresznye",
            ["plum"] = "Szilva", ["plums"] = "Szilva",
            ["watermelon"] = "Görögdinnye",
            ["cantaloupe"] = "Sárgadinnye",
            ["blueberry"] = "Áfonya", ["blueberries"] = "Áfonya",
            ["raspberry"] = "Málna", ["raspberries"] = "Málna",
            ["blackberry"] = "Szeder", ["blackberries"] = "Szeder",
            ["mango"] = "Mangó",
            ["pineapple"] = "Ananász",
            ["kiwi"] = "Kivi",
            ["lemon"] = "Citrom", ["lemons"] = "Citrom",
            ["lime"] = "Lime",
            ["grapefruit"] = "Grapefruit",
            ["avocado"] = "Avokádó", ["avocados"] = "Avokádó",
            ["fig"] = "Füge", ["figs"] = "Füge",
            ["apricot"] = "Sárgabarack", ["apricots"] = "Sárgabarack",
            ["pomegranate"] = "Gránátalma",
            ["coconut"] = "Kókusz",
            ["date"] = "Datolya", ["dates"] = "Datolya",
            ["cranberry"] = "Vörösáfonya", ["cranberries"] = "Vörösáfonya",
            ["raisin"] = "Mazsola", ["raisins"] = "Mazsola",
            ["prune"] = "Aszalt szilva", ["prunes"] = "Aszalt szilva",
            ["papaya"] = "Papaya",
            ["persimmon"] = "Datolyaszilva",
            ["tangerine"] = "Mandarin",
            ["clementine"] = "Clementine",
            ["guava"] = "Guava",
            ["lychee"] = "Licsi",
            ["passion fruit"] = "Maracuja",
            ["quince"] = "Birs",
            ["elderberry"] = "Bodza", ["elderberries"] = "Bodza",
            ["gooseberry"] = "Köszméte", ["gooseberries"] = "Köszméte",
            ["currant"] = "Ribizli", ["currants"] = "Ribizli",

            // Zöldségek
            ["tomato"] = "Paradicsom", ["tomatoes"] = "Paradicsom",
            ["potato"] = "Burgonya", ["potatoes"] = "Burgonya",
            ["sweet potato"] = "Édesburgonya", ["sweet potatoes"] = "Édesburgonya",
            ["yam"] = "Jam gyökér",
            ["carrot"] = "Sárgarépa", ["carrots"] = "Sárgarépa",
            ["broccoli"] = "Brokkoli",
            ["spinach"] = "Spenót",
            ["lettuce"] = "Saláta",
            ["romaine"] = "Római saláta",
            ["cucumber"] = "Uborka", ["cucumbers"] = "Uborka",
            ["pepper"] = "Paprika", ["peppers"] = "Paprika",
            ["bell pepper"] = "Édes paprika",
            ["jalapeño"] = "Jalapeño paprika",
            ["onion"] = "Hagyma", ["onions"] = "Hagyma",
            ["green onion"] = "Zöldhagyma",
            ["scallion"] = "Metélőhagyma",
            ["leek"] = "Póréhagyma", ["leeks"] = "Póréhagyma",
            ["garlic"] = "Fokhagyma",
            ["mushroom"] = "Gomba", ["mushrooms"] = "Gomba",
            ["zucchini"] = "Cukkini",
            ["squash"] = "Tök",
            ["pumpkin"] = "Sütőtök",
            ["cauliflower"] = "Karfiol",
            ["cabbage"] = "Káposzta",
            ["red cabbage"] = "Vöröskáposzta",
            ["sauerkraut"] = "Savanyú káposzta",
            ["celery"] = "Zeller",
            ["asparagus"] = "Spárga",
            ["eggplant"] = "Padlizsán",
            ["corn"] = "Kukorica",
            ["sweet corn"] = "Édes kukorica",
            ["pea"] = "Borsó", ["peas"] = "Borsó",
            ["green bean"] = "Zöldbab",
            ["snap pea"] = "Cukorborso",
            ["bean"] = "Bab", ["beans"] = "Bab",
            ["kidney bean"] = "Vesebab",
            ["black bean"] = "Fekete bab",
            ["navy bean"] = "Fehér bab",
            ["lentil"] = "Lencse", ["lentils"] = "Lencse",
            ["chickpea"] = "Csicseriborsó", ["chickpeas"] = "Csicseriborsó",
            ["beet"] = "Cékla", ["beets"] = "Cékla",
            ["artichoke"] = "Articsóka",
            ["brussels sprout"] = "Kelbimbó", ["brussels sprouts"] = "Kelbimbó",
            ["kale"] = "Fodorkáposzta",
            ["arugula"] = "Rukkola",
            ["radish"] = "Retek", ["radishes"] = "Retek",
            ["turnip"] = "Tarlórépa",
            ["parsnip"] = "Pasztinák",
            ["fennel"] = "Édeskömény",
            ["endive"] = "Endívia",
            ["chard"] = "Mángold",
            ["watercress"] = "Vízitorma",
            ["bamboo shoot"] = "Bambuszrügy",
            ["okra"] = "Okra",
            ["lotus root"] = "Lótuszgyökér",

            // Húsok
            ["chicken"] = "Csirke",
            ["chicken breast"] = "Csirkemell",
            ["chicken thigh"] = "Csirkecomb",
            ["chicken leg"] = "Csirkecomb",
            ["chicken wing"] = "Csirkeszárny",
            ["turkey"] = "Pulyka",
            ["turkey breast"] = "Pulykamell",
            ["beef"] = "Marhahús",
            ["ground beef"] = "Darált marhahús",
            ["steak"] = "Steak",
            ["pork"] = "Sertéshús",
            ["pork chop"] = "Sertéskaraj",
            ["pork loin"] = "Sertésszűz",
            ["lamb"] = "Bárányhús",
            ["veal"] = "Borjúhús",
            ["duck"] = "Kacsa",
            ["goose"] = "Liba",
            ["ham"] = "Sonka",
            ["bacon"] = "Bacon/szalonna",
            ["sausage"] = "Kolbász",
            ["salami"] = "Szalámi",
            ["pepperoni"] = "Pepperoni",
            ["hot dog"] = "Hot dog kolbász",
            ["bologna"] = "Bolognai felvágott",
            ["liverwurst"] = "Májas",
            ["prosciutto"] = "Prosciutto",

            // Halak, tenger gyümölcsei
            ["salmon"] = "Lazac",
            ["tuna"] = "Tonhal",
            ["cod"] = "Tőkehal",
            ["tilapia"] = "Tilápia",
            ["shrimp"] = "Garnélarák",
            ["crab"] = "Rák",
            ["lobster"] = "Homár",
            ["sardine"] = "Szardínia", ["sardines"] = "Szardínia",
            ["herring"] = "Hering",
            ["trout"] = "Pisztráng",
            ["carp"] = "Ponty",
            ["catfish"] = "Harcsa",
            ["mackerel"] = "Makréla",
            ["halibut"] = "Laposhal",
            ["snapper"] = "Vörössügér",
            ["bass"] = "Sügér",
            ["clam"] = "Kagyló", ["clams"] = "Kagyló",
            ["mussel"] = "Kék kagyló", ["mussels"] = "Kék kagyló",
            ["oyster"] = "Osztriga", ["oysters"] = "Osztriga",
            ["scallop"] = "Fésűkagyló", ["scallops"] = "Fésűkagyló",
            ["squid"] = "Tintahal",
            ["octopus"] = "Polip",
            ["anchovy"] = "Szardella", ["anchovies"] = "Szardella",
            ["fish"] = "Hal",
            ["fish oil"] = "Halolaj",
            ["cod liver oil"] = "Csukamájolaj",

            // Tejtermékek, tojás
            ["milk"] = "Tej",
            ["whole milk"] = "Teljes zsírtartalmú tej",
            ["skim milk"] = "Sovány tej",
            ["low fat milk"] = "Félzsíros tej",
            ["cheese"] = "Sajt",
            ["cheddar"] = "Cheddar sajt",
            ["mozzarella"] = "Mozzarella",
            ["parmesan"] = "Parmezán",
            ["brie"] = "Brie sajt",
            ["feta"] = "Feta sajt",
            ["ricotta"] = "Ricotta",
            ["cream cheese"] = "Krémsajt",
            ["butter"] = "Vaj",
            ["margarine"] = "Margarin",
            ["yogurt"] = "Joghurt",
            ["greek yogurt"] = "Görög joghurt",
            ["kefir"] = "Kefír",
            ["sour cream"] = "Tejföl",
            ["cream"] = "Tejszín",
            ["heavy cream"] = "Habtejszín",
            ["whipping cream"] = "Tejszínhab",
            ["cottage cheese"] = "Túró",
            ["quark"] = "Quark túró",
            ["egg"] = "Tojás", ["eggs"] = "Tojás",
            ["egg white"] = "Tojásfehérje",
            ["egg yolk"] = "Tojássárgája",
            ["hard boiled egg"] = "Keménytojás",
            ["scrambled egg"] = "Rántotta",

            // Gabonák, kenyér, pékáruk
            ["rice"] = "Rizs",
            ["brown rice"] = "Barna rizs",
            ["white rice"] = "Fehér rizs",
            ["wild rice"] = "Vadrizs",
            ["bread"] = "Kenyér",
            ["white bread"] = "Fehér kenyér",
            ["whole wheat bread"] = "Teljes kiőrlésű kenyér",
            ["rye bread"] = "Rozskenyér",
            ["sourdough"] = "Kovászos kenyér",
            ["bagel"] = "Bagel",
            ["croissant"] = "Croissant",
            ["muffin"] = "Muffin",
            ["roll"] = "Zsemle",
            ["bun"] = "Zsemle",
            ["pasta"] = "Tészta",
            ["spaghetti"] = "Spagetti",
            ["penne"] = "Penne",
            ["macaroni"] = "Makaróni",
            ["noodle"] = "Metélt", ["noodles"] = "Metélt",
            ["oat"] = "Zab", ["oats"] = "Zab",
            ["oatmeal"] = "Zabkása",
            ["granola"] = "Granola",
            ["cereal"] = "Reggeli gabonapehely",
            ["cornflakes"] = "Kukoricapehely",
            ["flour"] = "Liszt",
            ["whole wheat flour"] = "Teljes kiőrlésű liszt",
            ["quinoa"] = "Quinoa",
            ["barley"] = "Árpagyöngy",
            ["couscous"] = "Kuszkusz",
            ["bulgur"] = "Bulgur",
            ["millet"] = "Köles",
            ["buckwheat"] = "Hajdina",
            ["amaranth"] = "Amaránt",
            ["polenta"] = "Polenta",
            ["tortilla"] = "Tortilla",
            ["pita"] = "Pita kenyér",
            ["crackers"] = "Keksz",
            ["pretzel"] = "Perec",

            // Diófélék, magvak
            ["almond"] = "Mandula", ["almonds"] = "Mandula",
            ["walnut"] = "Dió", ["walnuts"] = "Dió",
            ["peanut"] = "Mogyoró", ["peanuts"] = "Mogyoró",
            ["cashew"] = "Kesüdió", ["cashews"] = "Kesüdió",
            ["pistachio"] = "Pisztácia", ["pistachios"] = "Pisztácia",
            ["pecan"] = "Pekándió", ["pecans"] = "Pekándió",
            ["macadamia"] = "Makadámia dió",
            ["hazelnut"] = "Mogyoró", ["hazelnuts"] = "Mogyoró",
            ["brazil nut"] = "Brazíldió", ["brazil nuts"] = "Brazíldió",
            ["pine nut"] = "Fenyőmag", ["pine nuts"] = "Fenyőmag",
            ["sunflower seed"] = "Napraforgómag", ["sunflower seeds"] = "Napraforgómag",
            ["pumpkin seed"] = "Tökmag", ["pumpkin seeds"] = "Tökmag",
            ["sesame"] = "Szézámmag",
            ["flaxseed"] = "Lenmag", ["flaxseeds"] = "Lenmag",
            ["chia"] = "Chiamag",
            ["hemp seed"] = "Kendermag",
            ["peanut butter"] = "Mogyoróvaj",
            ["almond butter"] = "Mandulakrém",
            ["tahini"] = "Tahini (szézámpüré)",

            // Olajok, zsírok
            ["oil"] = "Olaj",
            ["olive oil"] = "Olívaolaj",
            ["sunflower oil"] = "Napraforgóolaj",
            ["coconut oil"] = "Kókuszolaj",
            ["vegetable oil"] = "Növényi olaj",
            ["canola oil"] = "Repceolaj",
            ["lard"] = "Zsír",

            // Édességek, desszertek
            ["chocolate"] = "Csokoládé",
            ["dark chocolate"] = "Étcsokoládé",
            ["milk chocolate"] = "Tejcsokoládé",
            ["white chocolate"] = "Fehér csokoládé",
            ["cocoa"] = "Kakaó",
            ["honey"] = "Méz",
            ["sugar"] = "Cukor",
            ["brown sugar"] = "Barnacukor",
            ["jam"] = "Lekvár",
            ["jelly"] = "Zselé",
            ["ice cream"] = "Fagylalt",
            ["cookie"] = "Keksz", ["cookies"] = "Keksz",
            ["cake"] = "Sütemény",
            ["pie"] = "Pite",
            ["brownie"] = "Brownie",
            ["cheesecake"] = "Sajttorta",
            ["pudding"] = "Puding",
            ["candy"] = "Cukorka",
            ["syrup"] = "Szirup",
            ["maple syrup"] = "Juharszirup",
            ["agave"] = "Agávészirup",

            // Italok
            ["water"] = "Víz",
            ["juice"] = "Gyümölcslé",
            ["orange juice"] = "Narancslé",
            ["apple juice"] = "Almalé",
            ["coffee"] = "Kávé",
            ["tea"] = "Tea",
            ["milk"] = "Tej",
            ["smoothie"] = "Smoothie",
            ["beer"] = "Sör",
            ["wine"] = "Bor",
            ["soda"] = "Üdítő",
            ["energy drink"] = "Energiaital",
            ["sports drink"] = "Sportital",

            // Egyéb
            ["tofu"] = "Tofu",
            ["tempeh"] = "Tempeh",
            ["seitan"] = "Búzahús",
            ["hummus"] = "Hummus",
            ["guacamole"] = "Guacamole",
            ["salsa"] = "Salsa",
            ["mayonnaise"] = "Majonéz",
            ["ketchup"] = "Ketchup",
            ["mustard"] = "Mustár",
            ["hot sauce"] = "Csípős szósz",
            ["soy sauce"] = "Szójaszósz",
            ["vinegar"] = "Ecet",
            ["salt"] = "Só",
            ["pepper"] = "Bors",
            ["olive"] = "Olajbogyó", ["olives"] = "Olajbogyó",
            ["pickle"] = "Savanyúság", ["pickles"] = "Savanyúság",
            ["kimchi"] = "Kimchi",
            ["soup"] = "Leves",
            ["broth"] = "Húsleves",
            ["stock"] = "Alaplé",
            ["protein powder"] = "Fehérjepor",
            ["whey protein"] = "Tejsavó fehérje",
            ["casein"] = "Kazein fehérje",
            ["creatine"] = "Kreatin",
            ["multivitamin"] = "Multivitamin",
        };

        // Elkészítési módok (vesszővel elválasztva az USDA nevekben)
        private static readonly Dictionary<string, string> elkeszites = new(StringComparer.OrdinalIgnoreCase)
        {
            ["raw"] = "nyers",
            ["cooked"] = "főtt",
            ["baked"] = "sütőben sütött",
            ["grilled"] = "grillezett",
            ["roasted"] = "sült",
            ["fried"] = "sütött",
            ["boiled"] = "főtt",
            ["steamed"] = "párolt",
            ["braised"] = "párolt",
            ["stewed"] = "párolt",
            ["sauteed"] = "pirított",
            ["poached"] = "buggyantott",
            ["dried"] = "szárított",
            ["canned"] = "konzerv",
            ["frozen"] = "fagyasztott",
            ["fresh"] = "friss",
            ["ground"] = "darált",
            ["sliced"] = "szeletelt",
            ["chopped"] = "apróra vágott",
            ["minced"] = "apróra vágott",
            ["smoked"] = "füstölt",
            ["pickled"] = "savanyított",
            ["fermented"] = "erjesztett",
            ["dehydrated"] = "dehidratált",
            ["powdered"] = "por alakú",
            ["condensed"] = "sűrített",
            ["evaporated"] = "párolt",
            ["enriched"] = "dúsított",
            ["whole"] = "egész",
            ["farmed"] = "tenyésztett",
            ["wild"] = "vadon fogott",
            ["atlantic"] = "atlanti",
            ["pacific"] = "csendes-óceáni",
            ["lean"] = "sovány",
            ["extra lean"] = "extra sovány",
            ["defatted"] = "zsírtalanított",
            ["low sodium"] = "csökkentett sótartalmú",
            ["unsalted"] = "sótlan",
            ["salted"] = "sózott",
            ["sweetened"] = "cukrozott",
            ["unsweetened"] = "cukrozatlan",
            ["organic"] = "bio",
            ["fortified"] = "vitaminokkal dúsított",
            ["plain"] = "natúr",
            ["flavored"] = "ízesített",
            ["reduced fat"] = "csökkentett zsírtartalmú",
            ["fat free"] = "zsírmentes",
            ["nonfat"] = "zsírmentes",
            ["full fat"] = "teljes zsírtartalmú",
        };

        // USDA kategória-szavak — az első rész néha csak kategória, a lényeg a második
        private static readonly HashSet<string> kategoriak = new(StringComparer.OrdinalIgnoreCase)
        {
            "fish", "meat", "poultry", "game", "lamb", "veal", "pork", "beef",
            "vegetables", "fruits", "legumes", "nuts", "seeds",
            "dairy", "milk", "eggs", "cereals", "grains", "beverages",
            "fats", "oils", "sweets", "candies", "snacks", "soups",
            "sauces", "spices", "herbs", "baked products",
        };

        // ── Publikus API ──────────────────────────────────────────────────────────────────

        /// <summary>Magyar keresőszóra USDA Foundation+SR Legacy keresés, magyar névvel visszaadva.</summary>
        public static async Task<List<FoodItem>> Kereses(string keresoszo, int darab = 15)
        {
            string kulcs = keresoszo.Trim().ToLowerInvariant();
            if (kereses_cache.TryGetValue(kulcs, out var cached)) return cached;

            string angol = MagyarKeresesFordito.Forditas(keresoszo);

            var lista = new List<FoodItem>();
            try
            {
                string url = $"{UsdaConfig.BaseUrl}/foods/search" +
                             $"?api_key={UsdaConfig.ApiKey}" +
                             $"&query={Uri.EscapeDataString(angol)}" +
                             $"&pageSize={darab}" +
                             "&dataType=Foundation,SR%20Legacy" +
                             "&sortBy=dataType.keyword&sortOrder=asc";

                var response = await kliens.GetAsync(url);
                if (!response.IsSuccessStatusCode) return lista;

                string nyers = await response.Content.ReadAsStringAsync();
                using var doc = JsonDocument.Parse(nyers);

                if (!doc.RootElement.TryGetProperty("foods", out var foods) ||
                    foods.ValueKind != JsonValueKind.Array)
                    return lista;

                // Párhuzamos fordítás
                var feladatok = foods.EnumerateArray()
                    .Select(f => FoodItemKeszites(f))
                    .ToList();

                foreach (var eredmeny in await Task.WhenAll(feladatok))
                {
                    if (eredmeny != null) lista.Add(eredmeny);
                }

                if (lista.Count > 0)
                    kereses_cache[kulcs] = lista;
            }
            catch (Exception) { }

            return lista;
        }

        // ── Privát segédfüggvények ────────────────────────────────────────────────────────

        // Kiszűrendő USDA kategóriák (bébiétel, kiegészítők, nem releváns)
        private static readonly string[] kizart_kategoriak =
            ["babyfood", "baby food", "infant formula", "formulas", "fast food", "restaurant"];

        private static async Task<FoodItem?> FoodItemKeszites(JsonElement food)
        {
            string nev_eng = food.TryGetProperty("description", out var d) ? d.GetString() ?? "" : "";
            string id      = food.TryGetProperty("fdcId",       out var i) ? i.GetRawText()    : "";

            if (string.IsNullOrWhiteSpace(nev_eng) || string.IsNullOrWhiteSpace(id)) return null;

            // Bébiételek és hasonlók kizárása
            string nev_lower = nev_eng.ToLowerInvariant();
            if (kizart_kategoriak.Any(k => nev_lower.StartsWith(k))) return null;

            var (kcal, feherje, szenhidrat, zsir) = TapanyagokKinyerese(food);
            if (kcal <= 0) return null;

            string nev_hu = await EtelNevMagyarul(nev_eng);
            if (string.IsNullOrWhiteSpace(nev_hu)) return null;

            return new FoodItem
            {
                Id       = $"usda_{id}",
                Name     = nev_hu,
                Calories = kcal,
                Protein  = feherje,
                Carbs    = szenhidrat,
                Fat      = zsir,
                ImageUrl = ""
            };
        }

        private static (double kcal, double feherje, double szenhidrat, double zsir)
            TapanyagokKinyerese(JsonElement food)
        {
            double kcal = 0, feherje = 0, szenhidrat = 0, zsir = 0;

            if (!food.TryGetProperty("foodNutrients", out var nutrients) ||
                nutrients.ValueKind != JsonValueKind.Array)
                return (0, 0, 0, 0);

            foreach (var n in nutrients.EnumerateArray())
            {
                int    nid    = n.TryGetProperty("nutrientId", out var nid_e) ? nid_e.GetInt32()    : 0;
                double amount = n.TryGetProperty("value",      out var v)     ? v.GetDouble()       : 0;

                switch (nid)
                {
                    case ID_KCAL:       kcal       = Math.Round(amount, 1); break;
                    case ID_FEHERJE:    feherje    = Math.Round(amount, 1); break;
                    case ID_SZENHIDRAT: szenhidrat = Math.Round(amount, 1); break;
                    case ID_ZSIR:       zsir       = Math.Round(amount, 1); break;
                }
            }

            return (kcal, feherje, szenhidrat, zsir);
        }

        /// <summary>
        /// USDA névből természetes magyar nevet állít elő.
        /// Pl. "Apples, raw, with skin" → "Alma, nyers"
        /// Pl. "Chicken, breast, meat only, cooked, roasted" → "Csirkemell, sült"
        /// </summary>
        private static async Task<string> EtelNevMagyarul(string angol_nev)
        {
            if (forditas_cache.TryGetValue(angol_nev, out var cached)) return cached;

            string eredmeny = SzotarForditasUsdaNev(angol_nev);

            // Ha maradt még ismeretlen angol szó → MyMemory API-val lefordítjuk
            if (VanAnglolSzo(eredmeny))
            {
                string api = await ForditoSeged.Forditas(eredmeny);
                if (!string.IsNullOrWhiteSpace(api) && api != eredmeny)
                    eredmeny = api;
            }

            eredmeny = NevTisztitas(eredmeny);
            forditas_cache[angol_nev] = eredmeny;
            return eredmeny;
        }

        /// <summary>
        /// USDA formátumú leírás szótáras feldolgozása.
        /// Format: "MainFood, qualifier1, qualifier2, preparation" (vesszővel elválasztva)
        /// Pl. "Fish, salmon, Atlantic, farmed, raw" → "Lazac, tenyésztett, nyers"
        /// Pl. "Chicken, breast, meat only, cooked, roasted" → "Csirkemell, sült"
        /// </summary>
        private static string SzotarForditasUsdaNev(string nev)
        {
            // Zárójeleket és rövidítéseket eltávolítjuk
            nev = System.Text.RegularExpressions.Regex.Replace(nev, @"\([^)]*\)", "").Trim().Trim(',').Trim();
            nev = System.Text.RegularExpressions.Regex.Replace(nev, @"\bNFS\b", "", System.Text.RegularExpressions.RegexOptions.IgnoreCase).Trim();

            var reszek = nev.Split(',').Select(r => r.Trim()).Where(r => !string.IsNullOrWhiteSpace(r)).ToArray();
            if (reszek.Length == 0) return nev;

            // Ha az első rész csak kategória (pl. "Fish"), a második az igazi étel neve
            int foszint = 0;
            if (reszek.Length > 1 && kategoriak.Contains(reszek[0]))
                foszint = 1;

            string fo = reszek[foszint];
            string fo_hu = SzotarKereses(fo);

            // Testrész kombinálása a főnévvel — CSAK pontos szótári egyezés esetén
            // pl. "Chicken" + "breast" → "Chicken breast" → "Csirkemell" (ha pontosan szerepel a szótárban)
            if (foszint + 1 < reszek.Length)
            {
                string resz2 = reszek[foszint + 1];
                string kombinalt = $"{fo} {resz2}";
                // Csak akkor cseréljük le, ha pontosan megvan a szótárban (nem szavanként fordítva!)
                if (szotar.TryGetValue(kombinalt, out var kombinalt_hu))
                    fo_hu = kombinalt_hu;
            }

            // Elkészítési módok és jelzők kinyerése
            var modok = new List<string>();
            var kihagyando = new HashSet<string>(StringComparer.OrdinalIgnoreCase)
            {
                "meat only", "flesh only", "with bone", "without bone", "boneless",
                "without skin", "skinless", "with skin", "ns as to fat eaten",
                "fat not added in cooking", "fat added in cooking",
                "commercially prepared", "home prepared", "restaurant prepared",
                "ns as to type", "not specified", "not further specified",
                "breast", "thigh", "wing", "leg", "fillet", "loin", "chop",
                "all classes", "composite cuts",
                "broilers or fryers", "broiler or fryers", "roasters",
                "large", "medium", "small", "extra large", "grade a", "grade b",
                "all purpose", "general purpose",
                "babyfood", "baby food",
                "oil", "oil type",
                "chinook", "atlantic", "pacific", "sockeye", "coho", "pink",
                "california", "florida", "hass",
            };

            foreach (var resz in reszek.Skip(foszint + 1))
            {
                if (kihagyando.Contains(resz)) continue;
                if (kategoriak.Contains(resz)) continue;

                // Szám-tartalmú részeket (pl. "85% lean") lerövidítjük
                if (System.Text.RegularExpressions.Regex.IsMatch(resz, @"\d+%")) continue;

                if (elkeszites.TryGetValue(resz, out var mod))
                {
                    if (!modok.Contains(mod)) modok.Add(mod);
                }
            }

            if (modok.Count > 0)
                return $"{fo_hu}, {string.Join(", ", modok)}";

            return fo_hu;
        }

        private static string SzotarKereses(string angol)
        {
            if (szotar.TryGetValue(angol.Trim(), out var hu)) return hu;

            // Szavanként próbálkozás
            var szavak = angol.Trim().ToLower().Split(' ');
            if (szavak.Length > 1)
            {
                var forditott = szavak.Select(sz => szotar.TryGetValue(sz, out var h) ? h.ToLower() : sz);
                string osszefuzott = string.Join(" ", forditott);
                if (osszefuzott != string.Join(" ", szavak))
                    return char.ToUpper(osszefuzott[0]) + osszefuzott[1..];
            }

            return char.ToUpper(angol[0]) + angol[1..];
        }

        private static bool VanAnglolSzo(string szoveg)
        {
            var angol_jellemzok = new[]
            {
                "chicken", "beef", "pork", "turkey", "salmon", "tuna", "bread",
                "rice", "pasta", "milk", "cheese", "yogurt", "egg", "potato",
                "tomato", "apple", "banana", "orange", "butter", "cream",
                "flour", "sugar", "cake", "cookie", "juice", "sauce",
                "cooked", "baked", "grilled", "roasted", "dried", "canned"
            };
            string lower = szoveg.ToLower();
            return angol_jellemzok.Any(sz => lower.Contains(sz));
        }

        private static string NevTisztitas(string nev)
        {
            // Egymás melletti vesszők, felesleges szóközök eltávolítása
            nev = System.Text.RegularExpressions.Regex.Replace(nev, @",\s*,", ",");
            nev = System.Text.RegularExpressions.Regex.Replace(nev, @"\s+", " ");
            nev = nev.Trim().Trim(',').Trim();

            // Első betű nagybetű
            if (nev.Length > 0)
                nev = char.ToUpper(nev[0]) + nev[1..];

            return nev;
        }
    }
}
