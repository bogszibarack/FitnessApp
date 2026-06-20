using System.Text.Json;

namespace FitnessBackend.Models
{
    /// <summary>Spoonacular konfiguráció — a kulcsot a Program.cs tölti be appsettings/env alapján.</summary>
    public static class SpoonacularConfig
    {
        public static string ApiKey { get; set; } = "";
        public const string BaseUrl = "https://api.spoonacular.com";
        public static bool VanKulcs => !string.IsNullOrWhiteSpace(ApiKey);
    }

    public static class ReceptApiSeged
    {
        private static readonly HttpClient kliens = new HttpClient();

        // --- Publikus lekérdezések ---

        /// <summary>complexSearch — valódi tápértékkel. extra_params pl. "diet=vegan&maxCarbs=25".</summary>
        public static async Task<List<ReceptListaElem>> ComplexSearch(string extra_params, int darab = 20)
        {
            string url = $"{SpoonacularConfig.BaseUrl}/recipes/complexSearch" +
                         $"?apiKey={SpoonacularConfig.ApiKey}" +
                         $"&number={darab}" +
                         "&addRecipeNutrition=true" +
                         "&instructionsRequired=true" +
                         "&fillIngredients=true";

            if (!string.IsNullOrWhiteSpace(extra_params))
            {
                url += "&" + extra_params;
            }

            string nyers_json = await kliens.GetStringAsync(url);

            using JsonDocument doc = JsonDocument.Parse(nyers_json);
            var lista = new List<ReceptListaElem>();

            if (!doc.RootElement.TryGetProperty("results", out var results) ||
                results.ValueKind != JsonValueKind.Array)
            {
                return lista;
            }

            foreach (var recept in results.EnumerateArray())
            {
                var elem = EredmenybolListaElem(recept);
                if (elem != null) lista.Add(elem);
            }

            await ForditoSeged.CimekForditasa(lista);
            return lista;
        }

        /// <summary>Kulcsszavas keresés — magyar szavakat angolra fordít.</summary>
        public static async Task<List<ReceptListaElem>> Kereses(string keresoszo, int darab = 20)
        {
            string angol = MagyarKeresesFordito.Forditas(keresoszo);
            return await ComplexSearch($"query={Uri.EscapeDataString(angol)}&sort=healthiness", darab);
        }

        /// <summary>Egy recept részletei — getInformation valódi tápértékkel.</summary>
        public static async Task<ReceptReszletes?> ReceptLekerdezese(string recept_id)
        {
            string url = $"{SpoonacularConfig.BaseUrl}/recipes/{recept_id}/information" +
                         $"?apiKey={SpoonacularConfig.ApiKey}&includeNutrition=true";

            string nyers_json = await kliens.GetStringAsync(url);
            using JsonDocument doc = JsonDocument.Parse(nyers_json);

            var reszletes = EredmenybolReszletes(doc.RootElement);
            if (reszletes != null)
            {
                reszletes.Nev = await ForditoSeged.Forditas(reszletes.Nev);
                reszletes.Leiras = await ForditoSeged.HosszuForditas(reszletes.Leiras);
            }
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

        // --- JSON feldolgozás ---

        private static ReceptListaElem? EredmenybolListaElem(JsonElement recept)
        {
            string id = recept.TryGetProperty("id", out var id_elem) ? id_elem.GetRawText() : "";
            string nev = recept.TryGetProperty("title", out var nev_elem) ? nev_elem.GetString() ?? "" : "";

            if (string.IsNullOrWhiteSpace(id) || string.IsNullOrWhiteSpace(nev)) return null;

            var elem = new ReceptListaElem
            {
                Id = id,
                Nev = nev,
                KepUrl = recept.TryGetProperty("image", out var kep) ? kep.GetString() ?? "" : "",
                Kategoria = ElsoDishType(recept),
                HozzavaloSzam = HozzavalokSzama(recept),
            };

            TapertekBetoltese(recept, elem);
            elem.GyorsElkeszitheto = ReadyInMinutes(recept) is int perc && perc <= 25;
            elem.YazioCimkek = CimkekGeneralasa(recept, elem);
            return elem;
        }

        private static ReceptReszletes? EredmenybolReszletes(JsonElement recept)
        {
            string id = recept.TryGetProperty("id", out var id_elem) ? id_elem.GetRawText() : "";
            string nev = recept.TryGetProperty("title", out var nev_elem) ? nev_elem.GetString() ?? "" : "";
            if (string.IsNullOrWhiteSpace(id) || string.IsNullOrWhiteSpace(nev)) return null;

            var reszletes = new ReceptReszletes
            {
                Id = id,
                Nev = nev,
                KepUrl = recept.TryGetProperty("image", out var kep) ? kep.GetString() ?? "" : "",
                Kategoria = ElsoDishType(recept),
                HozzavaloSzam = HozzavalokSzama(recept),
                Leiras = LeirasTisztitas(recept),
                YoutubeUrl = "",
                SzarmazasiTerulet = ElsoCuisine(recept),
                Osszetevok = OsszetevokKinyerese(recept)
            };

            TapertekBetoltese(recept, reszletes);
            reszletes.GyorsElkeszitheto = ReadyInMinutes(recept) is int perc && perc <= 25;
            reszletes.YazioCimkek = CimkekGeneralasa(recept, reszletes);
            return reszletes;
        }

        private static void TapertekBetoltese(JsonElement recept, ReceptListaElem elem)
        {
            if (!recept.TryGetProperty("nutrition", out var nutrition) ||
                !nutrition.TryGetProperty("nutrients", out var nutrients) ||
                nutrients.ValueKind != JsonValueKind.Array)
            {
                return;
            }

            elem.BecsultKaloria = (int)Math.Round(Tapanyag(nutrients, "Calories"));
            elem.BecsultFeherje = Math.Round(Tapanyag(nutrients, "Protein"), 1);
            elem.BecsultSzenhidrat = Math.Round(Tapanyag(nutrients, "Carbohydrates"), 1);
            elem.BecsultZsir = Math.Round(Tapanyag(nutrients, "Fat"), 1);
        }

        private static double Tapanyag(JsonElement nutrients, string nev)
        {
            foreach (var n in nutrients.EnumerateArray())
            {
                if (n.TryGetProperty("name", out var nev_elem) &&
                    string.Equals(nev_elem.GetString(), nev, StringComparison.OrdinalIgnoreCase) &&
                    n.TryGetProperty("amount", out var amount))
                {
                    return amount.GetDouble();
                }
            }
            return 0;
        }

        private static List<ReceptOsszetevo> OsszetevokKinyerese(JsonElement recept)
        {
            var lista = new List<ReceptOsszetevo>();
            if (!recept.TryGetProperty("extendedIngredients", out var ingredients) ||
                ingredients.ValueKind != JsonValueKind.Array)
            {
                return lista;
            }

            foreach (var ing in ingredients.EnumerateArray())
            {
                string nev = ing.TryGetProperty("nameClean", out var nc) && nc.ValueKind == JsonValueKind.String
                    ? nc.GetString() ?? ""
                    : (ing.TryGetProperty("name", out var n) ? n.GetString() ?? "" : "");

                string menny = ing.TryGetProperty("original", out var orig) ? orig.GetString() ?? "" : "";

                if (!string.IsNullOrWhiteSpace(nev))
                {
                    lista.Add(new ReceptOsszetevo { Nev = nev.Trim(), Mennyiseg = menny.Trim() });
                }
            }
            return lista;
        }

        private static string LeirasTisztitas(JsonElement recept)
        {
            string nyers = recept.TryGetProperty("instructions", out var inst) && inst.ValueKind == JsonValueKind.String
                ? inst.GetString() ?? ""
                : "";

            if (string.IsNullOrWhiteSpace(nyers)) return "";

            var sb = new System.Text.StringBuilder();
            bool tagben = false;
            foreach (char c in nyers)
            {
                if (c == '<') { tagben = true; continue; }
                if (c == '>') { tagben = false; sb.Append(' '); continue; }
                if (!tagben) sb.Append(c);
            }
            return System.Net.WebUtility.HtmlDecode(sb.ToString()).Replace("  ", " ").Trim();
        }

        private static int HozzavalokSzama(JsonElement recept)
        {
            if (recept.TryGetProperty("extendedIngredients", out var ing) && ing.ValueKind == JsonValueKind.Array)
            {
                return ing.GetArrayLength();
            }
            return 0;
        }

        private static int? ReadyInMinutes(JsonElement recept)
        {
            if (recept.TryGetProperty("readyInMinutes", out var perc) && perc.ValueKind == JsonValueKind.Number)
            {
                return perc.GetInt32();
            }
            return null;
        }

        private static string ElsoDishType(JsonElement recept)
        {
            if (recept.TryGetProperty("dishTypes", out var dt) && dt.ValueKind == JsonValueKind.Array && dt.GetArrayLength() > 0)
            {
                string nyers = dt[0].GetString() ?? "";
                return DishTypeMagyar(nyers);
            }
            return "Recept";
        }

        private static string ElsoCuisine(JsonElement recept)
        {
            if (recept.TryGetProperty("cuisines", out var c) && c.ValueKind == JsonValueKind.Array && c.GetArrayLength() > 0)
            {
                return c[0].GetString() ?? "";
            }
            return "";
        }

        private static string DishTypeMagyar(string dt) => dt.ToLower() switch
        {
            "breakfast" or "morning meal" or "brunch" => "Reggeli",
            "lunch" => "Ebéd",
            "dinner" or "main course" or "main dish" => "Főétel",
            "side dish" => "Köret",
            "salad" => "Saláta",
            "soup" => "Leves",
            "snack" or "fingerfood" or "appetizer" or "antipasti" or "starter" => "Snack",
            "dessert" => "Desszert",
            "drink" or "beverage" => "Ital",
            "smoothie" => "Smoothie",
            _ => char.ToUpper(dt[0]) + dt[1..]
        };

        private static List<string> CimkekGeneralasa(JsonElement recept, ReceptListaElem elem)
        {
            var cimkek = new List<string>();

            bool vegan = recept.TryGetProperty("vegan", out var v) && v.ValueKind == JsonValueKind.True;
            bool vega = recept.TryGetProperty("vegetarian", out var vg) && vg.ValueKind == JsonValueKind.True;
            bool gluten = recept.TryGetProperty("glutenFree", out var g) && g.ValueKind == JsonValueKind.True;

            if (elem.BecsultFeherje >= 25) cimkek.Add("Magas fehérje");
            if (elem.BecsultSzenhidrat <= 25 && elem.BecsultSzenhidrat > 0) cimkek.Add("Kevés szénhidrát");
            if (elem.BecsultZsir <= 12 && elem.BecsultZsir > 0) cimkek.Add("Alacsony zsír");
            if (vegan) cimkek.Add("Vegán");
            else if (vega) cimkek.Add("Vega");
            if (gluten) cimkek.Add("Gluténmentes");
            if (elem.GyorsElkeszitheto) cimkek.Add("Gyors");

            return cimkek;
        }
    }

    /// <summary>Magyar keresőszavak → angol (Spoonacular angol nyelvű).</summary>
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
        };

        /// <summary>Magyar szó → angol fordítás. Ékezet nélkül is megtalálja (mogyoro = mogyoró).</summary>
        public static string Forditas(string magyar)
        {
            if (string.IsNullOrWhiteSpace(magyar)) return magyar;

            var szavak = magyar.Trim().Split(' ', StringSplitOptions.RemoveEmptyEntries);
            var eredmeny = szavak.Select(sz =>
            {
                // 1. közvetlen találat (ékezettel)
                if (szotar.TryGetValue(sz, out var a1)) return a1;
                // 2. ékezet nélkülített verzió
                string norm = EkezetNelkul(sz);
                if (szotar.TryGetValue(norm, out var a2)) return a2;
                // 3. szótárban ékezet nélkül keressük
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
