using System.Collections.Concurrent;
using System.Globalization;
using System.Text.Json;
using System.Text.RegularExpressions;

namespace FitnessBackend.Models
{
    /// <summary>
    /// Nosalty.hu recept integráció — HTML + schema.org JSON-LD feldolgozás.
    /// </summary>
    public static class NosaltyApiSeged
    {
        private const string BaseUrl = "https://www.nosalty.hu";
        private static readonly HttpClient kliens = new()
        {
            Timeout = TimeSpan.FromSeconds(20),
        };

        private static readonly ConcurrentDictionary<string, (DateTime ido, List<ReceptListaElem> lista)> lista_cache = new();
        private static readonly ConcurrentDictionary<string, (DateTime ido, ReceptReszletes? recept)> reszlet_cache = new();
        private static readonly TimeSpan cache_ido = TimeSpan.FromHours(6);

        static NosaltyApiSeged()
        {
            kliens.DefaultRequestHeaders.UserAgent.ParseAdd(
                "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36 FitnessBackend/1.0");
            kliens.DefaultRequestHeaders.Accept.ParseAdd("text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8");
            kliens.DefaultRequestHeaders.AcceptLanguage.ParseAdd("hu-HU,hu;q=0.9,en;q=0.8");
        }

        public static readonly List<ReceptKategoria> Kategoriak = new()
        {
            new() { Id = "levesek/husleves",       Nev = "Levesek",     Ikon = "🍲" },
            new() { Id = "fozelekek",              Nev = "Főzelék",     Ikon = "🥘" },
            new() { Id = "porkolt",                Nev = "Pörkölt",     Ikon = "🍖" },
            new() { Id = "egytaletelek",           Nev = "Egytálétel",  Ikon = "🥘" },
            new() { Id = "edes-suti",              Nev = "Sütemény",    Ikon = "🍰" },
            new() { Id = "salata",                 Nev = "Saláta",      Ikon = "🥗" },
            new() { Id = "palacsinta/palacsinta-alapteszta", Nev = "Palacsinta", Ikon = "🥞" },
            new() { Id = "mentes-receptek/vegan-receptek",   Nev = "Vegán",      Ikon = "🌱" },
            new() { Id = "koretek",                Nev = "Köret",       Ikon = "🍚" },
            new() { Id = "pite",                   Nev = "Pite",        Ikon = "🥧" },
        };

        public static async Task<List<ReceptListaElem>> Kereses(string keresoszó, int darab = 20)
        {
            string kulcs = $"search_{Normalizalt(keresoszó)}_{darab}";
            if (CacheLista(kulcs, out var cached)) return cached!;

            var osszes = new List<ReceptListaElem>();
            var latva = new HashSet<string>();

            foreach (var elem in await KozvetlenSlugKereses(keresoszó))
            {
                if (latva.Add(elem.Id))
                    osszes.Add(elem);
            }

            string q = Uri.EscapeDataString(keresoszó.Trim());
            for (int oldal = 1; oldal <= 8 && osszes.Count < darab; oldal++)
            {
                string url = $"{BaseUrl}/kereses/recept?q={q}&rendezes=relevancia&page={oldal}";
                string html = await OldalLetoltese(url);
                foreach (var elem in ListaElemekHtmlbol(html, darab * 2, csakKeresesiEredmeny: true))
                {
                    if (!IlleszkedikKeresoszohoz(keresoszó, elem)) continue;
                    if (latva.Add(elem.Id))
                        osszes.Add(elem);
                }

                if (!VanTovabbiKeresesiOldal(html, oldal)) break;
            }

            var lista = osszes.Take(darab).ToList();
            lista = await ListaElemekKiegeszitese(lista);
            CacheListaMentese(kulcs, lista);
            return lista;
        }

        public static async Task<List<ReceptListaElem>> KategoriaSzerint(string kategoriaUt, int darab = 12)
        {
            string kulcs = $"kat_{kategoriaUt}_{darab}";
            if (CacheLista(kulcs, out var cached)) return cached!;

            string url = $"{BaseUrl}/receptek/kategoria/{kategoriaUt.Trim('/')}";
            string html = await OldalLetoltese(url);
            var lista = ListaElemekHtmlbol(html, darab);
            if (lista.Count == 0)
                lista = HasonloReceptekHtmlbol(html, darab, KategoriaNev(kategoriaUt));

            lista = await ListaElemekKiegeszitese(lista);
            CacheListaMentese(kulcs, lista);
            return lista;
        }

        public static async Task<List<ReceptListaElem>> Felfedezes(int darab = 12)
        {
            string kulcs = $"felf_{darab}";
            if (CacheLista(kulcs, out var cached)) return cached!;

            string html = await OldalLetoltese($"{BaseUrl}/receptek");
            var lista = ListaElemekHtmlbol(html, darab);
            lista = await ListaElemekKiegeszitese(lista);
            CacheListaMentese(kulcs, lista);
            return lista;
        }

        public static async Task<List<ReceptListaElem>> KaloriaSzerint(int min, int max, int darab = 12)
        {
            string kulcs = $"kcal_{min}_{max}_{darab}";
            if (CacheLista(kulcs, out var cached)) return cached!;

            var osszes = new List<ReceptListaElem>();
            var latva = new HashSet<string>();

            foreach (string url in KaloriaForrasUrlek(min, max))
            {
                if (osszes.Count >= darab * 4) break;

                try
                {
                    string html = await OldalLetoltese(url);
                    foreach (var elem in ListaElemekHtmlbol(html, darab * 3))
                    {
                        if (!latva.Add(elem.Id)) continue;
                        // 0 kcal = ismeretlen a listán — később JSON-LD-ből pótoljuk.
                        if (elem.BecsultKaloria > 0 && (elem.BecsultKaloria < min || elem.BecsultKaloria > max))
                            continue;
                        osszes.Add(elem);
                        if (osszes.Count >= darab * 4) break;
                    }
                }
                catch
                {
                    // Egy forrás hibája ne állítsa le a többit.
                }
            }

            var lista = osszes.Take(darab * 4).ToList();
            lista = await ListaElemekKiegeszitese(lista);
            lista = lista
                .Where(r => r.BecsultKaloria >= min && r.BecsultKaloria <= max)
                .Take(darab)
                .ToList();
            CacheListaMentese(kulcs, lista);
            return lista;
        }

        private static IEnumerable<string> KaloriaForrasUrlek(int min, int max)
        {
            int kozep = (min + max) / 2;

            // Kalória szerinti rendezés — a cél-tartomány környéki oldalak.
            foreach (int oldal in KaloriaOldalJeloltek(kozep))
            {
                yield return $"{BaseUrl}/kereses/recept?rendezes=kaloria-novekvo&page={oldal}";
            }

            // Főoldal + kategóriák — változatos receptek kalória adattal a kártyákon.
            for (int oldal = 1; oldal <= 3; oldal++)
                yield return oldal == 1 ? $"{BaseUrl}/receptek" : $"{BaseUrl}/receptek?page={oldal}";

            foreach (var kat in Kategoriak)
            {
                yield return $"{BaseUrl}/receptek/kategoria/{kat.Id.Trim('/')}";
                yield return $"{BaseUrl}/receptek/kategoria/{kat.Id.Trim('/')}?page=2";
            }
        }

        private static IEnumerable<int> KaloriaOldalJeloltek(int kozepKcal)
        {
            // A Nosalty növekvő kalória rendezésén kb. 1,3 kcal / oldal — durva becslés a cél-tartományhoz.
            int kozepOldal = Math.Max(1, (int)Math.Round(kozepKcal / 1.3));
            yield return kozepOldal;
            for (int elteres = 1; elteres <= 12; elteres++)
            {
                if (kozepOldal - elteres > 0) yield return kozepOldal - elteres;
                yield return kozepOldal + elteres;
            }
        }

        public static async Task<ReceptReszletes?> ReceptLekerdezese(string receptId)
        {
            string slug = SlugKinyerese(receptId);
            if (string.IsNullOrWhiteSpace(slug)) return null;

            string kulcs = $"resz_{slug}";
            if (reszlet_cache.TryGetValue(kulcs, out var c) && DateTime.UtcNow - c.ido < cache_ido)
                return c.recept;

            string html = await OldalLetoltese($"{BaseUrl}/recept/{slug}");
            var recept = ReszletesJsonLdbol(html, slug);
            reszlet_cache[kulcs] = (DateTime.UtcNow, recept);
            return recept;
        }

        public static LoggedFood ReceptbolNaploBejegyzes(ReceptReszletes recept, double adagSzam, string etkezesTipus)
        {
            return new LoggedFood
            {
                FoodId = $"recept_{recept.Id}",
                ReceptId = recept.Id,
                FoodName = recept.Nev,
                Receptbol = true,
                AdagSzam = adagSzam,
                MealType = etkezesTipus,
                KepUrl = recept.KepUrl,
                CaloriesPer100g = recept.BecsultKaloria,
                ProteinPer100g = recept.BecsultFeherje,
                CarbsPer100g = recept.BecsultSzenhidrat,
                FatPer100g = recept.BecsultZsir,
            };
        }

        public static string SlugKinyerese(string receptId)
        {
            if (string.IsNullOrWhiteSpace(receptId)) return "";
            if (receptId.StartsWith("nosalty_", StringComparison.OrdinalIgnoreCase))
                return receptId["nosalty_".Length..];
            if (receptId.StartsWith("local_", StringComparison.OrdinalIgnoreCase))
                return "";
            if (Regex.IsMatch(receptId, @"^\d+$"))
                return "";
            return receptId.Trim('/');
        }

        public static string IdFromSlug(string slug) => $"nosalty_{slug}";

        private static async Task<string> OldalLetoltese(string url)
        {
            var response = await kliens.GetAsync(url);
            response.EnsureSuccessStatusCode();
            return await response.Content.ReadAsStringAsync();
        }

        private static async Task<List<ReceptListaElem>> ListaElemekKiegeszitese(IReadOnlyList<ReceptListaElem> lista)
        {
            if (lista.Count == 0) return new List<ReceptListaElem>();

            var sem = new SemaphoreSlim(5);
            var tasks = lista.Select(async elem =>
            {
                if (!HianyzoTapertek(elem)) return elem;
                await sem.WaitAsync();
                try
                {
                    return await ListaElemKiegeszitese(elem);
                }
                finally
                {
                    sem.Release();
                }
            });

            return (await Task.WhenAll(tasks)).ToList();
        }

        private static bool HianyzoTapertek(ReceptListaElem elem) =>
            elem.BecsultKaloria <= 0 ||
            string.IsNullOrWhiteSpace(elem.KepUrl) ||
            (elem.BecsultFeherje <= 0 && elem.BecsultSzenhidrat <= 0 && elem.BecsultZsir <= 0);

        private static async Task<ReceptListaElem> ListaElemKiegeszitese(ReceptListaElem elem)
        {
            var reszlet = await ReceptLekerdezese(elem.Id);
            if (reszlet == null) return elem;

            if (elem.BecsultKaloria <= 0) elem.BecsultKaloria = reszlet.BecsultKaloria;
            if (string.IsNullOrWhiteSpace(elem.KepUrl)) elem.KepUrl = reszlet.KepUrl;
            if (elem.BecsultFeherje <= 0) elem.BecsultFeherje = reszlet.BecsultFeherje;
            if (elem.BecsultSzenhidrat <= 0) elem.BecsultSzenhidrat = reszlet.BecsultSzenhidrat;
            if (elem.BecsultZsir <= 0) elem.BecsultZsir = reszlet.BecsultZsir;
            if (elem.HozzavaloSzam <= 0) elem.HozzavaloSzam = reszlet.HozzavaloSzam;
            if (elem.Cimkek.Count == 0 && reszlet.Cimkek.Count > 0) elem.Cimkek = reszlet.Cimkek;
            return elem;
        }

        private static List<ReceptListaElem> ListaElemekHtmlbol(string html, int max, bool csakKeresesiEredmeny = false)
        {
            string scope = KeresesiScope(html, csakKeresesiEredmeny);
            var lista = KartyaLista(scope, max);
            if (lista.Count > 0) return lista;
            return GyorsLinkLista(scope, max);
        }

        private static string KeresesiScope(string html, bool csakKeresesiEredmeny)
        {
            if (!csakKeresesiEredmeny) return html;

            var scopeMatch = Regex.Match(html,
                @"id=""recipe-search-result""[\s\S]*?(?=id=""recipe-search-filter|<footer|</body>)",
                RegexOptions.IgnoreCase);
            return scopeMatch.Success ? scopeMatch.Value : html;
        }

        private static List<ReceptListaElem> KartyaLista(string html, int max)
        {
            var lista = new List<ReceptListaElem>();
            var latva = new HashSet<string>();

            var articleRegex = new Regex(
                @"<article class=""m-articleCard[^""]*""[^>]*>(.*?)</article>",
                RegexOptions.Singleline | RegexOptions.IgnoreCase);

            foreach (Match article in articleRegex.Matches(html))
            {
                var elem = KartyaElembol(article.Groups[1].Value);
                if (elem == null || !latva.Add(elem.Id)) continue;
                lista.Add(elem);
                if (lista.Count >= max) break;
            }

            return lista;
        }

        private static async Task<List<ReceptListaElem>> KozvetlenSlugKereses(string keresoszó)
        {
            var lista = new List<ReceptListaElem>();
            foreach (string slug in SlugJeloltek(keresoszó))
            {
                try
                {
                    var elem = await ListaElemSlugbol(slug);
                    if (elem != null) lista.Add(elem);
                }
                catch
                {
                    // A slug nem létezik — következő jelölt.
                }
            }

            return lista;
        }

        private static IEnumerable<string> SlugJeloltek(string keresoszó)
        {
            var latva = new HashSet<string>();
            string alap = SlugFromText(keresoszó);
            if (alap.Length >= 3 && latva.Add(alap)) yield return alap;

            foreach (string szo in NormalizaltSzavak(keresoszó).Where(s => s.Length >= 4))
            {
                if (latva.Add(szo)) yield return szo;
            }
        }

        private static async Task<ReceptListaElem?> ListaElemSlugbol(string slug)
        {
            string html = await OldalLetoltese($"{BaseUrl}/recept/{slug}");
            if (!html.Contains("\"@type\": \"Recipe\"", StringComparison.Ordinal) &&
                !html.Contains("\"@type\":\"Recipe\"", StringComparison.Ordinal))
                return null;

            using var doc = JsonDocument.Parse(JsonLdRecipe(html));
            var root = doc.RootElement;
            string nev = JsonString(root, "name");
            if (string.IsNullOrWhiteSpace(nev)) return null;

            int adag = Math.Max(1, JsonInt(root, "recipeYield", 1));
            var (kcal, _, _, _) = TapertekPerAdag(root, adag);

            return new ReceptListaElem
            {
                Id = IdFromSlug(slug),
                Nev = nev,
                KepUrl = KepJsonbol(root),
                BecsultKaloria = kcal,
                Cimkek = kcal > 0 ? CimkekKaloriaAlapjan(kcal) : new List<string>(),
            };
        }

        private static bool IlleszkedikKeresoszohoz(string keresoszó, ReceptListaElem elem)
        {
            var tokenek = NormalizaltSzavak(keresoszó);
            if (tokenek.Count == 0) return true;

            string nev = Normalizalt(elem.Nev);
            string slug = Normalizalt(SlugKinyerese(elem.Id).Replace('-', ' '));
            return tokenek.All(t => nev.Contains(t) || slug.Contains(t));
        }

        private static bool VanTovabbiKeresesiOldal(string html, int oldal)
        {
            string kovetkezo = $"/kereses/recept?q=";
            return html.Contains($"{kovetkezo}", StringComparison.OrdinalIgnoreCase) &&
                   html.Contains($"page={oldal + 1}", StringComparison.OrdinalIgnoreCase);
        }

        private static string SlugFromText(string szoveg)
        {
            var sb = new System.Text.StringBuilder();
            bool elozoKotojel = false;
            foreach (char c in Normalizalt(szoveg))
            {
                if (char.IsLetterOrDigit(c))
                {
                    sb.Append(c);
                    elozoKotojel = false;
                }
                else if (!elozoKotojel && sb.Length > 0)
                {
                    sb.Append('-');
                    elozoKotojel = true;
                }
            }

            return sb.ToString().Trim('-');
        }

        private static List<string> NormalizaltSzavak(string szoveg) =>
            Normalizalt(szoveg)
                .Split(' ', StringSplitOptions.RemoveEmptyEntries | StringSplitOptions.TrimEntries)
                .Where(s => s.Length >= 3)
                .Distinct()
                .ToList();

        private static string Normalizalt(string szoveg)
        {
            if (string.IsNullOrWhiteSpace(szoveg)) return "";
            string s = szoveg.ToLowerInvariant().Normalize(System.Text.NormalizationForm.FormD);
            var sb = new System.Text.StringBuilder(s.Length);
            foreach (char c in s)
            {
                if (System.Globalization.CharUnicodeInfo.GetUnicodeCategory(c) != System.Globalization.UnicodeCategory.NonSpacingMark)
                    sb.Append(c);
            }

            return sb.ToString().Normalize(System.Text.NormalizationForm.FormC);
        }

        private static List<ReceptListaElem> GyorsLinkLista(string html, int max)
        {
            var scopeMatch = Regex.Match(html,
                @"id=""recipe-search-result""[\s\S]*?(?=id=""recipe-search-filter|<footer|</body>)",
                RegexOptions.IgnoreCase);
            string scope = scopeMatch.Success ? scopeMatch.Value : html;

            var lista = new List<ReceptListaElem>();
            var latva = new HashSet<string>();

            var linkRegex = new Regex(
                @"href=""(?:https://www\.nosalty\.hu)?/recept/([a-z0-9\-]+)""[^>]*>[\s\S]*?m-articleCard__headline[^>]*>([^<]+)</a>",
                RegexOptions.Singleline | RegexOptions.IgnoreCase);

            foreach (Match m in linkRegex.Matches(scope))
            {
                string slug = m.Groups[1].Value;
                string id = IdFromSlug(slug);
                if (!latva.Add(id)) continue;

                lista.Add(new ReceptListaElem
                {
                    Id = id,
                    Nev = HtmlDecode(m.Groups[2].Value.Trim()),
                    KepUrl = KepKinyereseBlokbol(m.Value),
                    BecsultKaloria = KcalKinyereseBlokbol(m.Value),
                    Cimkek = CimkekKaloriaAlapjan(KcalKinyereseBlokbol(m.Value)),
                });
                if (lista.Count >= max) break;
            }

            return lista;
        }

        private static List<ReceptListaElem> HasonloReceptekHtmlbol(string html, int max, string kategoria)
        {
            var lista = new List<ReceptListaElem>();
            var latva = new HashSet<string>();

            var linkRegex = new Regex(
                @"href=""(?:https://www\.nosalty\.hu)?/recept/([a-z0-9\-]+)""[^>]*>[\s\S]*?m-articleCard__headline[^>]*>\s*([^<]+)\s*</h2>",
                RegexOptions.Singleline | RegexOptions.IgnoreCase);

            foreach (Match m in linkRegex.Matches(html))
            {
                string slug = m.Groups[1].Value;
                string id = IdFromSlug(slug);
                if (!latva.Add(id)) continue;

                string img = KepKinyereseBlokbol(m.Value);
                lista.Add(new ReceptListaElem
                {
                    Id = id,
                    Nev = HtmlDecode(m.Groups[2].Value.Trim()),
                    KepUrl = img,
                    Kategoria = kategoria,
                });
                if (lista.Count >= max) break;
            }

            return lista;
        }

        private static ReceptListaElem? KartyaElembol(string block)
        {
            var slugMatch = Regex.Match(block, @"/recept/([a-z0-9\-]+)", RegexOptions.IgnoreCase);
            if (!slugMatch.Success) return null;

            string slug = slugMatch.Groups[1].Value;
            var nevMatch = Regex.Match(block,
                @"m-articleCard__headline[^>]*>([^<]+)</a>",
                RegexOptions.IgnoreCase | RegexOptions.Singleline);
            if (!nevMatch.Success)
            {
                nevMatch = Regex.Match(block,
                    @"m-articleCard__headline[^>]*>\s*([^<]+)\s*</",
                    RegexOptions.IgnoreCase | RegexOptions.Singleline);
            }
            if (!nevMatch.Success) return null;

            int kcal = KcalKinyereseBlokbol(block);

            return new ReceptListaElem
            {
                Id = IdFromSlug(slug),
                Nev = HtmlDecode(nevMatch.Groups[1].Value.Trim()),
                KepUrl = KepKinyereseBlokbol(block),
                BecsultKaloria = kcal,
                Kategoria = KategoriaBlokbol(block),
                Cimkek = kcal > 0 ? CimkekKaloriaAlapjan(kcal) : new List<string>(),
            };
        }

        private static int KcalKinyereseBlokbol(string block)
        {
            var kcalMatch = Regex.Match(block, @"(\d+)\s*kcal", RegexOptions.IgnoreCase);
            return kcalMatch.Success ? int.Parse(kcalMatch.Groups[1].Value) : 0;
        }

        private static string KepKinyereseBlokbol(string block)
        {
            var imgMatch = Regex.Match(block,
                @"src=""(https://image-api\.nosalty\.hu/nosalty/images/recipes/[^""?]+(?:\?[^""]*)?)""",
                RegexOptions.IgnoreCase);
            if (imgMatch.Success)
                return KepUrlNormalizalas(imgMatch.Groups[1].Value);

            var srcsetMatch = Regex.Match(block,
                @"data-srcset=""(https://image-api\.nosalty\.hu/nosalty/images/recipes/[^""\s]+)",
                RegexOptions.IgnoreCase);
            if (srcsetMatch.Success)
                return KepUrlNormalizalas(srcsetMatch.Groups[1].Value);

            var lazyMatch = Regex.Match(block,
                @"data-src=""(https://image-api\.nosalty\.hu/nosalty/images/recipes/[^""?]+(?:\?[^""]*)?)""",
                RegexOptions.IgnoreCase);
            return lazyMatch.Success ? KepUrlNormalizalas(lazyMatch.Groups[1].Value) : "";
        }

        private static string KepUrlNormalizalas(string url) =>
            url.Replace("&amp;", "&");

        private static ReceptReszletes? ReszletesJsonLdbol(string html, string slug)
        {
            using var doc = JsonDocument.Parse(JsonLdRecipe(html));
            var root = doc.RootElement;

            string nev = JsonString(root, "name");
            if (string.IsNullOrWhiteSpace(nev)) return null;

            int adag = JsonInt(root, "recipeYield", 1);
            if (adag <= 0) adag = 1;

            var (kcal, feherje, szenhidrat, zsir) = TapertekPerAdag(root, adag);
            var osszetevok = OsszetevokJsonbol(root);
            string utasitas = UtasitasJsonbol(root);
            string kep = KepJsonbol(root);
            string kategoria = JsonString(root, "recipeCategory");
            string konyha = JsonString(root, "recipeCuisine");
            var cimkek = CimkekJsonbol(root, kcal, feherje);

            bool gyors = IdotartamPerc(root, "totalTime") <= 30
                         || IdotartamPerc(root, "prepTime") + IdotartamPerc(root, "cookTime") <= 30;

            return new ReceptReszletes
            {
                Id = IdFromSlug(slug),
                Nev = nev,
                KepUrl = kep,
                Kategoria = string.IsNullOrWhiteSpace(kategoria) ? konyha : kategoria,
                SzarmazasiTerulet = konyha,
                BecsultKaloria = kcal,
                BecsultFeherje = feherje,
                BecsultSzenhidrat = szenhidrat,
                BecsultZsir = zsir,
                HozzavaloSzam = osszetevok.Count,
                GyorsElkeszitheto = gyors,
                Leiras = utasitas,
                Osszetevok = osszetevok,
                Cimkek = cimkek,
            };
        }

        private static string JsonLdRecipe(string html)
        {
            var matches = Regex.Matches(html,
                @"<script type=""application/ld\+json"">\s*(.*?)\s*</script>",
                RegexOptions.Singleline | RegexOptions.IgnoreCase);

            foreach (Match m in matches)
            {
                string nyers = m.Groups[1].Value.Trim();
                if (nyers.Contains("\"@type\": \"Recipe\"", StringComparison.Ordinal) ||
                    nyers.Contains("\"@type\":\"Recipe\"", StringComparison.Ordinal))
                    return nyers;
            }

            throw new InvalidOperationException("Nincs Recipe JSON-LD a Nosalty oldalon.");
        }

        private static (int kcal, double feherje, double szenhidrat, double zsir) TapertekPerAdag(JsonElement root, int adag)
        {
            if (!root.TryGetProperty("nutrition", out var nutr))
                return (0, 0, 0, 0);

            double feherje = NutrientErtek(nutr, "proteinContent") / adag;
            double szenhidrat = NutrientErtek(nutr, "carbohydrateContent") / adag;
            double zsir = NutrientErtek(nutr, "fatContent") / adag;
            double kcalDouble = NutrientErtek(nutr, "calories") / adag;

            int kcal = (int)Math.Round(kcalDouble);
            if (kcal <= 0 && feherje + szenhidrat + zsir > 0)
                kcal = (int)Math.Round(feherje * 4 + szenhidrat * 4 + zsir * 9);

            return (kcal, Math.Round(feherje, 1), Math.Round(szenhidrat, 1), Math.Round(zsir, 1));
        }

        private static double NutrientErtek(JsonElement nutr, string mezo)
        {
            if (!nutr.TryGetProperty(mezo, out var elem)) return 0;
            string szoveg = elem.ValueKind == JsonValueKind.String ? elem.GetString() ?? "" : elem.GetRawText();
            var match = Regex.Match(szoveg.Replace(',', '.'), @"([\d.]+)");
            return match.Success && double.TryParse(match.Groups[1].Value, NumberStyles.Any, CultureInfo.InvariantCulture, out var v)
                ? v : 0;
        }

        private static List<ReceptOsszetevo> OsszetevokJsonbol(JsonElement root)
        {
            var lista = new List<ReceptOsszetevo>();
            if (!root.TryGetProperty("recipeIngredient", out var arr) || arr.ValueKind != JsonValueKind.Array)
                return lista;

            foreach (var item in arr.EnumerateArray())
            {
                string sor = item.GetString()?.Trim() ?? "";
                if (string.IsNullOrWhiteSpace(sor)) continue;

                var parts = sor.Split(' ', 2, StringSplitOptions.RemoveEmptyEntries);
                if (parts.Length == 2 && Regex.IsMatch(parts[0], @"^[\d,/\.]+"))
                    lista.Add(new ReceptOsszetevo { Mennyiseg = parts[0], Nev = parts[1] });
                else
                    lista.Add(new ReceptOsszetevo { Nev = sor });
            }

            return lista;
        }

        private static string UtasitasJsonbol(JsonElement root)
        {
            if (!root.TryGetProperty("recipeInstructions", out var arr) || arr.ValueKind != JsonValueKind.Array)
                return "";

            var lepesek = new List<string>();
            int i = 1;
            foreach (var item in arr.EnumerateArray())
            {
                string lepes = item.ValueKind == JsonValueKind.String
                    ? item.GetString() ?? ""
                    : item.TryGetProperty("text", out var t) ? t.GetString() ?? "" : "";
                lepes = lepes.Trim();
                if (string.IsNullOrWhiteSpace(lepes)) continue;
                lepesek.Add($"{i}. {lepes}");
                i++;
            }

            return string.Join("\n\n", lepesek);
        }

        private static string KepJsonbol(JsonElement root)
        {
            if (root.TryGetProperty("image", out var img))
            {
                if (img.ValueKind == JsonValueKind.Array)
                {
                    foreach (var item in img.EnumerateArray())
                    {
                        if (item.TryGetProperty("url", out var url))
                            return url.GetString() ?? "";
                        if (item.ValueKind == JsonValueKind.String)
                            return item.GetString() ?? "";
                    }
                }
                else if (img.ValueKind == JsonValueKind.String)
                {
                    return img.GetString() ?? "";
                }
            }

            if (root.TryGetProperty("thumbnailUrl", out var thumbs) && thumbs.ValueKind == JsonValueKind.Array)
            {
                foreach (var t in thumbs.EnumerateArray())
                {
                    string url = t.GetString() ?? "";
                    if (!string.IsNullOrWhiteSpace(url)) return url;
                }
            }

            return "";
        }

        private static List<string> CimkekJsonbol(JsonElement root, int kcal, double feherje)
        {
            var cimkek = new List<string>();
            if (feherje >= 25) cimkek.Add("Magas fehérje");
            if (kcal > 0 && kcal < 300) cimkek.Add("Alacsony kalória");

            string keywords = JsonString(root, "keywords");
            foreach (var tag in keywords.Split(',', StringSplitOptions.RemoveEmptyEntries | StringSplitOptions.TrimEntries))
            {
                if (!string.IsNullOrWhiteSpace(tag) && cimkek.Count < 6)
                    cimkek.Add(tag);
            }

            return cimkek;
        }

        private static List<string> CimkekKaloriaAlapjan(int kcal)
        {
            var cimkek = new List<string>();
            if (kcal < 300) cimkek.Add("Alacsony kalória");
            if (kcal >= 450) cimkek.Add("Kiadós");
            return cimkek;
        }

        private static string KategoriaBlokbol(string block)
        {
            var match = Regex.Match(block,
                @"-articleCategory[^>]*>([^<]+)</span>",
                RegexOptions.IgnoreCase);
            if (!match.Success) return "";
            string szoveg = match.Groups[1].Value.Trim();
            return szoveg.EndsWith("kcal", StringComparison.OrdinalIgnoreCase) ? "" : szoveg;
        }

        private static string KategoriaNev(string ut) =>
            Kategoriak.FirstOrDefault(k => k.Id.Equals(ut, StringComparison.OrdinalIgnoreCase))?.Nev ?? ut;

        private static int IdotartamPerc(JsonElement root, string mezo)
        {
            string iso = JsonString(root, mezo);
            if (string.IsNullOrWhiteSpace(iso)) return 999;

            int perc = 0;
            var ora = Regex.Match(iso, @"(\d+)H", RegexOptions.IgnoreCase);
            var p = Regex.Match(iso, @"(\d+)M", RegexOptions.IgnoreCase);
            if (ora.Success) perc += int.Parse(ora.Groups[1].Value) * 60;
            if (p.Success) perc += int.Parse(p.Groups[1].Value);
            return perc;
        }

        private static string JsonString(JsonElement elem, string mezo) =>
            elem.TryGetProperty(mezo, out var v) && v.ValueKind == JsonValueKind.String ? v.GetString() ?? "" : "";

        private static int JsonInt(JsonElement elem, string mezo, int alap)
        {
            if (!elem.TryGetProperty(mezo, out var v)) return alap;
            if (v.ValueKind == JsonValueKind.Number) return v.GetInt32();
            if (v.ValueKind == JsonValueKind.String && int.TryParse(v.GetString(), out var i)) return i;
            return alap;
        }

        private static string HtmlDecode(string s) =>
            System.Net.WebUtility.HtmlDecode(s).Replace("\u00a0", " ").Trim();

        private static bool CacheLista(string kulcs, out List<ReceptListaElem>? lista)
        {
            if (lista_cache.TryGetValue(kulcs, out var c) && DateTime.UtcNow - c.ido < cache_ido)
            {
                lista = c.lista;
                return true;
            }
            lista = null;
            return false;
        }

        private static void CacheListaMentese(string kulcs, List<ReceptListaElem> lista)
        {
            if (lista.Count > 0)
                lista_cache[kulcs] = (DateTime.UtcNow, lista);
        }
    }
}
