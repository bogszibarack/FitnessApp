using System.Text.Json;

namespace FitnessBackend.Models
{
    // Közös segéd: TheMealDB + makró becslés (Recept + Nutrition)
    public static class ReceptApiSeged
    {
        public const string MealDbApi = "https://www.themealdb.com/api/json/v1/1";

        public static async Task<ReceptReszletes?> ReceptLekerdezese(string recept_id)
        {
            using var kliens = new HttpClient();
            string nyers_json = await kliens.GetStringAsync($"{MealDbApi}/lookup.php?i={recept_id}");

            using JsonDocument doc = JsonDocument.Parse(nyers_json);
            if (!doc.RootElement.TryGetProperty("meals", out var meals) ||
                meals.ValueKind != JsonValueKind.Array ||
                meals.GetArrayLength() == 0)
            {
                return null;
            }

            return MealElembolReszletes(meals[0]);
        }

        public static LoggedFood ReceptbolNaploBejegyzes(ReceptReszletes recept, double adag_szam, string etkezes_tipus)
        {
            var makrok = MakrokBecslese(recept.BecsultKaloria, recept.Kategoria);

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
                ProteinPer100g = makrok.feherje,
                CarbsPer100g = makrok.szenhidrat,
                FatPer100g = makrok.zsir
            };
        }

        public static int BecsultKaloria(string kategoria, int hozzavalo_szam)
        {
            int alap = kategoria.ToLower() switch
            {
                "breakfast" => 280,
                "dessert" => 380,
                "side" => 120,
                "starter" => 180,
                "vegan" or "vegetarian" => 220,
                "seafood" => 320,
                "chicken" => 400,
                "beef" or "lamb" or "pork" or "goat" => 480,
                "pasta" => 420,
                _ => 300
            };

            return alap + (hozzavalo_szam * 12);
        }

        public static (double feherje, double szenhidrat, double zsir) MakrokBecslese(int kaloria, string kategoria)
        {
            var (feherje_pct, szenhidrat_pct, zsir_pct) = kategoria.ToLower() switch
            {
                "chicken" or "beef" or "lamb" or "pork" or "goat" or "seafood" => (0.35, 0.30, 0.35),
                "vegan" or "vegetarian" => (0.20, 0.55, 0.25),
                "dessert" => (0.10, 0.60, 0.30),
                "pasta" => (0.18, 0.58, 0.24),
                _ => (0.25, 0.45, 0.30)
            };

            return (
                Math.Round(kaloria * feherje_pct / 4.0, 1),
                Math.Round(kaloria * szenhidrat_pct / 4.0, 1),
                Math.Round(kaloria * zsir_pct / 9.0, 1)
            );
        }

        private static ReceptReszletes MealElembolReszletes(JsonElement meal)
        {
            string id = meal.TryGetProperty("idMeal", out var id_elem) ? id_elem.GetString() ?? "" : "";
            string nev = meal.TryGetProperty("strMeal", out var nev_elem) ? nev_elem.GetString() ?? "" : "";
            string kategoria = meal.TryGetProperty("strCategory", out var kat_elem) ? kat_elem.GetString() ?? "" : "";
            string kep = meal.TryGetProperty("strMealThumb", out var kep_elem) ? kep_elem.GetString() ?? "" : "";
            string cimkek_nyers = meal.TryGetProperty("strTags", out var tag_elem) ? tag_elem.GetString() ?? "" : "";
            int hozzavalo_szam = OsszetevokSzama(meal);

            return new ReceptReszletes
            {
                Id = id,
                Nev = nev,
                Kategoria = kategoria,
                KepUrl = kep,
                BecsultKaloria = BecsultKaloria(kategoria, hozzavalo_szam),
                Cimkek = CimkekListaba(cimkek_nyers),
                Leiras = meal.TryGetProperty("strInstructions", out var inst) ? inst.GetString() ?? "" : "",
                YoutubeUrl = meal.TryGetProperty("strYoutube", out var yt) ? yt.GetString() ?? "" : "",
                SzarmazasiTerulet = meal.TryGetProperty("strArea", out var area) ? area.GetString() ?? "" : "",
                Osszetevok = OsszetevokKinyerese(meal)
            };
        }

        private static List<ReceptOsszetevo> OsszetevokKinyerese(JsonElement meal)
        {
            var osszetevok = new List<ReceptOsszetevo>();
            for (int i = 1; i <= 20; i++)
            {
                string nev = meal.TryGetProperty($"strIngredient{i}", out var n) ? n.GetString() ?? "" : "";
                string menny = meal.TryGetProperty($"strMeasure{i}", out var m) ? m.GetString() ?? "" : "";
                if (!string.IsNullOrWhiteSpace(nev))
                {
                    osszetevok.Add(new ReceptOsszetevo { Nev = nev.Trim(), Mennyiseg = menny.Trim() });
                }
            }
            return osszetevok;
        }

        private static int OsszetevokSzama(JsonElement meal)
        {
            int szam = 0;
            for (int i = 1; i <= 20; i++)
            {
                string nev = meal.TryGetProperty($"strIngredient{i}", out var n) ? n.GetString() ?? "" : "";
                if (!string.IsNullOrWhiteSpace(nev)) szam++;
            }
            return szam;
        }

        private static List<string> CimkekListaba(string cimkek_nyers)
        {
            if (string.IsNullOrWhiteSpace(cimkek_nyers)) return new List<string>();
            return cimkek_nyers.Split(',', StringSplitOptions.RemoveEmptyEntries | StringSplitOptions.TrimEntries).ToList();
        }
    }

    // Telefon küldi: recept + hány adag + melyik étkezéshez
    public class ReceptNaplobaKeres
    {
        public string ReceptId { get; set; } = "";
        public double AdagSzam { get; set; } = 1;
        public string EtkezesTipus { get; set; } = "ebed";
    }
}
