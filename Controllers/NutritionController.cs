using Microsoft.AspNetCore.Mvc;
using System.Collections.Concurrent;
using System.Text.Json;
using FitnessBackend.Models;

namespace FitnessBackend.Controllers
{
    [ApiController]
    [Route("api/[controller]")]
    public class NutritionController : ControllerBase
    {
        private static readonly HttpClient kliens = new HttpClient();

        // Spoonacular étel-keresés cache (30 perc, rate-limit ellen)
        private static readonly ConcurrentDictionary<string, (DateTime ido, List<FoodItem> lista)> kereses_cache = new();
        private static readonly TimeSpan cache_elettartam = TimeSpan.FromMinutes(30);

        // Open Food Facts — csak vonalkódhoz
        private const string off_api_alap = "https://world.openfoodfacts.org";
        private const string off_user_agent = "FitnessBackend/1.0 (fitness@local.dev)";

        // 1. ÉTELKERESŐ — USDA FoodData Central (ingyenes, korlátlan) + offline adatbázis
        // Példa: GET /api/nutrition/kereso?keresoszo=alma
        [HttpGet("kereso")]
        public async Task<ActionResult<List<FoodItem>>> EtelKereso([FromQuery] string keresoszo)
        {
            if (string.IsNullOrWhiteSpace(keresoszo))
                return BadRequest("Add meg a keresoszot: ?keresoszo=alma");

            return Ok(await EtelKeresesFo(keresoszo));
        }

        // 1/b. Régi útvonal — visszafelé kompatibilitás
        [HttpGet("kereses/{etel_neve}")]
        public async Task<ActionResult<List<FoodItem>>> EtelKeresesUtvonal(string etel_neve)
        {
            if (string.IsNullOrWhiteSpace(etel_neve) || etel_neve.Contains("etel_neve"))
                return BadRequest("Az etel_neve mezobe ird be a keresett etelt, pl: alma");

            return Ok(await EtelKeresesFo(etel_neve));
        }

        // 2. VONALKÓD — Open Food Facts (globális termékadat-bázis, kód alapján pontos találat)
        [HttpGet("vonalkod/{vonalkod}")]
        public async Task<ActionResult<FoodItem>> EtelVonalkodbol(string vonalkod)
        {
            try
            {
                using var off_kliens = new HttpClient();
                off_kliens.DefaultRequestHeaders.Add("User-Agent", off_user_agent);

                string url = $"{off_api_alap}/api/v2/product/{vonalkod}.json" +
                             "?fields=code,product_name,product_name_hu,product_name_en,brands,nutriments,image_front_thumb_url";
                string nyers_json = await off_kliens.GetStringAsync(url);

                using JsonDocument doc = JsonDocument.Parse(nyers_json);
                int status = doc.RootElement.TryGetProperty("status", out var s) ? s.GetInt32() : 0;

                if (status != 1 || !doc.RootElement.TryGetProperty("product", out var termek))
                    return NotFound("Nem talalhato termek ehhez a vonalkodhoz.");

                var food = OffTermekbolFoodItem(termek);
                if (food == null) return NotFound("A termek adatai hianyosak.");

                return Ok(food);
            }
            catch (Exception)
            {
                return StatusCode(503, "A vonalkod-adatbazis nem elerheto. Probald ujra kesobb!");
            }
        }

        // 3. MAI NAPLÓ
        [HttpGet("mai-naplo")]
        public ActionResult<DailyNutritionSession> MaiNaplo()
            => Ok(NaploLekerdezeseVagyLetrehozasa(DateTime.Today));

        // 3/b. NAPLÓ DÁTUM ALAPJÁN
        [HttpGet("naplo/{ev}/{honap}/{nap}")]
        public ActionResult<DailyNutritionSession> NaploDatumra(int ev, int honap, int nap)
            => Ok(NaploLekerdezeseVagyLetrehozasa(new DateTime(ev, honap, nap)));

        // 3/c. ÉTKEZÉS SZERINTI BONTÁS
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

        // 4. NAPI KALÓRIA CÉL
        [HttpPut("cel-kaloria")]
        public ActionResult<DailyNutritionSession> CelKaloriaBeallitasa([FromBody] double cel_kaloria)
        {
            var naplo = NaploLekerdezeseVagyLetrehozasa(DateTime.Today);
            naplo.TargetCalories = cel_kaloria;
            return Ok(naplo);
        }

        // 5. ÉTEL HOZZÁADÁSA A NAPLÓHOZ
        [HttpPost("etel-hozzaadas")]
        public ActionResult<DailyNutritionSession> EtelHozzaadasa([FromBody] LoggedFood uj_etel)
        {
            if (!uj_etel.Receptbol && uj_etel.AmountGrams <= 0)
                return BadRequest("Az AmountGrams (gramm) kotelezo es nagyobb mint 0.");

            var naplo = NaploLekerdezeseVagyLetrehozasa(DateTime.Today);
            naplo.EatenFoods.Add(uj_etel);
            return Ok(naplo);
        }

        // 5/b. RECEPT HOZZÁADÁSA A NAPLÓHOZ
        [HttpPost("recept-hozzaadas")]
        public async Task<ActionResult<DailyNutritionSession>> ReceptHozzaadasa([FromBody] ReceptNaplobaKeres keres)
        {
            var (naplo, _, hiba) = await NutritionTarolo.ReceptHozzaadasaAsync(keres);
            if (hiba != null)
                return hiba.Contains("Nincs") ? NotFound(hiba) : BadRequest(hiba);
            return Ok(naplo);
        }

        // 5/c. MAI RECEPTEK A NAPLÓBAN
        [HttpGet("mai-naplo/receptek")]
        public ActionResult<List<LoggedFood>> MaiReceptek()
        {
            var naplo = NaploLekerdezeseVagyLetrehozasa(DateTime.Today);
            return Ok(naplo.EatenFoods.Where(e => e.Receptbol).ToList());
        }

        // 6. ÉTEL MÓDOSÍTÁSA
        [HttpPut("etel-modositas/{etel_index}")]
        public ActionResult<DailyNutritionSession> EtelModositasa(int etel_index, [FromBody] LoggedFood modositott_etel)
        {
            var naplo = NaploLekerdezeseVagyLetrehozasa(DateTime.Today);
            if (etel_index < 0 || etel_index >= naplo.EatenFoods.Count)
                return NotFound("Nincs ilyen etel a mai naploban.");
            naplo.EatenFoods[etel_index] = modositott_etel;
            return Ok(naplo);
        }

        // 7. ÉTEL TÖRLÉSE
        [HttpDelete("etel-torles/{etel_index}")]
        public ActionResult<DailyNutritionSession> EtelTorlese(int etel_index)
        {
            var naplo = NaploLekerdezeseVagyLetrehozasa(DateTime.Today);
            if (etel_index < 0 || etel_index >= naplo.EatenFoods.Count)
                return NotFound("Nincs ilyen etel a mai naploban.");
            naplo.EatenFoods.RemoveAt(etel_index);
            return Ok(naplo);
        }

        // --- Offline alapanyag-adatbázis ---
        // Ezek mindig elérhetők, API-limit nélkül, 100g-os tápértékkel.

        private static readonly List<FoodItem> offline_adatbazis = new()
        {
            new() { Id="off_alma",       Name="Alma",            Calories=52,  Protein=0.3, Carbs=14,  Fat=0.2 },
            new() { Id="off_koerte",     Name="Körte",           Calories=57,  Protein=0.4, Carbs=15,  Fat=0.1 },
            new() { Id="off_banan",      Name="Banán",           Calories=89,  Protein=1.1, Carbs=23,  Fat=0.3 },
            new() { Id="off_narancs",    Name="Narancs",         Calories=47,  Protein=0.9, Carbs=12,  Fat=0.1 },
            new() { Id="off_szilva",     Name="Szilva",          Calories=46,  Protein=0.7, Carbs=11,  Fat=0.3 },
            new() { Id="off_eper",       Name="Eper",            Calories=32,  Protein=0.7, Carbs=8,   Fat=0.3 },
            new() { Id="off_afonya",     Name="Áfonya",          Calories=57,  Protein=0.7, Carbs=14,  Fat=0.3 },
            new() { Id="off_grapefrui", Name="Grapefruit",      Calories=42,  Protein=0.8, Carbs=11,  Fat=0.1 },
            new() { Id="off_meggy",      Name="Meggy",           Calories=50,  Protein=1.0, Carbs=12,  Fat=0.3 },
            new() { Id="off_dinnye",     Name="Görögdinnye",     Calories=30,  Protein=0.6, Carbs=8,   Fat=0.2 },
            new() { Id="off_szolo",      Name="Szőlő",           Calories=67,  Protein=0.6, Carbs=17,  Fat=0.4 },
            new() { Id="off_kivi",       Name="Kivi",            Calories=61,  Protein=1.1, Carbs=15,  Fat=0.5 },
            new() { Id="off_mango",      Name="Mangó",           Calories=60,  Protein=0.8, Carbs=15,  Fat=0.4 },
            new() { Id="off_ananas",     Name="Ananász",         Calories=50,  Protein=0.5, Carbs=13,  Fat=0.1 },
            new() { Id="off_citrom",     Name="Citrom",          Calories=29,  Protein=1.1, Carbs=9,   Fat=0.3 },
            new() { Id="off_csirke",     Name="Csirkemell",      Calories=165, Protein=31,  Carbs=0,   Fat=3.6 },
            new() { Id="off_csirkecomb", Name="Csirkecomb",      Calories=215, Protein=26,  Carbs=0,   Fat=12 },
            new() { Id="off_marha",      Name="Marhahús",        Calories=250, Protein=26,  Carbs=0,   Fat=17 },
            new() { Id="off_sertes",     Name="Sertéshús",       Calories=242, Protein=27,  Carbs=0,   Fat=14 },
            new() { Id="off_pulyka",     Name="Pulykamell",      Calories=189, Protein=29,  Carbs=0,   Fat=7.5 },
            new() { Id="off_lazac",      Name="Lazac",           Calories=208, Protein=20,  Carbs=0,   Fat=13 },
            new() { Id="off_tonhal",     Name="Tonhal (konzerv)",Calories=116, Protein=26,  Carbs=0,   Fat=1.0 },
            new() { Id="off_ponty",      Name="Ponty",           Calories=162, Protein=18,  Carbs=0,   Fat=9.0 },
            new() { Id="off_sonka",      Name="Sonka",           Calories=145, Protein=21,  Carbs=1.5, Fat=6.0 },
            new() { Id="off_szalamitmp", Name="Szalámi",         Calories=406, Protein=22,  Carbs=2,   Fat=35 },
            new() { Id="off_tojas",      Name="Tojás (egész)",   Calories=155, Protein=13,  Carbs=1.1, Fat=11 },
            new() { Id="off_tojasfeh",   Name="Tojásfehérje",    Calories=52,  Protein=11,  Carbs=0.7, Fat=0.2 },
            new() { Id="off_tojassarg",  Name="Tojássárgája",    Calories=322, Protein=16,  Carbs=3.6, Fat=27 },
            new() { Id="off_tej",        Name="Tej (2,8%)",      Calories=50,  Protein=3.4, Carbs=4.8, Fat=2.0 },
            new() { Id="off_joghurt",    Name="Joghurt (natúr)", Calories=61,  Protein=3.5, Carbs=4.7, Fat=3.3 },
            new() { Id="off_gorog",      Name="Görög joghurt",   Calories=97,  Protein=9.0, Carbs=3.6, Fat=5.0 },
            new() { Id="off_sajt",       Name="Trappista sajt",  Calories=356, Protein=26,  Carbs=1.3, Fat=28 },
            new() { Id="off_mozzarella", Name="Mozzarella",      Calories=280, Protein=28,  Carbs=2.2, Fat=17 },
            new() { Id="off_turo",       Name="Túró (sovány)",   Calories=98,  Protein=11,  Carbs=3.4, Fat=4.3 },
            new() { Id="off_vaj",        Name="Vaj",             Calories=717, Protein=0.9, Carbs=0.1, Fat=81 },
            new() { Id="off_tejszin",    Name="Tejszín (30%)",   Calories=300, Protein=2.3, Carbs=3.0, Fat=30 },
            new() { Id="off_rizs",       Name="Rizs (főtt)",     Calories=130, Protein=2.7, Carbs=28,  Fat=0.3 },
            new() { Id="off_rizzsnyers", Name="Rizs (nyers)",    Calories=361, Protein=7.0, Carbs=80,  Fat=0.7 },
            new() { Id="off_teszta",     Name="Tészta (főtt)",   Calories=158, Protein=5.8, Carbs=31,  Fat=0.9 },
            new() { Id="off_kenyer",     Name="Kenyér (fehér)",  Calories=265, Protein=9.0, Carbs=49,  Fat=3.2 },
            new() { Id="off_barnaken",   Name="Kenyér (barna)",  Calories=247, Protein=8.9, Carbs=45,  Fat=3.4 },
            new() { Id="off_zab",        Name="Zabpehely",       Calories=389, Protein=17,  Carbs=66,  Fat=7.0 },
            new() { Id="off_zabkasa",    Name="Zabkása (főtt)",  Calories=71,  Protein=2.5, Carbs=12,  Fat=1.4 },
            new() { Id="off_kukoricap",  Name="Kukoricapehely",  Calories=356, Protein=7.5, Carbs=78,  Fat=1.9 },
            new() { Id="off_quinoa",     Name="Quinoa (főtt)",   Calories=120, Protein=4.4, Carbs=22,  Fat=1.9 },
            new() { Id="off_lencse",     Name="Lencse (főtt)",   Calories=116, Protein=9.0, Carbs=20,  Fat=0.4 },
            new() { Id="off_bab",        Name="Bab (főtt)",      Calories=127, Protein=8.7, Carbs=23,  Fat=0.5 },
            new() { Id="off_csicseribo", Name="Csicseriborsó",   Calories=164, Protein=8.9, Carbs=27,  Fat=2.6 },
            new() { Id="off_krumpli",    Name="Burgonya (főtt)", Calories=87,  Protein=1.9, Carbs=20,  Fat=0.1 },
            new() { Id="off_edesburgo",  Name="Édesburgonya",    Calories=86,  Protein=1.6, Carbs=20,  Fat=0.1 },
            new() { Id="off_mogyoro",    Name="Mogyoró",         Calories=607, Protein=14,  Carbs=16,  Fat=56 },
            new() { Id="off_dio",        Name="Dió",             Calories=654, Protein=15,  Carbs=14,  Fat=65 },
            new() { Id="off_mandula",    Name="Mandula",         Calories=579, Protein=21,  Carbs=22,  Fat=50 },
            new() { Id="off_kesudio",    Name="Kesüdió",         Calories=553, Protein=18,  Carbs=30,  Fat=44 },
            new() { Id="off_mogyorova",  Name="Mogyoróvaj",      Calories=588, Protein=25,  Carbs=20,  Fat=50 },
            new() { Id="off_olaj",       Name="Napraforgóolaj",  Calories=884, Protein=0,   Carbs=0,   Fat=100},
            new() { Id="off_olivaolaj",  Name="Olívaolaj",       Calories=884, Protein=0,   Carbs=0,   Fat=100},
            new() { Id="off_avokado",    Name="Avokádó",         Calories=160, Protein=2.0, Carbs=9.0, Fat=15 },
            new() { Id="off_brokkoli",   Name="Brokkoli",        Calories=34,  Protein=2.8, Carbs=7.0, Fat=0.4 },
            new() { Id="off_spenot",     Name="Spenót",          Calories=23,  Protein=2.9, Carbs=3.6, Fat=0.4 },
            new() { Id="off_paradicsom", Name="Paradicsom",      Calories=18,  Protein=0.9, Carbs=3.9, Fat=0.2 },
            new() { Id="off_uborka",     Name="Uborka",          Calories=16,  Protein=0.7, Carbs=3.6, Fat=0.1 },
            new() { Id="off_paprika",    Name="Paprika (piros)", Calories=31,  Protein=1.0, Carbs=6.0, Fat=0.3 },
            new() { Id="off_sarrep",     Name="Sárgarépa",       Calories=41,  Protein=0.9, Carbs=10,  Fat=0.2 },
            new() { Id="off_hagyma",     Name="Vöröshagyma",     Calories=40,  Protein=1.1, Carbs=9.3, Fat=0.1 },
            new() { Id="off_fokhag",     Name="Fokhagyma",       Calories=149, Protein=6.4, Carbs=33,  Fat=0.5 },
            new() { Id="off_cukkini",    Name="Cukkini",         Calories=17,  Protein=1.2, Carbs=3.1, Fat=0.3 },
            new() { Id="off_sutotok",    Name="Sütőtök",         Calories=26,  Protein=1.0, Carbs=6.5, Fat=0.1 },
            new() { Id="off_gomba",      Name="Csiperkegomba",   Calories=22,  Protein=3.1, Carbs=3.3, Fat=0.3 },
            new() { Id="off_salatafej",  Name="Saláta (fejes)",  Calories=15,  Protein=1.4, Carbs=2.9, Fat=0.2 },
            new() { Id="off_kelbimbo",   Name="Kelbimbó",        Calories=43,  Protein=3.4, Carbs=9.0, Fat=0.3 },
            new() { Id="off_karfiol",    Name="Karfiol",         Calories=25,  Protein=1.9, Carbs=5.0, Fat=0.3 },
            new() { Id="off_csokolade",  Name="Étcsokoládé (70%)",Calories=598, Protein=7.8,Carbs=46, Fat=43 },
            new() { Id="off_tejcsoki",   Name="Tejcsokoládé",    Calories=535, Protein=7.7, Carbs=60,  Fat=30 },
            new() { Id="off_mez",        Name="Méz",             Calories=304, Protein=0.3, Carbs=82,  Fat=0 },
            new() { Id="off_cukor",      Name="Cukor",           Calories=387, Protein=0,   Carbs=100, Fat=0 },
            new() { Id="off_lekvár",     Name="Lekvár",          Calories=250, Protein=0.4, Carbs=62,  Fat=0.1 },
            new() { Id="off_feherje_p",  Name="Fehérjepor (vanília)", Calories=380, Protein=77, Carbs=10, Fat=4 },
            new() { Id="off_kreatin",    Name="Kreatin",         Calories=0,   Protein=0,   Carbs=0,   Fat=0 },
            new() { Id="off_rizstejes",  Name="Rizs+tejszín",    Calories=190, Protein=3.5, Carbs=37,  Fat=4 },
            new() { Id="off_rizzspud",   Name="Rizspuding",      Calories=110, Protein=3.2, Carbs=21,  Fat=1.5 },
        };

        private static List<FoodItem> OfflineKereses(string keresoszó)
        {
            string norm = EkezetNelkulSearch(keresoszó.ToLowerInvariant());

            return offline_adatbazis
                .Where(f =>
                {
                    string nev_norm = EkezetNelkulSearch(f.Name.ToLowerInvariant());
                    return nev_norm.Contains(norm) || norm.Contains(nev_norm.Split(' ')[0]);
                })
                .Take(8)
                .ToList();
        }

        private static string EkezetNelkulSearch(string s) =>
            s.Replace('á', 'a').Replace('é', 'e').Replace('í', 'i')
             .Replace('ó', 'o').Replace('ö', 'o').Replace('ő', 'o')
             .Replace('ú', 'u').Replace('ü', 'u').Replace('ű', 'u');

        // --- Fő étel-keresési logika ---

        private async Task<List<FoodItem>> EtelKeresesFo(string keresoszó)
        {
            string kulcs = keresoszó.Trim().ToLowerInvariant();

            if (kereses_cache.TryGetValue(kulcs, out var cached) &&
                DateTime.UtcNow - cached.ido < cache_elettartam &&
                cached.lista.Count > 0)
                return cached.lista;

            // 1. Offline adatbázis — azonnali, API nélkül
            var eredmenyek = OfflineKereses(keresoszó);

            // 2. USDA FoodData Central — ingyenes, korlátlan, pontos tápérték
            if (UsdaConfig.VanKulcs)
            {
                var usda = await UsdaApiSeged.Kereses(keresoszó, 12);
                foreach (var t in usda)
                    if (!eredmenyek.Any(e => e.Id == t.Id)) eredmenyek.Add(t);
            }

            // 3. Ha az USDA nem adott semmit, Spoonacular fallback (ha van napi keret)
            if (eredmenyek.Count < 3 && SpoonacularConfig.VanKulcs)
            {
                var spoon = await SpoonKereses(keresoszó);
                foreach (var t in spoon)
                    if (!eredmenyek.Any(e => e.Id == t.Id)) eredmenyek.Add(t);
            }

            if (eredmenyek.Count > 0)
                kereses_cache[kulcs] = (DateTime.UtcNow, eredmenyek);

            return eredmenyek;
        }

        // --- Spoonacular étel-keresés (fallback) ---

        private async Task<List<FoodItem>> SpoonKereses(string keresoszó)
        {
            string kulcs = keresoszó.Trim().ToLowerInvariant();

            // Cache — 30 percen belül ugyanaz az eredmény
            if (kereses_cache.TryGetValue(kulcs, out var cached) &&
                DateTime.UtcNow - cached.ido < cache_elettartam &&
                cached.lista.Count > 0)
            {
                return cached.lista;
            }

            // 1. Offline adatbázis — mindig elérhető, API-limit nélkül
            var eredmenyek = OfflineKereses(keresoszó);

            // Magyar → angol fordítás (Spoonacular angolul keres)
            string angol = MagyarKeresesFordito.Forditas(keresoszó);

            bool spoon_keret_ok = true;

            // 2. Spoonacular ingredient keresés (kiegészítés)
            var ing = await SpoonIngredientSearch(angol);
            if (ing == null) { spoon_keret_ok = false; }
            else
            {
                foreach (var t in ing)
                    if (!eredmenyek.Any(e => e.Id == t.Id)) eredmenyek.Add(t);
            }

            // 3. Spoonacular product keresés (csomagolt termékek)
            if (spoon_keret_ok && eredmenyek.Count < 10)
            {
                var prod = await SpoonProductSearch(angol);
                if (prod != null)
                {
                    foreach (var t in prod)
                        if (!eredmenyek.Any(e => e.Id == t.Id)) eredmenyek.Add(t);
                }
            }

            // 4. OFF fallback ha Spoonacular keret elfogyott és offline sincs elég
            if (!spoon_keret_ok && eredmenyek.Count < 3)
            {
                var off_result = await OffFallbackKereses(keresoszó);
                foreach (var t in off_result)
                    if (!eredmenyek.Any(e => e.Id == t.Id)) eredmenyek.Add(t);
            }

            if (eredmenyek.Count > 0)
                kereses_cache[kulcs] = (DateTime.UtcNow, eredmenyek);

            return eredmenyek;
        }

        private async Task<List<FoodItem>> OffFallbackKereses(string keresoszó)
        {
            var lista = new List<FoodItem>();
            try
            {
                using var off = new HttpClient();
                off.DefaultRequestHeaders.Add("User-Agent", off_user_agent);

                // Próbáljuk magyarul, ha kevés találat, angolul is
                foreach (var q in new[] { keresoszó, MagyarKeresesFordito.Forditas(keresoszó) }.Distinct())
                {
                    string url = $"https://search.openfoodfacts.org/search?q={Uri.EscapeDataString(q)}" +
                                 "&page_size=15&fields=code,product_name,product_name_hu,product_name_en,brands,nutriments,image_front_thumb_url";
                    string nyers = await off.GetStringAsync(url);
                    using JsonDocument doc = JsonDocument.Parse(nyers);

                    if (!doc.RootElement.TryGetProperty("hits", out var hits) || hits.ValueKind != JsonValueKind.Array)
                        continue;

                    foreach (var termek in hits.EnumerateArray())
                    {
                        var food = OffTermekbolFoodItem(termek);
                        if (food != null && food.Calories > 0 && !lista.Any(x => x.Id == food.Id))
                            lista.Add(food);
                    }

                    if (lista.Count >= 5) break;
                }
            }
            catch (Exception) { }

            return lista;
        }

        /// <returns>null ha a Spoonacular keret elfogyott (402) — ekkor OFF fallbackre váltunk.</returns>
        private async Task<List<FoodItem>?> SpoonIngredientSearch(string angol_szo)
        {
            var lista = new List<FoodItem>();
            try
            {
                string url = $"{SpoonacularConfig.BaseUrl}/food/ingredients/search" +
                             $"?apiKey={SpoonacularConfig.ApiKey}" +
                             $"&query={Uri.EscapeDataString(angol_szo)}" +
                             "&number=12&metaInformation=true";

                var response = await kliens.GetAsync(url);

                if (response.StatusCode == System.Net.HttpStatusCode.PaymentRequired ||
                    response.StatusCode == System.Net.HttpStatusCode.TooManyRequests)
                {
                    return null; // keret elfogyott → OFF fallback
                }

                response.EnsureSuccessStatusCode();
                string nyers = await response.Content.ReadAsStringAsync();
                using JsonDocument doc = JsonDocument.Parse(nyers);

                if (!doc.RootElement.TryGetProperty("results", out var results) ||
                    results.ValueKind != JsonValueKind.Array)
                    return lista;

                foreach (var item in results.EnumerateArray())
                {
                    string id = item.TryGetProperty("id", out var id_e) ? id_e.GetRawText() : "";
                    string nev_eng = item.TryGetProperty("name", out var n) ? n.GetString() ?? "" : "";
                    if (string.IsNullOrWhiteSpace(id) || string.IsNullOrWhiteSpace(nev_eng)) continue;

                    string kep = item.TryGetProperty("image", out var kep_e) ? kep_e.GetString() ?? "" : "";
                    if (!string.IsNullOrWhiteSpace(kep) && !kep.StartsWith("http"))
                        kep = $"https://img.spoonacular.com/ingredients_250x250/{kep}";

                    var (kcal, feherje, szenhidrat, zsir) = await SpoonIngredientNutrition(id);
                    string nev_hu = await ForditoSeged.Forditas(nev_eng);

                    lista.Add(new FoodItem
                    {
                        Id = $"ing_{id}",
                        Name = nev_hu,
                        Calories = kcal,
                        Protein = feherje,
                        Carbs = szenhidrat,
                        Fat = zsir,
                        ImageUrl = kep
                    });
                }
            }
            catch (Exception) { }

            return lista;
        }

        private static readonly ConcurrentDictionary<string, (double kcal, double f, double sz, double zs)>
            nutrition_cache = new();

        private async Task<(double kcal, double feherje, double szenhidrat, double zsir)>
            SpoonIngredientNutrition(string id)
        {
            if (nutrition_cache.TryGetValue(id, out var n)) return n;

            try
            {
                string url = $"{SpoonacularConfig.BaseUrl}/food/ingredients/{id}/information" +
                             $"?apiKey={SpoonacularConfig.ApiKey}&amount=100&unit=g";

                string nyers = await kliens.GetStringAsync(url);
                using JsonDocument doc = JsonDocument.Parse(nyers);

                if (!doc.RootElement.TryGetProperty("nutrition", out var nutr) ||
                    !nutr.TryGetProperty("nutrients", out var nutrients))
                    return (0, 0, 0, 0);

                double kcal = 0, feherje = 0, szenhidrat = 0, zsir = 0;

                foreach (var nutrient in nutrients.EnumerateArray())
                {
                    string nev = nutrient.TryGetProperty("name", out var nn) ? nn.GetString() ?? "" : "";
                    double amount = nutrient.TryGetProperty("amount", out var a) ? a.GetDouble() : 0;

                    switch (nev)
                    {
                        case "Calories": kcal = Math.Round(amount, 1); break;
                        case "Protein": feherje = Math.Round(amount, 1); break;
                        case "Carbohydrates": szenhidrat = Math.Round(amount, 1); break;
                        case "Fat": zsir = Math.Round(amount, 1); break;
                    }
                }

                var eredmeny = (kcal, feherje, szenhidrat, zsir);
                nutrition_cache[id] = eredmeny;
                return eredmeny;
            }
            catch (Exception)
            {
                return (0, 0, 0, 0);
            }
        }

        private async Task<List<FoodItem>?> SpoonProductSearch(string angol_szo)
        {
            var lista = new List<FoodItem>();
            try
            {
                string url = $"{SpoonacularConfig.BaseUrl}/food/products/search" +
                             $"?apiKey={SpoonacularConfig.ApiKey}" +
                             $"&query={Uri.EscapeDataString(angol_szo)}&number=10";

                var response = await kliens.GetAsync(url);
                if (response.StatusCode == System.Net.HttpStatusCode.PaymentRequired ||
                    response.StatusCode == System.Net.HttpStatusCode.TooManyRequests)
                    return null;

                response.EnsureSuccessStatusCode();
                string nyers = await response.Content.ReadAsStringAsync();
                using JsonDocument doc = JsonDocument.Parse(nyers);

                if (!doc.RootElement.TryGetProperty("products", out var products) ||
                    products.ValueKind != JsonValueKind.Array)
                    return lista;

                foreach (var item in products.EnumerateArray())
                {
                    string id = item.TryGetProperty("id", out var id_e) ? id_e.GetRawText() : "";
                    string nev_eng = item.TryGetProperty("title", out var n) ? n.GetString() ?? "" : "";
                    if (string.IsNullOrWhiteSpace(id) || string.IsNullOrWhiteSpace(nev_eng)) continue;

                    string kep = item.TryGetProperty("image", out var kep_e) ? kep_e.GetString() ?? "" : "";

                    string nev_hu = await ForditoSeged.Forditas(nev_eng);

                    // Termék részletes tápérték — product information
                    var (kcal, feherje, szenhidrat, zsir) = await SpoonProductNutrition(id);
                    if (kcal <= 0) continue;

                    lista.Add(new FoodItem
                    {
                        Id = $"prod_{id}",
                        Name = nev_hu,
                        Calories = kcal,
                        Protein = feherje,
                        Carbs = szenhidrat,
                        Fat = zsir,
                        ImageUrl = kep
                    });
                }
            }
            catch (Exception) { }

            return lista; // nem null → nem 402
        }

        private async Task<(double kcal, double feherje, double szenhidrat, double zsir)>
            SpoonProductNutrition(string id)
        {
            string cache_key = $"p_{id}";
            if (nutrition_cache.TryGetValue(cache_key, out var n)) return n;

            try
            {
                string url = $"{SpoonacularConfig.BaseUrl}/food/products/{id}" +
                             $"?apiKey={SpoonacularConfig.ApiKey}";

                string nyers = await kliens.GetStringAsync(url);
                using JsonDocument doc = JsonDocument.Parse(nyers);

                if (!doc.RootElement.TryGetProperty("nutrition", out var nutr) ||
                    !nutr.TryGetProperty("nutrients", out var nutrients))
                    return (0, 0, 0, 0);

                double kcal = 0, feherje = 0, szenhidrat = 0, zsir = 0;

                foreach (var nutrient in nutrients.EnumerateArray())
                {
                    string nev = nutrient.TryGetProperty("name", out var nn) ? nn.GetString() ?? "" : "";
                    double amount = nutrient.TryGetProperty("amount", out var a) ? a.GetDouble() : 0;

                    switch (nev)
                    {
                        case "Calories": kcal = Math.Round(amount, 1); break;
                        case "Protein": feherje = Math.Round(amount, 1); break;
                        case "Carbohydrates": szenhidrat = Math.Round(amount, 1); break;
                        case "Fat": zsir = Math.Round(amount, 1); break;
                    }
                }

                var eredmeny = (kcal, feherje, szenhidrat, zsir);
                nutrition_cache[cache_key] = eredmeny;
                return eredmeny;
            }
            catch (Exception)
            {
                return (0, 0, 0, 0);
            }
        }

        // --- Open Food Facts — vonalkód segédfüggvény ---

        private static FoodItem? OffTermekbolFoodItem(JsonElement termek)
        {
            string nev = OffTermekNev(termek);
            if (string.IsNullOrWhiteSpace(nev)) return null;

            string marka = termek.TryGetProperty("brands", out var m) ? m.GetString() ?? "" : "";
            string teljes_nev = string.IsNullOrWhiteSpace(marka) ? nev : $"[{marka}] {nev}";
            string id = termek.TryGetProperty("code", out var c) ? c.GetString() ?? "0" : "0";
            string kep = termek.TryGetProperty("image_front_thumb_url", out var k) ? k.GetString() ?? "" : "";

            double kcal = 0, feherje = 0, szenhidrat = 0, zsir = 0;

            if (termek.TryGetProperty("nutriments", out var nu))
            {
                kcal = OffNutriment(nu, "energy-kcal_100g");
                if (kcal <= 0)
                {
                    double kj = OffNutriment(nu, "energy-kj_100g");
                    if (kj > 0) kcal = kj / 4.184;
                }
                feherje = OffNutriment(nu, "proteins_100g");
                szenhidrat = OffNutriment(nu, "carbohydrates_100g");
                zsir = OffNutriment(nu, "fat_100g");
            }

            return new FoodItem
            {
                Id = id,
                Name = teljes_nev,
                Calories = Math.Round(kcal, 1),
                Protein = Math.Round(feherje, 1),
                Carbs = Math.Round(szenhidrat, 1),
                Fat = Math.Round(zsir, 1),
                ImageUrl = kep
            };
        }

        private static string OffTermekNev(JsonElement termek)
        {
            foreach (var mezo in new[] { "product_name_hu", "product_name_en", "product_name" })
            {
                if (termek.TryGetProperty(mezo, out var v) && v.ValueKind == JsonValueKind.String)
                {
                    string s = v.GetString() ?? "";
                    if (!string.IsNullOrWhiteSpace(s)) return s;
                }
            }
            return "";
        }

        private static double OffNutriment(JsonElement nu, string mezo)
        {
            if (!nu.TryGetProperty(mezo, out var e)) return 0;
            if (e.ValueKind == JsonValueKind.Number) return e.GetDouble();
            if (e.ValueKind == JsonValueKind.String &&
                double.TryParse(e.GetString(), System.Globalization.NumberStyles.Any,
                    System.Globalization.CultureInfo.InvariantCulture, out var v))
                return v;
            return 0;
        }

        private static DailyNutritionSession NaploLekerdezeseVagyLetrehozasa(DateTime datum)
            => NutritionTarolo.NaploLekerdezeseVagyLetrehozasa(datum);
    }
}
