using Microsoft.AspNetCore.Mvc;
using FitnessBackend.Models;

namespace FitnessBackend.Controllers
{
    [ApiController]
    [Route("api/[controller]")]
    public class CommunityController : ControllerBase
    {
        private readonly IWebHostEnvironment _kornyezet;

        public CommunityController(IWebHostEnvironment kornyezet)
        {
            _kornyezet = kornyezet;
        }

        // 0. SZELFI FELTÖLTÉS — a telefon elküldi a képet, visszakapod az URL-t
        [HttpPost("szelfi-feltoltes")]
        [RequestSizeLimit(5 * 1024 * 1024)]
        public async Task<ActionResult<object>> SzelfiFeltoltes(IFormFile kep, [FromQuery] string userName)
        {
            if (kep == null || kep.Length == 0)
            {
                return BadRequest("Kep fajl kotelezo.");
            }

            if (string.IsNullOrWhiteSpace(userName))
            {
                return BadRequest("userName query parameter kotelezo.");
            }

            var engedelyezett = new HashSet<string>(StringComparer.OrdinalIgnoreCase)
            {
                ".jpg", ".jpeg", ".png", ".webp"
            };

            var kiterjesztes = Path.GetExtension(kep.FileName);
            if (!engedelyezett.Contains(kiterjesztes))
            {
                return BadRequest("Csak jpg, jpeg, png vagy webp formatum engedelyezett.");
            }

            var mappa = Path.Combine(_kornyezet.WebRootPath ?? "", "uploads", "selfies");
            Directory.CreateDirectory(mappa);

            var biztonsagos_nev = $"{SanitizeFileName(userName)}_{Guid.NewGuid():N}{kiterjesztes.ToLowerInvariant()}";
            var teljes_utvonal = Path.Combine(mappa, biztonsagos_nev);

            await using (var stream = new FileStream(teljes_utvonal, FileMode.Create))
            {
                await kep.CopyToAsync(stream);
            }

            return Ok(new
            {
                selfieUrl = $"/uploads/selfies/{biztonsagos_nev}",
                uzenet = "Szelfi feltoltve. Ezt az URL-t add meg a megosztasnal."
            });
        }

        // 1. MEGYÉK LISTÁJA
        [HttpGet("megyek")]
        public List<MegyeInfo> MegyekListaja()
        {
            return CommunityTarolo.MagyarMegyek;
        }

        // 2. RÉGIÓK LISTÁJA
        [HttpGet("regiok")]
        public List<string> RegiokListaja()
        {
            return CommunityTarolo.MagyarMegyek.Select(m => m.Regio).Distinct().OrderBy(r => r).ToList();
        }

        // 3. TELJES FEED — mindig friss elöl (legújabb posztok)
        [HttpGet("feed")]
        public List<CommunityPost> TeljesFeed()
        {
            return FeedRendezese(CommunityTarolo.Posztok);
        }

        // 4. FEED MEGYE SZERINT — pl. "Mit edzettek ma Jász-Nagykun-Szolnokban?"
        [HttpGet("feed/megye/{megye_id}")]
        public ActionResult<List<CommunityPost>> FeedMegyeSzerint(string megye_id)
        {
            var megye = MegyeKeresese(megye_id);
            if (megye == null)
            {
                return NotFound("Ismeretlen megye.");
            }

            var szurt = CommunityTarolo.Posztok
                .Where(p => p.Megye.Equals(megye.Nev, StringComparison.OrdinalIgnoreCase)
                    || p.Megye.Equals(megye.Id, StringComparison.OrdinalIgnoreCase))
                .ToList();

            return Ok(FeedRendezese(szurt));
        }

        // 5. FEED RÉGIÓ SZERINT — pl. Észak-Alföld
        [HttpGet("feed/regio/{regio_nev}")]
        public ActionResult<List<CommunityPost>> FeedRegioSzerint(string regio_nev)
        {
            var szurt = CommunityTarolo.Posztok
                .Where(p => p.Regio.Equals(regio_nev, StringComparison.OrdinalIgnoreCase))
                .ToList();

            return Ok(FeedRendezese(szurt));
        }

        // 6. MEGOSZTÁS — edzés + szelfi + megye (Hevy Finish után)
        [HttpPost("megosztas")]
        public ActionResult<CommunityPost> EdzesMegosztasa([FromBody] MegosztasKeres keres)
        {
            var (poszt, hiba) = CommunityTarolo.UjPosztLetrehozasa(keres);

            if (hiba != null)
            {
                return BadRequest(hiba);
            }

            return Ok(poszt);
        }

        // 7. EGY POSZT RÉSZLETEI
        [HttpGet("{post_id}")]
        public ActionResult<CommunityPost> PosztReszletei(string post_id)
        {
            var poszt = PosztKeresese(post_id);
            if (poszt == null)
            {
                return NotFound("Nincs ilyen poszt.");
            }

            return Ok(poszt);
        }

        // 8. LIKE
        [HttpPost("{post_id}/like")]
        public ActionResult<CommunityPost> PosztLike([FromBody] LikeKeres keres, string post_id)
        {
            var poszt = PosztKeresese(post_id);
            if (poszt == null)
            {
                return NotFound("Nincs ilyen poszt.");
            }

            if (string.IsNullOrWhiteSpace(keres.UserName))
            {
                return BadRequest("UserName kotelezo.");
            }

            if (!poszt.Likeolok.Contains(keres.UserName))
            {
                poszt.Likeolok.Add(keres.UserName);
                poszt.LikeSzam = poszt.Likeolok.Count;
            }

            return Ok(poszt);
        }

        // 9. LIKE VISSZAVONÁSA
        [HttpDelete("{post_id}/like")]
        public ActionResult<CommunityPost> PosztUnlike([FromQuery] string userName, string post_id)
        {
            var poszt = PosztKeresese(post_id);
            if (poszt == null)
            {
                return NotFound("Nincs ilyen poszt.");
            }

            poszt.Likeolok.Remove(userName);
            poszt.LikeSzam = poszt.Likeolok.Count;
            return Ok(poszt);
        }

        // 10. KOMMENT ÍRÁSA
        [HttpPost("{post_id}/komment")]
        public ActionResult<CommunityComment> KommentIrasa(string post_id, [FromBody] KommentKeres keres)
        {
            var poszt = PosztKeresese(post_id);
            if (poszt == null)
            {
                return NotFound("Nincs ilyen poszt.");
            }

            if (string.IsNullOrWhiteSpace(keres.UserName) || string.IsNullOrWhiteSpace(keres.Szoveg))
            {
                return BadRequest("UserName es Szoveg kotelezo.");
            }

            var uj_komment = new CommunityComment
            {
                Id = $"komment_{Guid.NewGuid().ToString("N")[..8]}",
                UserName = keres.UserName,
                Szoveg = keres.Szoveg,
                Idobelyeg = DateTime.Now
            };

            poszt.Kommentek.Add(uj_komment);
            return Ok(uj_komment);
        }

        // 11. KOMMENTEK LISTÁJA
        [HttpGet("{post_id}/kommentek")]
        public ActionResult<List<CommunityComment>> KommentekListaja(string post_id)
        {
            var poszt = PosztKeresese(post_id);
            if (poszt == null)
            {
                return NotFound("Nincs ilyen poszt.");
            }

            return Ok(poszt.Kommentek.OrderByDescending(k => k.Idobelyeg).ToList());
        }

        // 12. MENTÉS RUTINKÉNT — haver edzéstervét lemented
        [HttpPost("{post_id}/mentes-rutinkent")]
        public ActionResult<Routine> MentésRutinkent(string post_id, [FromQuery] string userName)
        {
            var poszt = PosztKeresese(post_id);
            if (poszt == null)
            {
                return NotFound("Nincs ilyen poszt.");
            }

            if (poszt.Edzes.Exercises.Count == 0)
            {
                return BadRequest("A poszton nincs gyakorlat, rutin nem mentheto.");
            }

            var uj_rutin = Routine.LetrehozasKozossegPosztbol(poszt, userName);
            EdzesTervTarolo.MentettRutinok.Add(uj_rutin);
            return Ok(uj_rutin);
        }

        // 13. FELHASZNÁLÓ KERESÉS
        [HttpGet("felhasznalok")]
        public ActionResult<List<object>> FelhasznalokKeresese([FromQuery] string? kereses = null)
        {
            var osszes = CommunityTarolo.Posztok
                .GroupBy(p => p.UserName)
                .Select(g => new
                {
                    userName = g.Key,
                    posztSzam = g.Count(),
                    osszLike = g.Sum(p => p.LikeSzam),
                    utolsoEdzes = g.Max(p => p.Megosztva),
                    legutobbiEdzesCim = g.OrderByDescending(p => p.Megosztva).First().Edzes.Title
                })
                .OrderByDescending(u => u.posztSzam);

            if (!string.IsNullOrWhiteSpace(kereses))
            {
                var szurt = osszes
                    .Where(u => u.userName.Contains(kereses, StringComparison.OrdinalIgnoreCase))
                    .ToList<object>();
                return Ok(szurt);
            }

            return Ok(osszes.ToList<object>());
        }

        // 14. FELHASZNÁLÓ POSZTJAI
        [HttpGet("felhasznalo/{userName}")]
        public ActionResult<List<CommunityPost>> FelhasznaloPosztjai(string userName)
        {
            var posztok = CommunityTarolo.Posztok
                .Where(p => p.UserName.Equals(userName, StringComparison.OrdinalIgnoreCase))
                .OrderByDescending(p => p.Megosztva)
                .ToList();
            return Ok(posztok);
        }

        // 15. KÖVETÉS
        [HttpPost("kovet/{kovetett}")]
        public ActionResult KovetesFelvetel(string kovetett, [FromQuery] string koveto)
        {
            if (string.IsNullOrWhiteSpace(koveto)) return BadRequest("koveto query param kotelezo.");
            if (!CommunityTarolo.KoveteEllenorzes(koveto, kovetett))
            {
                CommunityTarolo.Kovetek.Add(new KovetesInfo { Koveto = koveto, Kovetett = kovetett, Ota = DateTime.Now });
            }
            return Ok(new { koveto, kovetett, kovet = true });
        }

        // 16. KÖVETÉS VISSZAVONÁSA
        [HttpDelete("kovet/{kovetett}")]
        public ActionResult KovetesVisszavonasa(string kovetett, [FromQuery] string koveto)
        {
            var elem = CommunityTarolo.Kovetek
                .FirstOrDefault(k => k.Koveto == koveto && k.Kovetett == kovetett);
            if (elem != null) CommunityTarolo.Kovetek.Remove(elem);
            return Ok(new { koveto, kovetett, kovet = false });
        }

        // 17. KÖVETÉSEK LEKÉRDEZÉSE
        [HttpGet("kovetesek")]
        public ActionResult<object> KovetesekLekerdezese([FromQuery] string userName)
        {
            var kovetett = CommunityTarolo.Kovetek
                .Where(k => k.Koveto == userName)
                .Select(k => k.Kovetett)
                .ToList();
            var koveto = CommunityTarolo.Kovetek
                .Where(k => k.Kovetett == userName)
                .Select(k => k.Koveto)
                .ToList();
            return Ok(new { kovetett, koveto, kovetettSzam = kovetett.Count, kovetoSzam = koveto.Count });
        }

        // --- Segédfüggvények ---

        private static string SanitizeFileName(string nev)
        {
            var karakterek = nev
                .Where(c => char.IsLetterOrDigit(c) || c == '-' || c == '_')
                .ToArray();

            var tisztitott = new string(karakterek);
            return string.IsNullOrWhiteSpace(tisztitott) ? "user" : tisztitott.ToLowerInvariant();
        }

        private static List<CommunityPost> FeedRendezese(List<CommunityPost> posztok)
        {
            return posztok.OrderByDescending(p => p.Megosztva).ToList();
        }

        private static CommunityPost? PosztKeresese(string post_id)
        {
            return CommunityTarolo.Posztok
                .FirstOrDefault(p => p.Id.Equals(post_id, StringComparison.OrdinalIgnoreCase));
        }

        private static MegyeInfo? MegyeKeresese(string megye_azonosito)
        {
            return CommunityTarolo.MagyarMegyek.FirstOrDefault(m =>
                m.Id.Equals(megye_azonosito, StringComparison.OrdinalIgnoreCase) ||
                m.Nev.Equals(megye_azonosito, StringComparison.OrdinalIgnoreCase));
        }
    }
}
