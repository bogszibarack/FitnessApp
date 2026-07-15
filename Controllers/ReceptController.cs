using Microsoft.AspNetCore.Mvc;
using FitnessBackend.Models;

namespace FitnessBackend.Controllers
{
    [ApiController]
    [Route("api/[controller]")]
    public class ReceptController : ControllerBase
    {
        private static readonly List<KaloriaTartomany> kaloria_tartomanyok = new()
        {
            new() { Min = 0,   Max = 250, Nev = "0-250 kcal" },
            new() { Min = 250, Max = 350, Nev = "250-350 kcal" },
            new() { Min = 350, Max = 450, Nev = "350-450 kcal" },
            new() { Min = 450, Max = 600, Nev = "450-600 kcal" },
        };

        [HttpGet("kategoriak")]
        public List<ReceptKategoria> Kategoriak() => NosaltyApiSeged.Kategoriak;

        [HttpGet("kaloria-tartomanyok")]
        public List<KaloriaTartomany> KaloriaTartomanyok() => kaloria_tartomanyok;

        [HttpGet("kereso")]
        public async Task<ActionResult<List<ReceptListaElem>>> ReceptKereso([FromQuery] string keresoszo)
        {
            if (string.IsNullOrWhiteSpace(keresoszo))
                return BadRequest("Add meg a keresoszot.");

            try
            {
                return Ok(await NosaltyApiSeged.Kereses(keresoszo));
            }
            catch
            {
                return Ok(new List<ReceptListaElem>());
            }
        }

        [HttpGet("kategoria/{*kategoria_id}")]
        public async Task<ActionResult<List<ReceptListaElem>>> ReceptekKategoriaSzerint(string kategoria_id)
        {
            var kategoria = NosaltyApiSeged.Kategoriak.FirstOrDefault(k =>
                k.Id.Equals(kategoria_id, StringComparison.OrdinalIgnoreCase));

            if (kategoria == null) return BadRequest($"Ismeretlen kategoria: {kategoria_id}");

            try
            {
                return Ok(await NosaltyApiSeged.KategoriaSzerint(kategoria.Id));
            }
            catch
            {
                return Ok(new List<ReceptListaElem>());
            }
        }

        [HttpGet("kaloria")]
        public async Task<ActionResult<List<ReceptListaElem>>> ReceptekKaloriaSzerint([FromQuery] int min, [FromQuery] int max)
        {
            try
            {
                return Ok(await NosaltyApiSeged.KaloriaSzerint(min, max));
            }
            catch
            {
                return Ok(new List<ReceptListaElem>());
            }
        }

        [HttpGet("felfedezes")]
        public async Task<ActionResult<List<ReceptListaElem>>> Felfedezes([FromQuery] int darab = 12)
        {
            try
            {
                return Ok(await NosaltyApiSeged.Felfedezes(darab));
            }
            catch
            {
                return Ok(new List<ReceptListaElem>());
            }
        }

        [HttpGet("kedvencek")]
        public List<ReceptListaElem> KedvencReceptek() => ReceptTarolo.KedvencReceptek;

        [HttpPost("kedvencek/{recept_id}")]
        public async Task<ActionResult<ReceptListaElem>> KedvenchezAdas(string recept_id)
        {
            if (ReceptTarolo.KedvencReceptek.Any(r => r.Id == recept_id))
                return Ok(ReceptTarolo.KedvencReceptek.First(r => r.Id == recept_id));

            var reszletes = await NosaltyApiSeged.ReceptLekerdezese(recept_id);
            if (reszletes == null) return NotFound("Nincs ilyen recept.");
            ReceptTarolo.KedvencReceptek.Add(reszletes);
            return Ok(reszletes);
        }

        [HttpDelete("kedvencek/{recept_id}")]
        public ActionResult<string> KedvencTorlese(string recept_id)
        {
            var torlendo = ReceptTarolo.KedvencReceptek.FirstOrDefault(r => r.Id == recept_id);
            if (torlendo == null) return NotFound("Nincs a kedvencek kozott.");
            ReceptTarolo.KedvencReceptek.Remove(torlendo);
            return Ok($"Kedvenc torolve: {torlendo.Nev}");
        }

        [HttpPost("{recept_id}/naplohoz-ad")]
        public async Task<ActionResult<object>> ReceptNaplohozAdasa(string recept_id, [FromBody] ReceptNaplobaKeres keres)
        {
            keres.ReceptId = recept_id;
            var (naplo, bejegyzes, hiba) = await NutritionTarolo.ReceptHozzaadasaAsync(keres);
            if (hiba != null) return hiba.Contains("Nincs") ? NotFound(hiba) : BadRequest(hiba);
            return Ok(new
            {
                uzenet = $"Recept hozzaadva: {bejegyzes?.FoodName}",
                hozzaadott = bejegyzes,
                mai_naplo = naplo
            });
        }

        [HttpGet("{recept_id}")]
        public async Task<ActionResult<ReceptReszletes>> ReceptReszletei(string recept_id)
        {
            try
            {
                var reszletes = await NosaltyApiSeged.ReceptLekerdezese(recept_id);
                if (reszletes == null) return NotFound("Nincs ilyen recept.");
                return Ok(reszletes);
            }
            catch
            {
                return NotFound("A recept nem elerheto.");
            }
        }
    }
}
