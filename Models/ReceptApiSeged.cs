using System.Text.Json;
using System.Collections.Concurrent;

namespace FitnessBackend.Models
{
    /// <summary>Spoonacular konfig — megtartjuk de már nem elsődleges.</summary>
    public static class SpoonacularConfig
    {
        public static string ApiKey { get; set; } = "";
        public const string BaseUrl = "https://api.spoonacular.com";
        public static bool VanKulcs => !string.IsNullOrWhiteSpace(ApiKey);
    }

    /// <summary>
    /// TheMealDB integráció — ingyenes, korlátlan, képekkel.
    /// https://www.themealdb.com/api.php
    /// </summary>
    public static class ReceptApiSeged
    {
        private static readonly HttpClient kliens = new HttpClient();
        private const string BASE = "https://www.themealdb.com/api/json/v1/1";

        // 6 órás cache — így nem terheljük a TheMealDB-t feleslegesen
        private static readonly ConcurrentDictionary<string, (DateTime ido, List<ReceptListaElem> lista)> lista_cache = new();
        private static readonly ConcurrentDictionary<string, (DateTime ido, ReceptReszletes? recept)> reszlet_cache = new();
        private static readonly TimeSpan cache_ido = TimeSpan.FromHours(6);

        // --- Publikus metódusok (ReceptController hívja) ---

        /// <summary>Kulcsszavas keresés — fordítja a magyar szavakat angolra.</summary>
        public static async Task<List<ReceptListaElem>> Kereses(string keresoszo, int darab = 12)
        {
            string angol = MagyarKeresesFordito.Forditas(keresoszo);
            string kulcs = $"search_{angol}_{darab}";
            if (CacheBol(lista_cache, kulcs, out var cached)) return cached!;

            string url = $"{BASE}/search.php?s={Uri.EscapeDataString(angol)}";
            var lista = await MealekFeldolgozasa(url, darab);

            lista_cache[kulcs] = (DateTime.UtcNow, lista);
            return lista;
        }

        /// <summary>Kategória szerint szűrés.</summary>
        public static async Task<List<ReceptListaElem>> KategoriaSzerint(string kategoria_en, int darab = 12)
        {
            string kulcs = $"kat_{kategoria_en}_{darab}";
            if (CacheBol(lista_cache, kulcs, out var cached)) return cached!;

            // filter.php csak id + nev + kep adatot ad — kiegészítjük becsült tápértékkel
            string url = $"{BASE}/filter.php?c={Uri.EscapeDataString(kategoria_en)}";
            var lista = await FilterMealekFeldolgozasa(url, darab, kategoria_en);

            lista_cache[kulcs] = (DateTime.UtcNow, lista);
            return lista;
        }

        /// <summary>Felfedezés — random receptek (több API hívás).</summary>
        public static async Task<List<ReceptListaElem>> Felfedezes(int darab = 12)
        {
            string kulcs = $"felf_{darab}";
            if (CacheBol(lista_cache, kulcs, out var cached)) return cached!;

            // Több random kérés → eltérő receptek
            var lista = new List<ReceptListaElem>();
            var ids = new HashSet<string>();
            int batchek = (int)Math.Ceiling(darab / 3.0);

            var feladatok = Enumerable.Range(0, batchek)
                .Select(_ => kliens.GetStringAsync($"{BASE}/random.php"))
                .ToList();

            var valaszok = await Task.WhenAll(feladatok);

            foreach (var json_str in valaszok)
            {
                using var doc = JsonDocument.Parse(json_str);
                if (!doc.RootElement.TryGetProperty("meals", out var meals) ||
                    meals.ValueKind != JsonValueKind.Array) continue;

                foreach (var meal in meals.EnumerateArray())
                {
                    var elem = MealbolListaElem(meal);
                    if (elem != null && ids.Add(elem.Id))
                    {
                        lista.Add(elem);
                        if (lista.Count >= darab) break;
                    }
                }
                if (lista.Count >= darab) break;
            }

            await ForditoSeged.CimekForditasa(lista);
            lista_cache[kulcs] = (DateTime.UtcNow, lista);
            return lista;
        }

        /// <summary>Recept részletei lookup.php alapján.</summary>
        public static async Task<ReceptReszletes?> ReceptLekerdezese(string recept_id)
        {
            string kulcs = $"reszlet_{recept_id}";
            if (reszlet_cache.TryGetValue(kulcs, out var c) && DateTime.UtcNow - c.ido < cache_ido)
                return c.recept;

            string url = $"{BASE}/lookup.php?i={Uri.EscapeDataString(recept_id)}";
            string json_str = await kliens.GetStringAsync(url);
            using var doc = JsonDocument.Parse(json_str);

            if (!doc.RootElement.TryGetProperty("meals", out var meals) ||
                meals.ValueKind != JsonValueKind.Array || meals.GetArrayLength() == 0)
                return null;

            var meal = meals[0];
            var reszletes = MealbolReszletes(meal);
            if (reszletes != null)
            {
                reszletes.Nev = await ForditoSeged.Forditas(reszletes.Nev);
                reszletes.Leiras = await ForditoSeged.HosszuForditas(reszletes.Leiras);
                // Hozzávalók nevei magyarul
                foreach (var o in reszletes.Osszetevok)
                    o.Nev = await ForditoSeged.Forditas(o.Nev);
            }

            reszlet_cache[kulcs] = (DateTime.UtcNow, reszletes);
            return reszletes;
        }

        public static LoggedFood ReceptbolNaploBejegyzes(ReceptReszletes recept, double adag_szam, string etkezes_tipus)
        {
            return new LoggedFood
            {
                FoodId = $"recept_{recept.Id}",
                ReceptId = recept.Id,
                FoodName = recept.Nev,
                Receptbol = true,
                AdagSzam = adag_szam,
                MealType = etkezes_tipus,
                KepUrl = recept.KepUrl,
                CaloriesPer100g = recept.BecsultKaloria,
                ProteinPer100g = recept.BecsultFeherje,
                CarbsPer100g = recept.BecsultSzenhidrat,
                FatPer100g = recept.BecsultZsir
            };
        }

        // --- Kategória lista (TheMealDB + magyar nevek) ---

        public static readonly List<ReceptKategoria> TheMealDbKategoriak = new()
        {
            new() { Id = "Chicken",     Nev = "Csirke",               Ikon = "🍗", SpoonParam = "Chicken" },
            new() { Id = "Beef",        Nev = "Marhahús",             Ikon = "🥩", SpoonParam = "Beef" },
            new() { Id = "Seafood",     Nev = "Tenger gyümölcsei",    Ikon = "🐟", SpoonParam = "Seafood" },
            new() { Id = "Vegetarian",  Nev = "Vegetáriánus",         Ikon = "🥗", SpoonParam = "Vegetarian" },
            new() { Id = "Vegan",       Nev = "Vegán",                Ikon = "🌱", SpoonParam = "Vegan" },
            new() { Id = "Pasta",       Nev = "Tészta",               Ikon = "🍝", SpoonParam = "Pasta" },
            new() { Id = "Pork",        Nev = "Sertéshús",            Ikon = "🥓", SpoonParam = "Pork" },
            new() { Id = "Lamb",        Nev = "Bárány",               Ikon = "🍖", SpoonParam = "Lamb" },
            new() { Id = "Breakfast",   Nev = "Reggeli",              Ikon = "🥚", SpoonParam = "Breakfast" },
            new() { Id = "Dessert",     Nev = "Desszert",             Ikon = "🍰", SpoonParam = "Dessert" },
        };

        // --- Tápérték becslés kategória alapján ---

        private static (int kcal, double feherje, double szenhidrat, double zsir) BecsultTapertek(string kategoria)
        {
            return kategoria.ToLowerInvariant() switch
            {
                "chicken"    => (350, 36, 14, 11),
                "beef"       => (460, 32,  8, 24),
                "seafood"    => (290, 28,  6,  9),
                "pork"       => (400, 30, 10, 20),
                "lamb"       => (420, 28,  8, 22),
                "pasta"      => (430, 16, 58, 11),
                "vegetarian" => (280, 12, 35,  8),
                "vegan"      => (250, 10, 40,  6),
                "breakfast"  => (320, 15, 32, 12),
                "dessert"    => (390,  6, 55, 16),
                "side"       => (220,  6, 35,  5),
                _            => (350, 20, 30, 10),
            };
        }

        // --- JSON feldolgozás ---

        private static async Task<List<ReceptListaElem>> MealekFeldolgozasa(string url, int darab)
        {
            string json_str = await kliens.GetStringAsync(url);
            using var doc = JsonDocument.Parse(json_str);
            var lista = new List<ReceptListaElem>();

            if (!doc.RootElement.TryGetProperty("meals", out var meals) ||
                meals.ValueKind != JsonValueKind.Array) return lista;

            foreach (var meal in meals.EnumerateArray())
            {
                var elem = MealbolListaElem(meal);
                if (elem != null) lista.Add(elem);
                if (lista.Count >= darab) break;
            }

            await ForditoSeged.CimekForditasa(lista);
            return lista;
        }

        private static async Task<List<ReceptListaElem>> FilterMealekFeldolgozasa(string url, int darab, string kategoria)
        {
            string json_str = await kliens.GetStringAsync(url);
            using var doc = JsonDocument.Parse(json_str);
            var lista = new List<ReceptListaElem>();

            if (!doc.RootElement.TryGetProperty("meals", out var meals) ||
                meals.ValueKind != JsonValueKind.Array) return lista;

            var (kcal, feherje, szenhidrat, zsir) = BecsultTapertek(kategoria);

            foreach (var meal in meals.EnumerateArray())
            {
                string id = meal.TryGetProperty("idMeal", out var id_el) ? id_el.GetString() ?? "" : "";
                string nev = meal.TryGetProperty("strMeal", out var nev_el) ? nev_el.GetString() ?? "" : "";
                string kep = meal.TryGetProperty("strMealThumb", out var kep_el) ? kep_el.GetString() ?? "" : "";

                if (string.IsNullOrWhiteSpace(id)) continue;

                lista.Add(new ReceptListaElem
                {
                    Id = id,
                    Nev = nev,
                    KepUrl = kep,
                    Kategoria = KategoriaMagyarul(kategoria),
                    BecsultKaloria = kcal,
                    BecsultFeherje = feherje,
                    BecsultSzenhidrat = szenhidrat,
                    BecsultZsir = zsir,
                });
                if (lista.Count >= darab) break;
            }

            await ForditoSeged.CimekForditasa(lista);
            return lista;
        }

        private static ReceptListaElem? MealbolListaElem(JsonElement meal)
        {
            string id = meal.TryGetProperty("idMeal", out var id_el) ? id_el.GetString() ?? "" : "";
            string nev = meal.TryGetProperty("strMeal", out var nev_el) ? nev_el.GetString() ?? "" : "";
            string kep = meal.TryGetProperty("strMealThumb", out var kep_el) ? kep_el.GetString() ?? "" : "";
            string kat_en = meal.TryGetProperty("strCategory", out var kat_el) ? kat_el.GetString() ?? "" : "";

            if (string.IsNullOrWhiteSpace(id)) return null;

            var (kcal, feherje, szenhidrat, zsir) = BecsultTapertek(kat_en);

            return new ReceptListaElem
            {
                Id = id,
                Nev = nev,
                KepUrl = kep,
                Kategoria = KategoriaMagyarul(kat_en),
                BecsultKaloria = kcal,
                BecsultFeherje = feherje,
                BecsultSzenhidrat = szenhidrat,
                BecsultZsir = zsir,
                Cimkek = TagekKeszitese(meal, kcal, feherje, szenhidrat, zsir),
            };
        }

        private static ReceptReszletes? MealbolReszletes(JsonElement meal)
        {
            string id = meal.TryGetProperty("idMeal", out var id_el) ? id_el.GetString() ?? "" : "";
            string nev = meal.TryGetProperty("strMeal", out var nev_el) ? nev_el.GetString() ?? "" : "";
            string kep = meal.TryGetProperty("strMealThumb", out var kep_el) ? kep_el.GetString() ?? "" : "";
            string kat_en = meal.TryGetProperty("strCategory", out var kat_el) ? kat_el.GetString() ?? "" : "";
            string terulet = meal.TryGetProperty("strArea", out var ter_el) ? ter_el.GetString() ?? "" : "";
            string utasitas = meal.TryGetProperty("strInstructions", out var inst_el) ? inst_el.GetString() ?? "" : "";
            string youtube = meal.TryGetProperty("strYoutube", out var yt_el) ? yt_el.GetString() ?? "" : "";

            if (string.IsNullOrWhiteSpace(id)) return null;

            var (kcal, feherje, szenhidrat, zsir) = BecsultTapertek(kat_en);

            var reszletes = new ReceptReszletes
            {
                Id = id,
                Nev = nev,
                KepUrl = kep,
                Kategoria = KategoriaMagyarul(kat_en),
                SzarmazasiTerulet = TeruletMagyarul(terulet),
                BecsultKaloria = kcal,
                BecsultFeherje = feherje,
                BecsultSzenhidrat = szenhidrat,
                BecsultZsir = zsir,
                Leiras = UtasitasTisztitas(utasitas),
                YoutubeUrl = youtube,
                Osszetevok = OsszetevokKinyerese(meal),
                Cimkek = TagekKeszitese(meal, kcal, feherje, szenhidrat, zsir),
            };
            return reszletes;
        }

        private static List<ReceptOsszetevo> OsszetevokKinyerese(JsonElement meal)
        {
            var lista = new List<ReceptOsszetevo>();
            for (int i = 1; i <= 20; i++)
            {
                string nev_key = $"strIngredient{i}";
                string menny_key = $"strMeasure{i}";

                if (!meal.TryGetProperty(nev_key, out var nev_el) ||
                    nev_el.ValueKind != JsonValueKind.String) break;

                string nev = nev_el.GetString()?.Trim() ?? "";
                string menny = meal.TryGetProperty(menny_key, out var m_el) ? m_el.GetString()?.Trim() ?? "" : "";

                if (string.IsNullOrWhiteSpace(nev)) break;

                lista.Add(new ReceptOsszetevo { Nev = nev, Mennyiseg = menny });
            }
            return lista;
        }

        private static List<string> TagekKeszitese(JsonElement meal, int kcal, double feherje, double szenhidrat, double zsir)
        {
            var tags = new List<string>();
            string kat = meal.TryGetProperty("strCategory", out var kat_el) ? kat_el.GetString() ?? "" : "";

            if (feherje >= 30) tags.Add("Magas fehérje");
            if (szenhidrat <= 20) tags.Add("Kevés szénhidrát");
            if (zsir <= 10) tags.Add("Alacsony zsír");
            if (kat.Equals("Vegetarian", StringComparison.OrdinalIgnoreCase)) tags.Add("Vegetáriánus");
            if (kat.Equals("Vegan", StringComparison.OrdinalIgnoreCase)) tags.Add("Vegán");
            if (kcal < 300) tags.Add("Alacsony kalória");

            if (meal.TryGetProperty("strTags", out var tag_el) && tag_el.ValueKind == JsonValueKind.String)
            {
                var raw = tag_el.GetString() ?? "";
                foreach (var t in raw.Split(',', StringSplitOptions.RemoveEmptyEntries))
                {
                    var tn = t.Trim();
                    if (!string.IsNullOrWhiteSpace(tn)) tags.Add(tn);
                }
            }

            return tags;
        }

        private static string UtasitasTisztitas(string szoveg)
        {
            if (string.IsNullOrWhiteSpace(szoveg)) return "";
            // Windows sortörések és dupla szóközök eltávolítása
            return szoveg
                .Replace("\r\n", "\n")
                .Replace("\r", "\n")
                .Replace("  ", " ")
                .Trim();
        }

        private static string KategoriaMagyarul(string en) => en.ToLowerInvariant() switch
        {
            "chicken"    => "Csirke",
            "beef"       => "Marhahús",
            "seafood"    => "Tenger gyümölcsei",
            "pork"       => "Sertéshús",
            "lamb"       => "Bárány",
            "pasta"      => "Tészta",
            "vegetarian" => "Vegetáriánus",
            "vegan"      => "Vegán",
            "breakfast"  => "Reggeli",
            "dessert"    => "Desszert",
            "side"       => "Köret",
            "starter"    => "Előétel",
            "goat"       => "Kecske",
            "miscellaneous" => "Egyéb",
            _ => en,
        };

        private static string TeruletMagyarul(string en) => en.ToLowerInvariant() switch
        {
            "american"   => "Amerikai",
            "british"    => "Brit",
            "canadian"   => "Kanadai",
            "chinese"    => "Kínai",
            "french"     => "Francia",
            "greek"      => "Görög",
            "indian"     => "Indiai",
            "italian"    => "Olasz",
            "japanese"   => "Japán",
            "mexican"    => "Mexikói",
            "moroccan"   => "Marokkói",
            "spanish"    => "Spanyol",
            "thai"       => "Thai",
            "turkish"    => "Török",
            _ => en,
        };

        // --- Cache segéd ---

        private static bool CacheBol(
            ConcurrentDictionary<string, (DateTime ido, List<ReceptListaElem> lista)> cache,
            string kulcs, out List<ReceptListaElem>? lista)
        {
            if (cache.TryGetValue(kulcs, out var c) && DateTime.UtcNow - c.ido < cache_ido)
            {
                lista = c.lista;
                return true;
            }
            lista = null;
            return false;
        }
    }

    /// <summary>Magyar keresőszavak → angol (TheMealDB angol nyelvű).</summary>
    public static class MagyarKeresesFordito
    {
        private static readonly Dictionary<string, string> szotar = new(StringComparer.OrdinalIgnoreCase)
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

        public static string Forditas(string magyar)
        {
            if (string.IsNullOrWhiteSpace(magyar)) return magyar;

            var szavak = magyar.Trim().Split(' ', StringSplitOptions.RemoveEmptyEntries);
            var eredmeny = szavak.Select(sz =>
            {
                if (szotar.TryGetValue(sz, out var a1)) return a1;
                string norm = EkezetNelkul(sz);
                if (szotar.TryGetValue(norm, out var a2)) return a2;
                foreach (var p in szotar)
                {
                    if (EkezetNelkul(p.Key).Equals(norm, StringComparison.OrdinalIgnoreCase))
                        return p.Value;
                }
                return sz;
            });
            return string.Join(' ', eredmeny);
        }

        private static string EkezetNelkul(string s) =>
            s.Replace('á', 'a').Replace('é', 'e').Replace('í', 'i')
             .Replace('ó', 'o').Replace('ö', 'o').Replace('ő', 'o')
             .Replace('ú', 'u').Replace('ü', 'u').Replace('ű', 'u')
             .Replace('Á', 'A').Replace('É', 'E').Replace('Í', 'I')
             .Replace('Ó', 'O').Replace('Ö', 'O').Replace('Ő', 'O')
             .Replace('Ú', 'U').Replace('Ü', 'U').Replace('Ű', 'U');
    }
}
