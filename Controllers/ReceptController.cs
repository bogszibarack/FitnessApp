using Microsoft.AspNetCore.Mvc;
using FitnessBackend.Models;

namespace FitnessBackend.Controllers
{
    [ApiController]
    [Route("api/[controller]")]
    public class ReceptController : ControllerBase
    {
        private static readonly List<KaloriaTartomany> kaloria_tartomanyok = new List<KaloriaTartomany>
        {
            new() { Min = 50, Max = 200, Nev = "50-200 kcal" },
            new() { Min = 200, Max = 350, Nev = "200-350 kcal" },
            new() { Min = 350, Max = 500, Nev = "350-500 kcal" },
            new() { Min = 500, Max = 650, Nev = "500-650 kcal" },
            new() { Min = 650, Max = 800, Nev = "650-800 kcal" },
            new() { Min = 800, Max = 1200, Nev = "800+ kcal" }
        };

        // 1. KATEGÓRIÁK (Yazio: Népszerű kategóriák sáv)
        [HttpGet("kategoriak")]
        public List<ReceptKategoria> Kategoriak()
        {
            return ReceptSzuroSeged.OsszesKategoria;
        }

        // 2. KALÓRIA TARTOMÁNYOK (Yazio: Receptek kalória szerint)
        [HttpGet("kaloria-tartomanyok")]
        public List<KaloriaTartomany> KaloriaTartomanyok()
        {
            return kaloria_tartomanyok;
        }

        // 3. KERESÉS (Yazio: kereső ikon) — magyar szavakat is fordít
        [HttpGet("kereso")]
        public async Task<ActionResult<List<ReceptListaElem>>> ReceptKereso([FromQuery] string keresoszo)
        {
            if (string.IsNullOrWhiteSpace(keresoszo))
            {
                return BadRequest("Add meg a keresoszot: ?keresoszo=alma");
            }

            var hiba = KulcsHiba();
            if (hiba != null) return hiba;

            try
            {
                var receptek = await ReceptApiSeged.Kereses(keresoszo);
                return Ok(receptek);
            }
            catch (Exception e)
            {
                return SpoonacularHiba(e);
            }
        }

        // 4. KATEGÓRIA SZERINT
        [HttpGet("kategoria/{kategoria_id}")]
        public async Task<ActionResult<List<ReceptListaElem>>> ReceptekKategoriaSzerint(string kategoria_id)
        {
            var kategoria = ReceptSzuroSeged.KategoriaById(kategoria_id);
            if (kategoria == null)
            {
                return BadRequest($"Ismeretlen kategoria: {kategoria_id}");
            }

            var hiba = KulcsHiba();
            if (hiba != null) return hiba;

            try
            {
                var receptek = await ReceptApiSeged.ComplexSearch(kategoria.SpoonParam);
                return Ok(receptek);
            }
            catch (Exception e)
            {
                return SpoonacularHiba(e);
            }
        }

        // 5. KALÓRIA SZERINT — most VALÓDI tápérték alapján szűr
        [HttpGet("kaloria")]
        public async Task<ActionResult<List<ReceptListaElem>>> ReceptekKaloriaSzerint([FromQuery] int min, [FromQuery] int max)
        {
            var hiba = KulcsHiba();
            if (hiba != null) return hiba;

            try
            {
                var receptek = await ReceptApiSeged.ComplexSearch(
                    $"minCalories={min}&maxCalories={max}&sort=healthiness&sortDirection=desc");
                return Ok(receptek);
            }
            catch (Exception e)
            {
                return SpoonacularHiba(e);
            }
        }

        // 6. FELFEDEZÉS (Yazio: Felfedezés tab — egészséges ajánlások)
        [HttpGet("felfedezes")]
        public async Task<ActionResult<List<ReceptListaElem>>> Felfedezes([FromQuery] int darab = 12)
        {
            var hiba = KulcsHiba();
            if (hiba != null) return hiba;

            try
            {
                var receptek = await ReceptApiSeged.ComplexSearch("sort=healthiness&sortDirection=desc", darab);
                return Ok(receptek);
            }
            catch (Exception e)
            {
                return SpoonacularHiba(e);
            }
        }

        // 7. KEDVENCEK
        [HttpGet("kedvencek")]
        public List<ReceptListaElem> KedvencReceptek()
        {
            return ReceptTarolo.KedvencReceptek;
        }

        [HttpPost("kedvencek/{recept_id}")]
        public async Task<ActionResult<ReceptListaElem>> KedvenchezAdas(string recept_id)
        {
            if (ReceptTarolo.KedvencReceptek.Any(r => r.Id == recept_id))
            {
                return Ok(ReceptTarolo.KedvencReceptek.First(r => r.Id == recept_id));
            }

            var hiba = KulcsHiba();
            if (hiba != null) return hiba;

            try
            {
                var reszletes = await ReceptApiSeged.ReceptLekerdezese(recept_id);
                if (reszletes == null)
                {
                    return NotFound("Nincs ilyen recept.");
                }

                ReceptTarolo.KedvencReceptek.Add(reszletes);
                return Ok(reszletes);
            }
            catch (Exception e)
            {
                return SpoonacularHiba(e);
            }
        }

        [HttpDelete("kedvencek/{recept_id}")]
        public ActionResult<string> KedvencTorlese(string recept_id)
        {
            var torlendo = ReceptTarolo.KedvencReceptek.FirstOrDefault(r => r.Id == recept_id);
            if (torlendo == null)
            {
                return NotFound("Nincs a kedvencek kozott.");
            }

            ReceptTarolo.KedvencReceptek.Remove(torlendo);
            return Ok($"Kedvenc torolve: {torlendo.Nev}");
        }

        // 7/b. RECEPT → NAPLÓ
        [HttpPost("{recept_id}/naplohoz-ad")]
        public async Task<ActionResult<object>> ReceptNaplohozAdasa(string recept_id, [FromBody] ReceptNaplobaKeres keres)
        {
            keres.ReceptId = recept_id;

            var (naplo, bejegyzes, hiba) = await NutritionTarolo.ReceptHozzaadasaAsync(keres);

            if (hiba != null)
            {
                return hiba.Contains("Nincs") ? NotFound(hiba) : BadRequest(hiba);
            }

            return Ok(new
            {
                uzenet = $"Recept hozzaadva a mai naplohoz: {bejegyzes?.FoodName}",
                hozzaadott = bejegyzes,
                mai_naplo = naplo
            });
        }

        // 8. RECEPT RÉSZLETEI — mindig utoljára a {id} route!
        [HttpGet("{recept_id}")]
        public async Task<ActionResult<ReceptReszletes>> ReceptReszletei(string recept_id)
        {
            var hiba = KulcsHiba();
            if (hiba != null) return hiba;

            try
            {
                var reszletes = await ReceptApiSeged.ReceptLekerdezese(recept_id);
                if (reszletes == null)
                {
                    return NotFound("Nincs ilyen recept.");
                }
                return Ok(reszletes);
            }
            catch (Exception e)
            {
                return SpoonacularHiba(e);
            }
        }

        // --- Hibakezelés ---

        private ObjectResult? KulcsHiba()
        {
            if (!SpoonacularConfig.VanKulcs)
            {
                return StatusCode(503,
                    "Hianyzik a Spoonacular API kulcs. Allitsd be az appsettings.json-ban (Spoonacular:ApiKey) " +
                    "vagy a SPOONACULAR_API_KEY kornyezeti valtozoban.");
            }
            return null;
        }

        private ObjectResult SpoonacularHiba(Exception e)
        {
            if (e is HttpRequestException hre)
            {
                if (hre.StatusCode == System.Net.HttpStatusCode.TooManyRequests ||
                    hre.StatusCode == (System.Net.HttpStatusCode)402)
                {
                    return StatusCode(429, "Elfogyott a napi Spoonacular keret (ingyenes: 150 pont/nap). Probald holnap.");
                }
                if (hre.StatusCode == System.Net.HttpStatusCode.Unauthorized)
                {
                    return StatusCode(401, "Ervenytelen Spoonacular API kulcs.");
                }
            }
            return StatusCode(502, $"Recept szolgaltatas hiba: {e.Message}");
        }
    }
}
