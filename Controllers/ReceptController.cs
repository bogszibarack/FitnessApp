using Microsoft.AspNetCore.Mvc;
using System.Text.Json;
using FitnessBackend.Models;

namespace FitnessBackend.Controllers
{
    [ApiController]
    [Route("api/[controller]")]
    public class ReceptController : ControllerBase
    {
        private const string mealdb_api = "https://www.themealdb.com/api/json/v1/1";

        private static readonly List<KaloriaTartomany> kaloria_tartomanyok = new List<KaloriaTartomany>
        {
            new() { Min = 50, Max = 100, Nev = "50-100 kcal" },
            new() { Min = 100, Max = 200, Nev = "100-200 kcal" },
            new() { Min = 200, Max = 300, Nev = "200-300 kcal" },
            new() { Min = 300, Max = 400, Nev = "300-400 kcal" },
            new() { Min = 400, Max = 500, Nev = "400-500 kcal" },
            new() { Min = 500, Max = 600, Nev = "500-600 kcal" }
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

        // 3. KERESÉS (Yazio: kereső ikon)
        [HttpGet("kereso")]
        public async Task<ActionResult<List<ReceptListaElem>>> ReceptKereso([FromQuery] string keresoszo)
        {
            if (string.IsNullOrWhiteSpace(keresoszo))
            {
                return BadRequest("Add meg a keresoszot: ?keresoszo=csirke");
            }

            using var kliens = new HttpClient();
            string url = $"{mealdb_api}/search.php?s={Uri.EscapeDataString(keresoszo)}";
            string nyers_json = await kliens.GetStringAsync(url);

            var receptek = MealDbListabolReceptek(nyers_json);
            return Ok(receptek);
        }

        // 4. KATEGÓRIA SZERINT — étkezés, vega, kevés szénhidrát, gyors stb.
        [HttpGet("kategoria/{kategoria_id}")]
        public async Task<ActionResult<List<ReceptListaElem>>> ReceptekKategoriaSzerint(string kategoria_id)
        {
            var valasztott_kategoria = ReceptSzuroSeged.OsszesKategoria
                .FirstOrDefault(k => k.Id.Equals(kategoria_id, StringComparison.OrdinalIgnoreCase));

            if (valasztott_kategoria == null)
            {
                return BadRequest($"Ismeretlen kategoria: {kategoria_id}");
            }

            using var kliens = new HttpClient();
            var osszes_recept = new List<ReceptListaElem>();

            var mealdb_kategoriak = ReceptSzuroSeged.MealDbKategoriakSzurohoz(
                valasztott_kategoria.SzuresTipus,
                valasztott_kategoria.MealDbKategoria);

            foreach (var mealdb_kat in mealdb_kategoriak)
            {
                string url = $"{mealdb_api}/filter.php?c={Uri.EscapeDataString(mealdb_kat)}";
                string nyers_json = await kliens.GetStringAsync(url);
                var receptek = await MealDbFilterbolReszletesLista(kliens, nyers_json);
                osszes_recept.AddRange(receptek);
            }

            var szurt_lista = osszes_recept
                .Where(r => ReceptSzuroSeged.IlleszkedikSzurore(r, valasztott_kategoria.SzuresTipus))
                .DistinctBy(r => r.Id)
                .Take(20)
                .ToList();

            return Ok(szurt_lista);
        }

        // 5. KALÓRIA SZERINT (Yazio: 100-200 kcal kártya)
        [HttpGet("kaloria")]
        public async Task<ActionResult<List<ReceptListaElem>>> ReceptekKaloriaSzerint([FromQuery] int min, [FromQuery] int max)
        {
            using var kliens = new HttpClient();

            var osszes_recept = new List<ReceptListaElem>();
            foreach (var mealdb_kat in ReceptSzuroSeged.AlapKategoriaPool)
            {
                string url = $"{mealdb_api}/filter.php?c={Uri.EscapeDataString(mealdb_kat)}";
                string nyers_json = await kliens.GetStringAsync(url);
                var receptek = await MealDbFilterbolReszletesLista(kliens, nyers_json);
                osszes_recept.AddRange(receptek);
            }

            var szurt = osszes_recept
                .Where(r => r.BecsultKaloria >= min && r.BecsultKaloria <= max)
                .DistinctBy(r => r.Id)
                .ToList();

            return Ok(szurt);
        }

        // 6. FELFEDEZÉS (Yazio: Felfedezés tab — véletlen receptek)
        [HttpGet("felfedezes")]
        public async Task<ActionResult<List<ReceptListaElem>>> Felfedezes([FromQuery] int darab = 8)
        {
            using var kliens = new HttpClient();
            var receptek = new List<ReceptListaElem>();

            for (int i = 0; i < darab; i++)
            {
                string nyers_json = await kliens.GetStringAsync($"{mealdb_api}/random.php");
                var egy_recept = MealDbReszletesbolListaElem(nyers_json);
                if (egy_recept != null && !receptek.Any(r => r.Id == egy_recept.Id))
                {
                    receptek.Add(egy_recept);
                }
            }

            return Ok(receptek);
        }

        // 7. KEDVENCEK (Yazio: Kedvenceim tab)
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

            using var kliens = new HttpClient();
            string nyers_json = await kliens.GetStringAsync($"{mealdb_api}/lookup.php?i={recept_id}");
            var lista_elem = MealDbReszletesbolListaElem(nyers_json);

            if (lista_elem == null)
            {
                return NotFound("Nincs ilyen recept.");
            }

            ReceptTarolo.KedvencReceptek.Add(lista_elem);
            return Ok(lista_elem);
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

        // 7/b. RECEPT → NAPLÓ (Yazio: „Hozzáadás a naplóhoz” gomb a recept oldalon)
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

        // 8. RECEPT RÉSZLETEI (Yazio: recept megnyitása) — mindig legyen utoljára a {id} route!
        [HttpGet("{recept_id}")]
        public async Task<ActionResult<ReceptReszletes>> ReceptReszletei(string recept_id)
        {
            using var kliens = new HttpClient();
            string url = $"{mealdb_api}/lookup.php?i={recept_id}";
            string nyers_json = await kliens.GetStringAsync(url);

            var reszletes = MealDbLookupbolReszletes(nyers_json);
            if (reszletes == null)
            {
                return NotFound("Nincs ilyen recept.");
            }

            return Ok(reszletes);
        }

        // --- TheMealDB segédfüggvények ---

        private static List<ReceptListaElem> MealDbListabolReceptek(string nyers_json)
        {
            var receptek = new List<ReceptListaElem>();

            using JsonDocument doc = JsonDocument.Parse(nyers_json);
            if (!doc.RootElement.TryGetProperty("meals", out var meals) ||
                meals.ValueKind != JsonValueKind.Array)
            {
                return receptek;
            }

            foreach (JsonElement meal in meals.EnumerateArray())
            {
                var elem = MealElembolListaElem(meal);
                if (elem != null) receptek.Add(elem);
            }

            return receptek;
        }

        private static async Task<List<ReceptListaElem>> MealDbFilterbolReszletesLista(HttpClient kliens, string filter_json)
        {
            var receptek = new List<ReceptListaElem>();

            using JsonDocument doc = JsonDocument.Parse(filter_json);
            if (!doc.RootElement.TryGetProperty("meals", out var meals) ||
                meals.ValueKind != JsonValueKind.Array)
            {
                return receptek;
            }

            foreach (JsonElement meal in meals.EnumerateArray())
            {
                string? id = meal.TryGetProperty("idMeal", out var id_elem) ? id_elem.GetString() : null;
                if (string.IsNullOrEmpty(id)) continue;

                string lookup_json = await kliens.GetStringAsync($"{mealdb_api}/lookup.php?i={id}");
                var elem = MealDbReszletesbolListaElem(lookup_json);
                if (elem != null) receptek.Add(elem);
            }

            return receptek.Take(20).ToList();
        }

        private static ReceptListaElem? MealDbReszletesbolListaElem(string lookup_json)
        {
            using JsonDocument doc = JsonDocument.Parse(lookup_json);
            if (!doc.RootElement.TryGetProperty("meals", out var meals) ||
                meals.ValueKind != JsonValueKind.Array ||
                meals.GetArrayLength() == 0)
            {
                return null;
            }

            return MealElembolListaElem(meals[0]);
        }

        private static ReceptReszletes? MealDbLookupbolReszletes(string lookup_json)
        {
            using JsonDocument doc = JsonDocument.Parse(lookup_json);
            if (!doc.RootElement.TryGetProperty("meals", out var meals) ||
                meals.ValueKind != JsonValueKind.Array ||
                meals.GetArrayLength() == 0)
            {
                return null;
            }

            return MealElembolReszletes(meals[0]);
        }

        private static ReceptListaElem? MealElembolListaElem(JsonElement meal)
        {
            string id = meal.TryGetProperty("idMeal", out var id_elem) ? id_elem.GetString() ?? "" : "";
            string nev = meal.TryGetProperty("strMeal", out var nev_elem) ? nev_elem.GetString() ?? "" : "";

            if (string.IsNullOrWhiteSpace(id) || string.IsNullOrWhiteSpace(nev))
            {
                return null;
            }

            string kategoria = meal.TryGetProperty("strCategory", out var kat_elem) ? kat_elem.GetString() ?? "" : "";
            string kep = meal.TryGetProperty("strMealThumb", out var kep_elem) ? kep_elem.GetString() ?? "" : "";
            string cimkek_nyers = meal.TryGetProperty("strTags", out var tag_elem) ? tag_elem.GetString() ?? "" : "";

            int hozzavalo_szam = OsszetevokSzama(meal);
            var osszetevok = OsszetevokKinyerese(meal);
            string leiras = meal.TryGetProperty("strInstructions", out var inst) ? inst.GetString() ?? "" : "";

            var elem = new ReceptListaElem
            {
                Id = id,
                Nev = nev,
                Kategoria = kategoria,
                KepUrl = kep,
                BecsultKaloria = ReceptApiSeged.BecsultKaloria(kategoria, hozzavalo_szam),
                Cimkek = CimkekListaba(cimkek_nyers)
            };

            ReceptSzuroSeged.ReceptKiegeszitese(elem, hozzavalo_szam, leiras, osszetevok);
            return elem;
        }

        private static ReceptReszletes MealElembolReszletes(JsonElement meal)
        {
            var lista_elem = MealElembolListaElem(meal)!;

            return new ReceptReszletes
            {
                Id = lista_elem.Id,
                Nev = lista_elem.Nev,
                Kategoria = lista_elem.Kategoria,
                KepUrl = lista_elem.KepUrl,
                BecsultKaloria = lista_elem.BecsultKaloria,
                HozzavaloSzam = lista_elem.HozzavaloSzam,
                BecsultFeherje = lista_elem.BecsultFeherje,
                BecsultSzenhidrat = lista_elem.BecsultSzenhidrat,
                BecsultZsir = lista_elem.BecsultZsir,
                GyorsElkeszitheto = lista_elem.GyorsElkeszitheto,
                Cimkek = lista_elem.Cimkek,
                YazioCimkek = lista_elem.YazioCimkek,
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
                string nev_kulcs = $"strIngredient{i}";
                string menny_kulcs = $"strMeasure{i}";

                string nev = meal.TryGetProperty(nev_kulcs, out var n) ? n.GetString() ?? "" : "";
                string menny = meal.TryGetProperty(menny_kulcs, out var m) ? m.GetString() ?? "" : "";

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
}
