using System.Text.Json;
using Microsoft.AspNetCore.Mvc;
using FitnessBackend.Models;

namespace FitnessBackend.Controllers
{
    [ApiController]
    [Route("api/[controller]")]
    public class ReceptController : ControllerBase
    {
        // Helyi fallback adatbázis (ha a TheMealDB nem elérhető)
        private static readonly List<ReceptReszletes> helyi_receptek = HelyiReceptekBetoltese();

        private static List<ReceptReszletes> HelyiReceptekBetoltese()
        {
            try
            {
                string alap = AppContext.BaseDirectory;
                string json_ut = Path.Combine(alap, "Data", "receptek.json");
                if (!System.IO.File.Exists(json_ut))
                    json_ut = Path.Combine(Directory.GetCurrentDirectory(), "Data", "receptek.json");
                if (!System.IO.File.Exists(json_ut)) return new();

                var json = System.IO.File.ReadAllText(json_ut);
                using var doc = JsonDocument.Parse(json);
                var lista = new List<ReceptReszletes>();

                foreach (var elem in doc.RootElement.EnumerateArray())
                {
                    var r = new ReceptReszletes
                    {
                        Id = elem.GetProperty("id").GetString() ?? "",
                        Nev = elem.GetProperty("nev").GetString() ?? "",
                        KepUrl = "",
                        BecsultKaloria = elem.GetProperty("becsultKaloria").GetInt32(),
                        BecsultFeherje = elem.GetProperty("becsultFeherje").GetDouble(),
                        BecsultSzenhidrat = elem.GetProperty("becsultSzenhidrat").GetDouble(),
                        BecsultZsir = elem.GetProperty("becsultZsir").GetDouble(),
                        Leiras = elem.GetProperty("leiras").GetString() ?? "",
                        Kategoria = elem.GetProperty("kategoria").GetString() ?? "",
                        SzarmazasiTerulet = elem.GetProperty("szarmazasiTerulet").GetString() ?? "",
                    };
                    if (elem.TryGetProperty("cimkek", out var cimkek_el))
                        r.Cimkek = cimkek_el.EnumerateArray().Select(c => c.GetString() ?? "").ToList();
                    if (elem.TryGetProperty("osszetevok", out var ossz_el))
                        r.Osszetevok = ossz_el.EnumerateArray().Select(o => new ReceptOsszetevo
                        {
                            Nev = o.GetProperty("nev").GetString() ?? "",
                            Mennyiseg = o.GetProperty("mennyiseg").GetString() ?? "",
                        }).ToList();
                    if (elem.TryGetProperty("elkeszites", out var ek))
                        r.Leiras = (r.Leiras + "\n\nElkészítés:\n" + ek.GetString()).Trim();
                    lista.Add(r);
                }
                return lista;
            }
            catch { return new(); }
        }

        private static readonly List<KaloriaTartomany> kaloria_tartomanyok = new()
        {
            new() { Min = 0,   Max = 250, Nev = "0-250 kcal" },
            new() { Min = 250, Max = 350, Nev = "250-350 kcal" },
            new() { Min = 350, Max = 450, Nev = "350-450 kcal" },
            new() { Min = 450, Max = 600, Nev = "450-600 kcal" },
        };

        // 1. KATEGÓRIÁK — TheMealDB kategóriák
        [HttpGet("kategoriak")]
        public List<ReceptKategoria> Kategoriak()
        {
            return ReceptApiSeged.TheMealDbKategoriak;
        }

        // 2. KALÓRIA TARTOMÁNYOK
        [HttpGet("kaloria-tartomanyok")]
        public List<KaloriaTartomany> KaloriaTartomanyok()
        {
            return kaloria_tartomanyok;
        }

        // 3. KERESÉS — TheMealDB névkeresés + helyi fallback
        [HttpGet("kereso")]
        public async Task<ActionResult<List<ReceptListaElem>>> ReceptKereso([FromQuery] string keresoszo)
        {
            if (string.IsNullOrWhiteSpace(keresoszo))
                return BadRequest("Add meg a keresoszot.");

            try
            {
                var receptek = await ReceptApiSeged.Kereses(keresoszo);
                if (receptek.Count > 0) return Ok(receptek);
                // Helyi fallback ha semmi sem jött
                return Ok(HelyiKereses(keresoszo: keresoszo));
            }
            catch (Exception e)
            {
                return Ok(HelyiKereses(keresoszo: keresoszo));
            }
        }

        // 4. KATEGÓRIA SZERINT — TheMealDB filter
        [HttpGet("kategoria/{kategoria_id}")]
        public async Task<ActionResult<List<ReceptListaElem>>> ReceptekKategoriaSzerint(string kategoria_id)
        {
            // kategoria_id = TheMealDB angol név pl. "Chicken"
            var kategoria = ReceptApiSeged.TheMealDbKategoriak.FirstOrDefault(k =>
                k.Id.Equals(kategoria_id, StringComparison.OrdinalIgnoreCase));

            if (kategoria == null) return BadRequest($"Ismeretlen kategoria: {kategoria_id}");

            try
            {
                var receptek = await ReceptApiSeged.KategoriaSzerint(kategoria.Id);
                if (receptek.Count > 0) return Ok(receptek);
                return Ok(HelyiKereses(kategoria: kategoria.Nev));
            }
            catch
            {
                return Ok(HelyiKereses(kategoria: kategoria.Nev));
            }
        }

        // 5. KALÓRIA SZERINT — helyi receptek szűrése (TheMealDB nem tudja)
        [HttpGet("kaloria")]
        public ActionResult<List<ReceptListaElem>> ReceptekKaloriaSzerint([FromQuery] int min, [FromQuery] int max)
        {
            return Ok(HelyiKereses(min_kal: min, max_kal: max));
        }

        // 6. FELFEDEZÉS — TheMealDB random
        [HttpGet("felfedezes")]
        public async Task<ActionResult<List<ReceptListaElem>>> Felfedezes([FromQuery] int darab = 12)
        {
            try
            {
                var receptek = await ReceptApiSeged.Felfedezes(darab);
                if (receptek.Count > 0) return Ok(receptek);
                return Ok(helyi_receptek.Take(darab).Cast<ReceptListaElem>().ToList());
            }
            catch
            {
                return Ok(helyi_receptek.Take(darab).Cast<ReceptListaElem>().ToList());
            }
        }

        // 7. KEDVENCEK
        [HttpGet("kedvencek")]
        public List<ReceptListaElem> KedvencReceptek() => ReceptTarolo.KedvencReceptek;

        [HttpPost("kedvencek/{recept_id}")]
        public async Task<ActionResult<ReceptListaElem>> KedvenchezAdas(string recept_id)
        {
            if (ReceptTarolo.KedvencReceptek.Any(r => r.Id == recept_id))
                return Ok(ReceptTarolo.KedvencReceptek.First(r => r.Id == recept_id));

            try
            {
                var reszletes = await ReceptApiSeged.ReceptLekerdezese(recept_id);
                if (reszletes == null) return NotFound("Nincs ilyen recept.");
                ReceptTarolo.KedvencReceptek.Add(reszletes);
                return Ok(reszletes);
            }
            catch { return NotFound("Nem sikerült betölteni a receptet."); }
        }

        [HttpDelete("kedvencek/{recept_id}")]
        public ActionResult<string> KedvencTorlese(string recept_id)
        {
            var torlendo = ReceptTarolo.KedvencReceptek.FirstOrDefault(r => r.Id == recept_id);
            if (torlendo == null) return NotFound("Nincs a kedvencek kozott.");
            ReceptTarolo.KedvencReceptek.Remove(torlendo);
            return Ok($"Kedvenc torolve: {torlendo.Nev}");
        }

        // 7/b. RECEPT → NAPLÓ
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

        // 8. RECEPT RÉSZLETEI — mindig utoljára!
        [HttpGet("{recept_id}")]
        public async Task<ActionResult<ReceptReszletes>> ReceptReszletei(string recept_id)
        {
            // Helyi recept (local_X) azonnal visszaadjuk
            var helyi = helyi_receptek.FirstOrDefault(r => r.Id == recept_id);
            if (helyi != null) return Ok(helyi);

            try
            {
                var reszletes = await ReceptApiSeged.ReceptLekerdezese(recept_id);
                if (reszletes == null) return NotFound("Nincs ilyen recept.");
                return Ok(reszletes);
            }
            catch { return NotFound("A recept nem elérhető."); }
        }

        // --- Helyi szűrés (fallback) ---

        private List<ReceptListaElem> HelyiKereses(int min_kal = 0, int max_kal = 99999,
            string? keresoszo = null, string? kategoria = null, int darab = 12)
        {
            var query = helyi_receptek.AsEnumerable();
            if (min_kal > 0 || max_kal < 99999)
                query = query.Where(r => r.BecsultKaloria >= min_kal && r.BecsultKaloria <= max_kal);
            if (!string.IsNullOrWhiteSpace(kategoria))
                query = query.Where(r => r.Kategoria.Contains(kategoria, StringComparison.OrdinalIgnoreCase) ||
                                         r.Cimkek.Any(c => c.Contains(kategoria, StringComparison.OrdinalIgnoreCase)));
            if (!string.IsNullOrWhiteSpace(keresoszo))
            {
                var k = keresoszo.ToLowerInvariant();
                query = query.Where(r =>
                    r.Nev.ToLowerInvariant().Contains(k) ||
                    r.Kategoria.ToLowerInvariant().Contains(k) ||
                    r.Cimkek.Any(c => c.ToLowerInvariant().Contains(k)));
            }
            return query.Take(darab).Cast<ReceptListaElem>().ToList();
        }
    }
}
