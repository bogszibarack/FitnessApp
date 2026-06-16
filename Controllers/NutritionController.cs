using Microsoft.AspNetCore.Mvc;
using System.Text.Json;
using FitnessBackend.Models;

namespace FitnessBackend.Controllers
{
    [ApiController]
    [Route("api/[controller]")]
    public class NutritionController : ControllerBase
    {
        private const string off_api_alap = "https://world.openfoodfacts.org";
        private const string off_user_agent = "FitnessBackend/1.0 (fitness@local.dev)";

        // 1. ÉTELKERESŐ — ezt használd Swaggerben! (Yazio: keresőmező)
        // Példa: GET /api/nutrition/kereso?keresoszo=alma
        [HttpGet("kereso")]
        public async Task<ActionResult<List<FoodItem>>> EtelKereso([FromQuery] string keresoszo)
        {
            if (string.IsNullOrWhiteSpace(keresoszo))
            {
                return BadRequest("Add meg a keresoszot: ?keresoszo=alma");
            }

            return Ok(await OffKereses(keresoszo));
        }

        // 1/b. Régi útvonal — az etel_neve mezőbe írd be: alma (NE hagyd benne az {etel_neve} szöveget!)
        [HttpGet("kereses/{etel_neve}")]
        public async Task<ActionResult<List<FoodItem>>> EtelKeresesUtvonal(string etel_neve)
        {
            if (string.IsNullOrWhiteSpace(etel_neve) || etel_neve.Contains("etel_neve"))
            {
                return BadRequest("Az etel_neve mezőbe ird be a keresett etelt, pl: alma");
            }

            return Ok(await OffKereses(etel_neve));
        }

        // 2. VONALKÓD LEOLVASÁS (Yazio: kamera scan)
        [HttpGet("vonalkod/{vonalkod}")]
        public async Task<ActionResult<FoodItem>> EtelVonalkodbol(string vonalkod)
        {
            using var kliens = UjOffKliens();

            try
            {
                string url = $"{off_api_alap}/api/v2/product/{vonalkod}.json";
                string nyers_json = await kliens.GetStringAsync(url);

                using JsonDocument doc = JsonDocument.Parse(nyers_json);
                int status = doc.RootElement.TryGetProperty("status", out var status_elem) ? status_elem.GetInt32() : 0;

                if (status != 1 || !doc.RootElement.TryGetProperty("product", out var termek))
                {
                    return NotFound("Nem talalhato termek ehhez a vonalkodhoz. Probald meg keresessel!");
                }

                var food = TermekbolFoodItem(termek);
                if (food == null)
                {
                    return NotFound("A termek adatai hianyosak.");
                }

                return Ok(food);
            }
            catch (Exception)
            {
                return StatusCode(503, "Az Open Food Facts szerver nem elerheto. Probald ujra kesobb!");
            }
        }

        // 3. MAI NAPLÓ (Yazio: főképernyő — kalória körök)
        [HttpGet("mai-naplo")]
        public ActionResult<DailyNutritionSession> MaiNaplo()
        {
            return Ok(NaploLekerdezeseVagyLetrehozasa(DateTime.Today));
        }

        // 3/b. NAPLÓ DÁTUM ALAPJÁN
        [HttpGet("naplo/{ev}/{honap}/{nap}")]
        public ActionResult<DailyNutritionSession> NaploDatumra(int ev, int honap, int nap)
        {
            return Ok(NaploLekerdezeseVagyLetrehozasa(new DateTime(ev, honap, nap)));
        }

        // 3/c. ÉTKEZÉS SZERINTI BONTÁS (Reggeli / Ebéd / Vacsora / Nasi)
        [HttpGet("mai-naplo/{etkezes_tipus}")]
        public ActionResult<object> MaiNaploEtkezesSzerint(string etkezes_tipus)
        {
            var naplo = NaploLekerdezeseVagyLetrehozasa(DateTime.Today);
            var etelek = naplo.EatenFoods
                .Where(e => e.MealType.Equals(etkezes_tipus, StringComparison.OrdinalIgnoreCase))
                .ToList();

            return Ok(new
            {
                etkezes = etkezes_tipus,
                etelek,
                ossz_kaloria = Math.Round(etelek.Sum(e => e.CalculatedCalories), 1),
                ossz_feherje = Math.Round(etelek.Sum(e => e.CalculatedProtein), 1)
            });
        }

        // 4. NAPI KALÓRIA CÉL BEÁLLÍTÁSA
        [HttpPut("cel-kaloria")]
        public ActionResult<DailyNutritionSession> CelKaloriaBeallitasa([FromBody] double cel_kaloria)
        {
            var naplo = NaploLekerdezeseVagyLetrehozasa(DateTime.Today);
            naplo.TargetCalories = cel_kaloria;
            return Ok(naplo);
        }

        // 5. ÉTEL HOZZÁADÁSA A NAPLÓHOZ — Open Food Facts termék (Yazio: + gomb)
        [HttpPost("etel-hozzaadas")]
        public ActionResult<DailyNutritionSession> EtelHozzaadasa([FromBody] LoggedFood uj_etel)
        {
            if (!uj_etel.Receptbol && uj_etel.AmountGrams <= 0)
            {
                return BadRequest("Az AmountGrams (gramm) kotelezo es nagyobb mint 0.");
            }

            var naplo = NaploLekerdezeseVagyLetrehozasa(DateTime.Today);
            naplo.EatenFoods.Add(uj_etel);
            return Ok(naplo);
        }

        // 5/b. RECEPT HOZZÁADÁSA A NAPLÓHOZ — Receptek → Napló összekötés (Yazio)
        [HttpPost("recept-hozzaadas")]
        public async Task<ActionResult<DailyNutritionSession>> ReceptHozzaadasa([FromBody] ReceptNaplobaKeres keres)
        {
            var (naplo, _, hiba) = await NutritionTarolo.ReceptHozzaadasaAsync(keres);

            if (hiba != null)
            {
                return hiba.Contains("Nincs") ? NotFound(hiba) : BadRequest(hiba);
            }

            return Ok(naplo);
        }

        // 5/c. MAI RECEPTEK A NAPLÓBAN
        [HttpGet("mai-naplo/receptek")]
        public ActionResult<List<LoggedFood>> MaiReceptek()
        {
            var naplo = NaploLekerdezeseVagyLetrehozasa(DateTime.Today);
            return Ok(naplo.EatenFoods.Where(e => e.Receptbol).ToList());
        }

        // 6. ÉTEL MÓDOSÍTÁSA A NAPLÓBAN
        [HttpPut("etel-modositas/{etel_index}")]
        public ActionResult<DailyNutritionSession> EtelModositasa(int etel_index, [FromBody] LoggedFood modositott_etel)
        {
            var naplo = NaploLekerdezeseVagyLetrehozasa(DateTime.Today);

            if (etel_index < 0 || etel_index >= naplo.EatenFoods.Count)
            {
                return NotFound("Nincs ilyen etel a mai naploban.");
            }

            naplo.EatenFoods[etel_index] = modositott_etel;
            return Ok(naplo);
        }

        // 7. ÉTEL TÖRLÉSE A NAPLÓBÓL
        [HttpDelete("etel-torles/{etel_index}")]
        public ActionResult<DailyNutritionSession> EtelTorlese(int etel_index)
        {
            var naplo = NaploLekerdezeseVagyLetrehozasa(DateTime.Today);

            if (etel_index < 0 || etel_index >= naplo.EatenFoods.Count)
            {
                return NotFound("Nincs ilyen etel a mai naploban.");
            }

            naplo.EatenFoods.RemoveAt(etel_index);
            return Ok(naplo);
        }

        // --- Open Food Facts segédfüggvények ---

        private static HttpClient UjOffKliens()
        {
            var kliens = new HttpClient();
            kliens.DefaultRequestHeaders.Add("User-Agent", off_user_agent);
            return kliens;
        }

        private async Task<List<FoodItem>> OffKereses(string keresoszó)
        {
            var talalatok = new List<FoodItem>();
            using var kliens = UjOffKliens();

            try
            {
                string url = $"{off_api_alap}/cgi/search.pl?search_terms={Uri.EscapeDataString(keresoszó)}&search_simple=1&action=process&json=1&page_size=15";
                string nyers_json = await kliens.GetStringAsync(url);

                using JsonDocument doc = JsonDocument.Parse(nyers_json);
                if (!doc.RootElement.TryGetProperty("products", out var termekek) ||
                    termekek.ValueKind != JsonValueKind.Array)
                {
                    return talalatok;
                }

                foreach (JsonElement termek in termekek.EnumerateArray())
                {
                    var food = TermekbolFoodItem(termek);
                    if (food != null && food.Calories > 0)
                    {
                        talalatok.Add(food);
                    }
                }
            }
            catch (Exception)
            {
                // Üres lista ha a külső API nem válaszol
            }

            return talalatok;
        }

        private static FoodItem? TermekbolFoodItem(JsonElement termek)
        {
            string nev = termek.TryGetProperty("product_name", out var nev_elem) ? nev_elem.GetString() ?? "" : "";
            if (string.IsNullOrWhiteSpace(nev))
            {
                return null;
            }

            string marka = termek.TryGetProperty("brands", out var marka_elem) ? marka_elem.GetString() ?? "" : "";
            string teljes_nev = string.IsNullOrWhiteSpace(marka) ? nev : $"[{marka}] {nev}";
            string id = termek.TryGetProperty("code", out var id_elem) ? id_elem.GetString() ?? "0" : "0";
            string kep = termek.TryGetProperty("image_front_thumb_url", out var kep_elem) ? kep_elem.GetString() ?? "" : "";

            double kaloria = 0, feherje = 0, szenhidrat = 0, zsir = 0;

            if (termek.TryGetProperty("nutriments", out var nutriments))
            {
                kaloria = NutrimentOlvasas(nutriments, "energy-kcal_100g");
                feherje = NutrimentOlvasas(nutriments, "proteins_100g");
                szenhidrat = NutrimentOlvasas(nutriments, "carbohydrates_100g");
                zsir = NutrimentOlvasas(nutriments, "fat_100g");
            }

            return new FoodItem
            {
                Id = id,
                Name = teljes_nev,
                Calories = Math.Round(kaloria, 1),
                Protein = Math.Round(feherje, 1),
                Carbs = Math.Round(szenhidrat, 1),
                Fat = Math.Round(zsir, 1),
                ImageUrl = kep
            };
        }

        private static double NutrimentOlvasas(JsonElement nutriments, string mezo_nev)
        {
            if (nutriments.TryGetProperty(mezo_nev, out var elem) && elem.ValueKind == JsonValueKind.Number)
            {
                return elem.GetDouble();
            }
            return 0;
        }

        private static DailyNutritionSession NaploLekerdezeseVagyLetrehozasa(DateTime datum)
            => NutritionTarolo.NaploLekerdezeseVagyLetrehozasa(datum);
    }
}
