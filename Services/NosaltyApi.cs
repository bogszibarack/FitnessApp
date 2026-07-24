using System.Collections.Concurrent;
using System.Globalization;
using System.Text.Json;
using System.Text.RegularExpressions;

using FitnessBackend.Models;

namespace FitnessBackend.Services
{
    /// <summary>
    /// Nosalty.hu recept integráció — HTML + schema.org JSON-LD feldolgozás.
    /// </summary>
    public static class NosaltyApi
    {
        private const string BaseUrl = "https://www.nosalty.hu";
        private static readonly HttpClient Http = new()
        {
            Timeout = TimeSpan.FromSeconds(20),
        };

        private static readonly ConcurrentDictionary<string, (DateTime ido, List<RecipeListItem> lista)> ListCache = new();
        private static readonly ConcurrentDictionary<string, (DateTime ido, RecipeDetail? recept)> DetailCache = new();
        private static readonly TimeSpan CacheTtl = TimeSpan.FromHours(6);

        static NosaltyApi()
        {
            Http.DefaultRequestHeaders.UserAgent.ParseAdd(
                "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36 FitnessBackend/1.0");
            Http.DefaultRequestHeaders.Accept.ParseAdd("text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8");
            Http.DefaultRequestHeaders.AcceptLanguage.ParseAdd("hu-HU,hu;q=0.9,en;q=0.8");
        }

        public static readonly List<RecipeCategory> Categories = new()
        {
            new() { Id = "levesek/husleves",       Name = "Levesek",     Icon = "🍲" },
            new() { Id = "fozelekek",              Name = "Főzelék",     Icon = "🥘" },
            new() { Id = "porkolt",                Name = "Pörkölt",     Icon = "🍖" },
            new() { Id = "egytaletelek",           Name = "Egytálétel",  Icon = "🥘" },
            new() { Id = "edes-suti",              Name = "Sütemény",    Icon = "🍰" },
            new() { Id = "salata",                 Name = "Saláta",      Icon = "🥗" },
            new() { Id = "palacsinta/palacsinta-alapteszta", Name = "Palacsinta", Icon = "🥞" },
            new() { Id = "mentes-receptek/vegan-receptek",   Name = "Vegán",      Icon = "🌱" },
            new() { Id = "koretek",                Name = "Köret",       Icon = "🍚" },
            new() { Id = "pite",                   Name = "Pite",        Icon = "🥧" },
        };

        public static async Task<List<RecipeListItem>> SearchAsync(string keresoszó, int darab = 20)
        {
            string kulcs = $"search_{Normalize(keresoszó)}_{darab}";
            if (TryGetCachedList(kulcs, out var cached)) return cached!;

            var osszes = new List<RecipeListItem>();
            var latva = new HashSet<string>();

            foreach (var elem in await DirectSlugSearchAsync(keresoszó))
            {
                if (latva.Add(elem.Id))
                    osszes.Add(elem);
            }

            string q = Uri.EscapeDataString(keresoszó.Trim());
            for (int oldal = 1; oldal <= 8 && osszes.Count < darab; oldal++)
            {
                string url = $"{BaseUrl}/kereses/recept?q={q}&rendezes=relevancia&page={oldal}";
                string html = await FetchPageAsync(url);
                foreach (var elem in ParseListFromHtml(html, darab * 2, csakKeresesiEredmeny: true))
                {
                    if (!MatchesQuery(keresoszó, elem)) continue;
                    if (latva.Add(elem.Id))
                        osszes.Add(elem);
                }

                if (!HasNextSearchPage(html, oldal)) break;
            }

            var lista = osszes.Take(darab).ToList();
            lista = await EnrichListAsync(lista);
            SetCachedList(kulcs, lista);
            return lista;
        }

        public static async Task<List<RecipeListItem>> ByCategoryAsync(string kategoriaUt, int darab = 12)
        {
            string kulcs = $"kat_{kategoriaUt}_{darab}";
            if (TryGetCachedList(kulcs, out var cached)) return cached!;

            string url = $"{BaseUrl}/receptek/kategoria/{kategoriaUt.Trim('/')}";
            string html = await FetchPageAsync(url);
            var lista = ParseListFromHtml(html, darab);
            if (lista.Count == 0)
                lista = ParseSimilarRecipes(html, darab, CategoryName(kategoriaUt));

            lista = await EnrichListAsync(lista);
            SetCachedList(kulcs, lista);
            return lista;
        }

        public static async Task<List<RecipeListItem>> DiscoverAsync(int darab = 12)
        {
            string kulcs = $"felf_{darab}";
            if (TryGetCachedList(kulcs, out var cached)) return cached!;

            string html = await FetchPageAsync($"{BaseUrl}/receptek");
            var lista = ParseListFromHtml(html, darab);
            lista = await EnrichListAsync(lista);
            SetCachedList(kulcs, lista);
            return lista;
        }

        public static async Task<List<RecipeListItem>> ByCaloriesAsync(int min, int max, int darab = 12)
        {
            string kulcs = $"kcal_{min}_{max}_{darab}";
            if (TryGetCachedList(kulcs, out var cached)) return cached!;

            var osszes = new List<RecipeListItem>();
            var latva = new HashSet<string>();

            foreach (string url in CalorieSourceUrls(min, max))
            {
                if (osszes.Count >= darab * 4) break;

                try
                {
                    string html = await FetchPageAsync(url);
                    foreach (var elem in ParseListFromHtml(html, darab * 3))
                    {
                        if (!latva.Add(elem.Id)) continue;
                        // 0 kcal = ismeretlen a listán — később JSON-LD-ből pótoljuk.
                        if (elem.EstimatedCalories > 0 && (elem.EstimatedCalories < min || elem.EstimatedCalories > max))
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
            lista = await EnrichListAsync(lista);
            lista = lista
                .Where(r => r.EstimatedCalories >= min && r.EstimatedCalories <= max)
                .Take(darab)
                .ToList();
            SetCachedList(kulcs, lista);
            return lista;
        }

        private static IEnumerable<string> CalorieSourceUrls(int min, int max)
        {
            int kozep = (min + max) / 2;

            // Kalória szerinti rendezés — a cél-tartomány környéki oldalak.
            foreach (int oldal in CaloriePageCandidates(kozep))
            {
                yield return $"{BaseUrl}/kereses/recept?rendezes=kaloria-novekvo&page={oldal}";
            }

            // Főoldal + kategóriák — változatos receptek kalória adattal a kártyákon.
            for (int oldal = 1; oldal <= 3; oldal++)
                yield return oldal == 1 ? $"{BaseUrl}/receptek" : $"{BaseUrl}/receptek?page={oldal}";

            foreach (var kat in Categories)
            {
                yield return $"{BaseUrl}/receptek/kategoria/{kat.Id.Trim('/')}";
                yield return $"{BaseUrl}/receptek/kategoria/{kat.Id.Trim('/')}?page=2";
            }
        }

        private static IEnumerable<int> CaloriePageCandidates(int kozepKcal)
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

        public static async Task<RecipeDetail?> GetByIdAsync(string receptId)
        {
            string slug = ExtractSlug(receptId);
            if (string.IsNullOrWhiteSpace(slug)) return null;

            string kulcs = $"resz_{slug}";
            if (DetailCache.TryGetValue(kulcs, out var c) && DateTime.UtcNow - c.ido < CacheTtl)
                return c.recept;

            string html = await FetchPageAsync($"{BaseUrl}/recept/{slug}");
            var recept = ParseDetailsFromJsonLd(html, slug);
            DetailCache[kulcs] = (DateTime.UtcNow, recept);
            return recept;
        }

        public static LoggedFood ToLoggedFood(RecipeDetail recept, double adagSzam, string etkezesTipus)
        {
            return new LoggedFood
            {
                FoodId = $"recept_{recept.Id}",
                RecipeId = recept.Id,
                FoodName = recept.Name,
                FromRecipe = true,
                Servings = adagSzam,
                MealType = etkezesTipus,
                ImageUrl = recept.ImageUrl,
                CaloriesPer100g = recept.EstimatedCalories,
                ProteinPer100g = recept.EstimatedProtein,
                CarbsPer100g = recept.EstimatedCarbs,
                FatPer100g = recept.EstimatedFat,
            };
        }

        public static string ExtractSlug(string receptId)
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

        private static async Task<string> FetchPageAsync(string url)
        {
            var response = await Http.GetAsync(url);
            response.EnsureSuccessStatusCode();
            return await response.Content.ReadAsStringAsync();
        }

        private static async Task<List<RecipeListItem>> EnrichListAsync(IReadOnlyList<RecipeListItem> lista)
        {
            if (lista.Count == 0) return new List<RecipeListItem>();

            var sem = new SemaphoreSlim(5);
            var tasks = lista.Select(async elem =>
            {
                if (!NeedsNutrition(elem)) return elem;
                await sem.WaitAsync();
                try
                {
                    return await EnrichItemAsync(elem);
                }
                finally
                {
                    sem.Release();
                }
            });

            return (await Task.WhenAll(tasks)).ToList();
        }

        private static bool NeedsNutrition(RecipeListItem elem) =>
            elem.EstimatedCalories <= 0 ||
            string.IsNullOrWhiteSpace(elem.ImageUrl) ||
            (elem.EstimatedProtein <= 0 && elem.EstimatedCarbs <= 0 && elem.EstimatedFat <= 0);

        private static async Task<RecipeListItem> EnrichItemAsync(RecipeListItem elem)
        {
            var reszlet = await GetByIdAsync(elem.Id);
            if (reszlet == null) return elem;

            if (elem.EstimatedCalories <= 0) elem.EstimatedCalories = reszlet.EstimatedCalories;
            if (string.IsNullOrWhiteSpace(elem.ImageUrl)) elem.ImageUrl = reszlet.ImageUrl;
            if (elem.EstimatedProtein <= 0) elem.EstimatedProtein = reszlet.EstimatedProtein;
            if (elem.EstimatedCarbs <= 0) elem.EstimatedCarbs = reszlet.EstimatedCarbs;
            if (elem.EstimatedFat <= 0) elem.EstimatedFat = reszlet.EstimatedFat;
            if (elem.IngredientCount <= 0) elem.IngredientCount = reszlet.IngredientCount;
            if (elem.Tags.Count == 0 && reszlet.Tags.Count > 0) elem.Tags = reszlet.Tags;
            return elem;
        }

        private static List<RecipeListItem> ParseListFromHtml(string html, int max, bool csakKeresesiEredmeny = false)
        {
            string scope = SearchScope(html, csakKeresesiEredmeny);
            var lista = ParseCards(scope, max);
            if (lista.Count > 0) return lista;
            return ParseQuickLinks(scope, max);
        }

        private static string SearchScope(string html, bool csakKeresesiEredmeny)
        {
            if (!csakKeresesiEredmeny) return html;

            var scopeMatch = Regex.Match(html,
                @"id=""recipe-search-result""[\s\S]*?(?=id=""recipe-search-filter|<footer|</body>)",
                RegexOptions.IgnoreCase);
            return scopeMatch.Success ? scopeMatch.Value : html;
        }

        private static List<RecipeListItem> ParseCards(string html, int max)
        {
            var lista = new List<RecipeListItem>();
            var latva = new HashSet<string>();

            var articleRegex = new Regex(
                @"<article class=""m-articleCard[^""]*""[^>]*>(.*?)</article>",
                RegexOptions.Singleline | RegexOptions.IgnoreCase);

            foreach (Match article in articleRegex.Matches(html))
            {
                var elem = ParseCard(article.Groups[1].Value);
                if (elem == null || !latva.Add(elem.Id)) continue;
                lista.Add(elem);
                if (lista.Count >= max) break;
            }

            return lista;
        }

        private static async Task<List<RecipeListItem>> DirectSlugSearchAsync(string keresoszó)
        {
            var lista = new List<RecipeListItem>();
            foreach (string slug in SlugCandidates(keresoszó))
            {
                try
                {
                    var elem = await ItemFromSlugAsync(slug);
                    if (elem != null) lista.Add(elem);
                }
                catch
                {
                    // A slug nem létezik — következő jelölt.
                }
            }

            return lista;
        }

        private static IEnumerable<string> SlugCandidates(string keresoszó)
        {
            var latva = new HashSet<string>();
            string alap = SlugFromText(keresoszó);
            if (alap.Length >= 3 && latva.Add(alap)) yield return alap;

            foreach (string szo in NormalizedWords(keresoszó).Where(s => s.Length >= 4))
            {
                if (latva.Add(szo)) yield return szo;
            }
        }

        private static async Task<RecipeListItem?> ItemFromSlugAsync(string slug)
        {
            string html = await FetchPageAsync($"{BaseUrl}/recept/{slug}");
            if (!html.Contains("\"@type\": \"Recipe\"", StringComparison.Ordinal) &&
                !html.Contains("\"@type\":\"Recipe\"", StringComparison.Ordinal))
                return null;

            using var doc = JsonDocument.Parse(ExtractRecipeJsonLd(html));
            var root = doc.RootElement;
            string nev = JsonString(root, "name");
            if (string.IsNullOrWhiteSpace(nev)) return null;

            int adag = Math.Max(1, JsonInt(root, "recipeYield", 1));
            var (kcal, _, _, _) = NutritionPerServing(root, adag);

            return new RecipeListItem
            {
                Id = IdFromSlug(slug),
                Name = nev,
                ImageUrl = ImageFromJson(root),
                EstimatedCalories = kcal,
                Tags = kcal > 0 ? TagsFromCalories(kcal) : new List<string>(),
            };
        }

        private static bool MatchesQuery(string keresoszó, RecipeListItem elem)
        {
            var tokenek = NormalizedWords(keresoszó);
            if (tokenek.Count == 0) return true;

            string nev = Normalize(elem.Name);
            string slug = Normalize(ExtractSlug(elem.Id).Replace('-', ' '));
            return tokenek.All(t => nev.Contains(t) || slug.Contains(t));
        }

        private static bool HasNextSearchPage(string html, int oldal)
        {
            string kovetkezo = $"/kereses/recept?q=";
            return html.Contains($"{kovetkezo}", StringComparison.OrdinalIgnoreCase) &&
                   html.Contains($"page={oldal + 1}", StringComparison.OrdinalIgnoreCase);
        }

        private static string SlugFromText(string szoveg)
        {
            var sb = new System.Text.StringBuilder();
            bool elozoKotojel = false;
            foreach (char c in Normalize(szoveg))
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

        private static List<string> NormalizedWords(string szoveg) =>
            Normalize(szoveg)
                .Split(' ', StringSplitOptions.RemoveEmptyEntries | StringSplitOptions.TrimEntries)
                .Where(s => s.Length >= 3)
                .Distinct()
                .ToList();

        private static string Normalize(string szoveg)
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

        private static List<RecipeListItem> ParseQuickLinks(string html, int max)
        {
            var scopeMatch = Regex.Match(html,
                @"id=""recipe-search-result""[\s\S]*?(?=id=""recipe-search-filter|<footer|</body>)",
                RegexOptions.IgnoreCase);
            string scope = scopeMatch.Success ? scopeMatch.Value : html;

            var lista = new List<RecipeListItem>();
            var latva = new HashSet<string>();

            var linkRegex = new Regex(
                @"href=""(?:https://www\.nosalty\.hu)?/recept/([a-z0-9\-]+)""[^>]*>[\s\S]*?m-articleCard__headline[^>]*>([^<]+)</a>",
                RegexOptions.Singleline | RegexOptions.IgnoreCase);

            foreach (Match m in linkRegex.Matches(scope))
            {
                string slug = m.Groups[1].Value;
                string id = IdFromSlug(slug);
                if (!latva.Add(id)) continue;

                lista.Add(new RecipeListItem
                {
                    Id = id,
                    Name = HtmlDecode(m.Groups[2].Value.Trim()),
                    ImageUrl = ExtractImage(m.Value),
                    EstimatedCalories = ExtractKcal(m.Value),
                    Tags = TagsFromCalories(ExtractKcal(m.Value)),
                });
                if (lista.Count >= max) break;
            }

            return lista;
        }

        private static List<RecipeListItem> ParseSimilarRecipes(string html, int max, string kategoria)
        {
            var lista = new List<RecipeListItem>();
            var latva = new HashSet<string>();

            var linkRegex = new Regex(
                @"href=""(?:https://www\.nosalty\.hu)?/recept/([a-z0-9\-]+)""[^>]*>[\s\S]*?m-articleCard__headline[^>]*>\s*([^<]+)\s*</h2>",
                RegexOptions.Singleline | RegexOptions.IgnoreCase);

            foreach (Match m in linkRegex.Matches(html))
            {
                string slug = m.Groups[1].Value;
                string id = IdFromSlug(slug);
                if (!latva.Add(id)) continue;

                string img = ExtractImage(m.Value);
                lista.Add(new RecipeListItem
                {
                    Id = id,
                    Name = HtmlDecode(m.Groups[2].Value.Trim()),
                    ImageUrl = img,
                    Category = kategoria,
                });
                if (lista.Count >= max) break;
            }

            return lista;
        }

        private static RecipeListItem? ParseCard(string block)
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

            int kcal = ExtractKcal(block);

            return new RecipeListItem
            {
                Id = IdFromSlug(slug),
                Name = HtmlDecode(nevMatch.Groups[1].Value.Trim()),
                ImageUrl = ExtractImage(block),
                EstimatedCalories = kcal,
                Category = CategoryFromBlock(block),
                Tags = kcal > 0 ? TagsFromCalories(kcal) : new List<string>(),
            };
        }

        private static int ExtractKcal(string block)
        {
            var kcalMatch = Regex.Match(block, @"(\d+)\s*kcal", RegexOptions.IgnoreCase);
            return kcalMatch.Success ? int.Parse(kcalMatch.Groups[1].Value) : 0;
        }

        private static string ExtractImage(string block)
        {
            var imgMatch = Regex.Match(block,
                @"src=""(https://image-api\.nosalty\.hu/nosalty/images/recipes/[^""?]+(?:\?[^""]*)?)""",
                RegexOptions.IgnoreCase);
            if (imgMatch.Success)
                return NormalizeImageUrl(imgMatch.Groups[1].Value);

            var srcsetMatch = Regex.Match(block,
                @"data-srcset=""(https://image-api\.nosalty\.hu/nosalty/images/recipes/[^""\s]+)",
                RegexOptions.IgnoreCase);
            if (srcsetMatch.Success)
                return NormalizeImageUrl(srcsetMatch.Groups[1].Value);

            var lazyMatch = Regex.Match(block,
                @"data-src=""(https://image-api\.nosalty\.hu/nosalty/images/recipes/[^""?]+(?:\?[^""]*)?)""",
                RegexOptions.IgnoreCase);
            return lazyMatch.Success ? NormalizeImageUrl(lazyMatch.Groups[1].Value) : "";
        }

        private static string NormalizeImageUrl(string url) =>
            url.Replace("&amp;", "&");

        private static RecipeDetail? ParseDetailsFromJsonLd(string html, string slug)
        {
            using var doc = JsonDocument.Parse(ExtractRecipeJsonLd(html));
            var root = doc.RootElement;

            string nev = JsonString(root, "name");
            if (string.IsNullOrWhiteSpace(nev)) return null;

            int adag = JsonInt(root, "recipeYield", 1);
            if (adag <= 0) adag = 1;

            var (kcal, protein, carbs, fat) = NutritionPerServing(root, adag);
            var osszetevok = IngredientsFromJson(root);
            string utasitas = InstructionsFromJson(root);
            string kep = ImageFromJson(root);
            string kategoria = JsonString(root, "recipeCategory");
            string konyha = JsonString(root, "recipeCuisine");
            var cimkek = TagsFromJson(root, kcal, protein);

            bool gyors = DurationMinutes(root, "totalTime") <= 30
                         || DurationMinutes(root, "prepTime") + DurationMinutes(root, "cookTime") <= 30;

            return new RecipeDetail
            {
                Id = IdFromSlug(slug),
                Name = nev,
                ImageUrl = kep,
                Category = string.IsNullOrWhiteSpace(kategoria) ? konyha : kategoria,
                Origin = konyha,
                EstimatedCalories = kcal,
                EstimatedProtein = protein,
                EstimatedCarbs = carbs,
                EstimatedFat = fat,
                IngredientCount = osszetevok.Count,
                QuickToMake = gyors,
                Description = utasitas,
                Ingredients = osszetevok,
                Tags = cimkek,
            };
        }

        private static string ExtractRecipeJsonLd(string html)
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

        private static (int kcal, double protein, double carbs, double fat) NutritionPerServing(JsonElement root, int adag)
        {
            if (!root.TryGetProperty("nutrition", out var nutr))
                return (0, 0, 0, 0);

            double protein = NutrientValue(nutr, "proteinContent") / adag;
            double carbs = NutrientValue(nutr, "carbohydrateContent") / adag;
            double fat = NutrientValue(nutr, "fatContent") / adag;
            double kcalDouble = NutrientValue(nutr, "calories") / adag;

            int kcal = (int)Math.Round(kcalDouble);
            if (kcal <= 0 && protein + carbs + fat > 0)
                kcal = (int)Math.Round(protein * 4 + carbs * 4 + fat * 9);

            return (kcal, Math.Round(protein, 1), Math.Round(carbs, 1), Math.Round(fat, 1));
        }

        private static double NutrientValue(JsonElement nutr, string mezo)
        {
            if (!nutr.TryGetProperty(mezo, out var elem)) return 0;
            string szoveg = elem.ValueKind == JsonValueKind.String ? elem.GetString() ?? "" : elem.GetRawText();
            var match = Regex.Match(szoveg.Replace(',', '.'), @"([\d.]+)");
            return match.Success && double.TryParse(match.Groups[1].Value, NumberStyles.Any, CultureInfo.InvariantCulture, out var v)
                ? v : 0;
        }

        private static List<RecipeIngredient> IngredientsFromJson(JsonElement root)
        {
            var ingredients = new List<RecipeIngredient>();
            if (!root.TryGetProperty("recipeIngredient", out var arr) || arr.ValueKind != JsonValueKind.Array)
                return ingredients;

            foreach (var item in arr.EnumerateArray())
            {
                string sor = item.GetString()?.Trim() ?? "";
                if (string.IsNullOrWhiteSpace(sor)) continue;

                var parts = sor.Split(' ', 2, StringSplitOptions.RemoveEmptyEntries);
                if (parts.Length == 2 && Regex.IsMatch(parts[0], @"^[\d,/\.]+"))
                    ingredients.Add(new RecipeIngredient { Amount = parts[0], Name = parts[1] });
                else
                    ingredients.Add(new RecipeIngredient { Name = sor });
            }

            return ingredients;
        }

        private static string InstructionsFromJson(JsonElement root)
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

        private static string ImageFromJson(JsonElement root)
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

        private static List<string> TagsFromJson(JsonElement root, int kcal, double protein)
        {
            var tags = new List<string>();
            if (protein >= 25) tags.Add("Magas fehérje");
            if (kcal > 0 && kcal < 300) tags.Add("Alacsony kalória");

            string keywords = JsonString(root, "keywords");
            foreach (var tag in keywords.Split(',', StringSplitOptions.RemoveEmptyEntries | StringSplitOptions.TrimEntries))
            {
                if (!string.IsNullOrWhiteSpace(tag) && tags.Count < 6)
                    tags.Add(tag);
            }

            return tags;
        }

        private static List<string> TagsFromCalories(int kcal)
        {
            var tags = new List<string>();
            if (kcal < 300) tags.Add("Alacsony kalória");
            if (kcal >= 450) tags.Add("Kiadós");
            return tags;
        }

        private static string CategoryFromBlock(string block)
        {
            var match = Regex.Match(block,
                @"-articleCategory[^>]*>([^<]+)</span>",
                RegexOptions.IgnoreCase);
            if (!match.Success) return "";
            string szoveg = match.Groups[1].Value.Trim();
            return szoveg.EndsWith("kcal", StringComparison.OrdinalIgnoreCase) ? "" : szoveg;
        }

        private static string CategoryName(string ut) =>
            Categories.FirstOrDefault(k => k.Id.Equals(ut, StringComparison.OrdinalIgnoreCase))?.Name ?? ut;

        private static int DurationMinutes(JsonElement root, string mezo)
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

        private static bool TryGetCachedList(string kulcs, out List<RecipeListItem>? lista)
        {
            if (ListCache.TryGetValue(kulcs, out var c) && DateTime.UtcNow - c.ido < CacheTtl)
            {
                lista = c.lista;
                return true;
            }
            lista = null;
            return false;
        }

        private static void SetCachedList(string kulcs, List<RecipeListItem> lista)
        {
            if (lista.Count > 0)
                ListCache[kulcs] = (DateTime.UtcNow, lista);
        }
    }
}
