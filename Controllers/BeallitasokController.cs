using Microsoft.AspNetCore.Mvc;
using FitnessBackend.Models;

namespace FitnessBackend.Controllers
{
    [ApiController]
    [Route("api/[controller]")]
    public class BeallitasokController : ControllerBase
    {
        private readonly IWebHostEnvironment _kornyezet;

        public BeallitasokController(IWebHostEnvironment kornyezet)
        {
            _kornyezet = kornyezet;
        }

        // --- REGISZTRÁCIÓ / BELÉPÉS ALAP ---

        [HttpPost("regisztracio")]
        public ActionResult<UserBeallitasok> Regisztracio([FromBody] RegisztracioKeres keres)
        {
            var (user, hiba) = FelhasznaloTarolo.Regisztracio(keres);
            if (hiba != null)
            {
                return BadRequest(hiba);
            }

            return Ok(user);
        }

        // --- MENÜ (frontend Settings lista — Hevy szerinti struktúra) ---

        [HttpGet("menu/{userName}")]
        public ActionResult<List<BeallitasMenuSzekcio>> BeallitasMenu(string userName)
        {
            if (string.IsNullOrWhiteSpace(userName))
            {
                return BadRequest("userName kotelezo.");
            }

            return Ok(FelhasznaloTarolo.MenuStruktura(userName));
        }

        // --- TELJES BEÁLLÍTÁS LEKÉRÉS / MENTÉS ---

        [HttpGet("{userName}")]
        public ActionResult<UserBeallitasok> OsszesBeallitas(string userName)
        {
            return Ok(FelhasznaloTarolo.FelhasznaloLekerdezeseVagyLetrehozasa(userName));
        }

        [HttpPut("{userName}")]
        public ActionResult<UserBeallitasok> OsszesBeallitasMentese(
            string userName, [FromBody] UserBeallitasok beallitasok)
        {
            var user = FelhasznaloTarolo.FelhasznaloLekerdezeseVagyLetrehozasa(userName);
            beallitasok.UserName = user.UserName;
            beallitasok.Fiok = user.Fiok;
            beallitasok.Tagsag = user.Tagsag;
            beallitasok.Letrehozva = user.Letrehozva;
            FelhasznaloTarolo.FelhasznaloMentese(beallitasok);
            return Ok(beallitasok);
        }

        // --- PROFIL ---

        [HttpGet("{userName}/profil")]
        public ActionResult<ProfilBeallitas> ProfilLekerdezes(string userName)
        {
            var user = FelhasznaloTarolo.FelhasznaloLekerdezeseVagyLetrehozasa(userName);
            return Ok(user.Profil);
        }

        [HttpPut("{userName}/profil")]
        public ActionResult<ProfilBeallitas> ProfilMentes(string userName, [FromBody] ProfilBeallitas profil)
        {
            var user = FelhasznaloTarolo.FelhasznaloLekerdezeseVagyLetrehozasa(userName);
            user.Profil = profil;
            FelhasznaloTarolo.FelhasznaloMentese(user);
            return Ok(user.Profil);
        }

        [HttpPost("{userName}/profil/kep-feltoltes")]
        [RequestSizeLimit(5 * 1024 * 1024)]
        public async Task<ActionResult<object>> ProfilKepFeltoltes(string userName, IFormFile kep)
        {
            if (kep == null || kep.Length == 0)
            {
                return BadRequest("Kep fajl kotelezo.");
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

            var mappa = Path.Combine(_kornyezet.WebRootPath, "uploads", "profiles");
            Directory.CreateDirectory(mappa);

            var biztonsagos_nev = $"{SanitizeFileName(userName)}_{Guid.NewGuid():N}{kiterjesztes.ToLowerInvariant()}";
            var teljes_utvonal = Path.Combine(mappa, biztonsagos_nev);

            await using (var stream = new FileStream(teljes_utvonal, FileMode.Create))
            {
                await kep.CopyToAsync(stream);
            }

            var user = FelhasznaloTarolo.FelhasznaloLekerdezeseVagyLetrehozasa(userName);
            user.Profil.KepUrl = $"/uploads/profiles/{biztonsagos_nev}";
            FelhasznaloTarolo.FelhasznaloMentese(user);

            return Ok(new
            {
                kepUrl = user.Profil.KepUrl,
                profil = user.Profil
            });
        }

        // --- FIÓK ---

        [HttpGet("{userName}/fiok")]
        public ActionResult<object> FiokLekerdezes(string userName)
        {
            var user = FelhasznaloTarolo.FelhasznaloLekerdezeseVagyLetrehozasa(userName);
            return Ok(new
            {
                userName = user.UserName,
                email = user.Fiok.Email,
                regisztralt = !string.IsNullOrEmpty(user.Fiok.JelszoHash)
            });
        }

        [HttpPut("{userName}/fiok/felhasznalonev")]
        public ActionResult<object> FelhasznalonevModositas(
            string userName, [FromBody] FelhasznalonevModositasKeres keres)
        {
            if (string.IsNullOrWhiteSpace(keres.UjUserName))
            {
                return BadRequest("UjUserName kotelezo.");
            }

            if (FelhasznaloTarolo.FelhasznaloLetezik(keres.UjUserName))
            {
                return BadRequest("Ez a felhasznalonev mar foglalt.");
            }

            var (siker, hiba) = FelhasznaloTarolo.FelhasznalonevAtnevezese(userName, keres.UjUserName);
            if (!siker)
            {
                return BadRequest(hiba);
            }

            return Ok(new
            {
                uzenet = "Felhasznalonev modositva.",
                regiUserName = userName,
                ujUserName = keres.UjUserName.Trim()
            });
        }

        [HttpPut("{userName}/fiok/email")]
        public ActionResult<object> EmailModositas(string userName, [FromBody] EmailModositasKeres keres)
        {
            if (string.IsNullOrWhiteSpace(keres.UjEmail))
            {
                return BadRequest("UjEmail kotelezo.");
            }

            var (siker, hiba) = FelhasznaloTarolo.JelszoEllenorzes(userName, keres.Jelszo);
            if (!siker)
            {
                return BadRequest(hiba);
            }

            var user = FelhasznaloTarolo.FelhasznaloLekerdezeseVagyLetrehozasa(userName);
            user.Fiok.Email = keres.UjEmail.Trim();
            FelhasznaloTarolo.FelhasznaloMentese(user);

            return Ok(new { uzenet = "Email modositva.", email = user.Fiok.Email });
        }

        [HttpPut("{userName}/fiok/jelszo")]
        public ActionResult<object> JelszoModositas(string userName, [FromBody] JelszoModositasKeres keres)
        {
            if (string.IsNullOrWhiteSpace(keres.UjJelszo) || keres.UjJelszo.Length < 6)
            {
                return BadRequest("Uj jelszo minimum 6 karakter.");
            }

            var (siker, hiba) = FelhasznaloTarolo.JelszoEllenorzes(userName, keres.RegiJelszo);
            if (!siker)
            {
                return BadRequest(hiba);
            }

            var user = FelhasznaloTarolo.FelhasznaloLekerdezeseVagyLetrehozasa(userName);
            user.Fiok.JelszoHash = FelhasznaloTarolo.JelszoHash(keres.UjJelszo);
            FelhasznaloTarolo.FelhasznaloMentese(user);

            return Ok(new { uzenet = "Jelszo modositva." });
        }

        // --- TAGSÁG ---

        [HttpGet("{userName}/tagsag")]
        public ActionResult<TagsagBeallitas> TagsagLekerdezes(string userName)
        {
            var user = FelhasznaloTarolo.FelhasznaloLekerdezeseVagyLetrehozasa(userName);
            return Ok(user.Tagsag);
        }

        [HttpPut("{userName}/tagsag")]
        public ActionResult<TagsagBeallitas> TagsagMentes(string userName, [FromBody] TagsagBeallitas tagsag)
        {
            var user = FelhasznaloTarolo.FelhasznaloLekerdezeseVagyLetrehozasa(userName);
            user.Tagsag = tagsag;
            FelhasznaloTarolo.FelhasznaloMentese(user);
            return Ok(user.Tagsag);
        }

        // --- ÉRTESÍTÉSEK ---

        [HttpGet("{userName}/ertesitesek")]
        public ActionResult<ErtesitesBeallitas> ErtesitesekLekerdezes(string userName)
        {
            var user = FelhasznaloTarolo.FelhasznaloLekerdezeseVagyLetrehozasa(userName);
            return Ok(user.Ertesitesek);
        }

        [HttpPut("{userName}/ertesitesek")]
        public ActionResult<ErtesitesBeallitas> ErtesitesekMentes(
            string userName, [FromBody] ErtesitesBeallitas ertesitesek)
        {
            var user = FelhasznaloTarolo.FelhasznaloLekerdezeseVagyLetrehozasa(userName);
            user.Ertesitesek = ertesitesek;
            FelhasznaloTarolo.FelhasznaloMentese(user);
            return Ok(user.Ertesitesek);
        }

        // --- EDZÉS BEÁLLÍTÁSOK ---

        [HttpGet("{userName}/edzes")]
        public ActionResult<EdzesBeallitas> EdzesBeallitasokLekerdezes(string userName)
        {
            var user = FelhasznaloTarolo.FelhasznaloLekerdezeseVagyLetrehozasa(userName);
            return Ok(user.Edzes);
        }

        [HttpPut("{userName}/edzes")]
        public ActionResult<EdzesBeallitas> EdzesBeallitasokMentes(
            string userName, [FromBody] EdzesBeallitas edzes)
        {
            if (edzes.PihenoIdozitoMasodperc < 10 || edzes.PihenoIdozitoMasodperc > 600)
            {
                return BadRequest("Piheno idozito 10-600 masodperc kozott lehet.");
            }

            if (!ErvényesHetNap(edzes.HetElsoNapja))
            {
                return BadRequest("HetElsoNapja: hetfo vagy vasarnap.");
            }

            var user = FelhasznaloTarolo.FelhasznaloLekerdezeseVagyLetrehozasa(userName);
            user.Edzes = edzes;
            FelhasznaloTarolo.FelhasznaloMentese(user);
            return Ok(user.Edzes);
        }

        // --- PRIVÁT & KÖZÖSSÉGI ---

        [HttpGet("{userName}/privat-szocial")]
        public ActionResult<PrivatSzocialBeallitas> PrivatSzocialLekerdezes(string userName)
        {
            var user = FelhasznaloTarolo.FelhasznaloLekerdezeseVagyLetrehozasa(userName);
            return Ok(user.PrivatSzocial);
        }

        [HttpPut("{userName}/privat-szocial")]
        public ActionResult<PrivatSzocialBeallitas> PrivatSzocialMentes(
            string userName, [FromBody] PrivatSzocialBeallitas beallitas)
        {
            if (!ErvényesLathatosag(beallitas.ProfilLathatosag))
            {
                return BadRequest("ProfilLathatosag: mindenki, kovetok, kozosseg, privat.");
            }

            var user = FelhasznaloTarolo.FelhasznaloLekerdezeseVagyLetrehozasa(userName);
            user.PrivatSzocial = beallitas;
            FelhasznaloTarolo.FelhasznaloMentese(user);
            return Ok(user.PrivatSzocial);
        }

        // --- MÉRTÉKEGYSÉGEK ---

        [HttpGet("{userName}/egyseg")]
        public ActionResult<EgysegBeallitas> EgysegLekerdezes(string userName)
        {
            var user = FelhasznaloTarolo.FelhasznaloLekerdezeseVagyLetrehozasa(userName);
            return Ok(user.Egyseg);
        }

        [HttpPut("{userName}/egyseg")]
        public ActionResult<EgysegBeallitas> EgysegMentes(string userName, [FromBody] EgysegBeallitas egyseg)
        {
            if (!ErvényesSulyEgyseg(egyseg.Suly) || !ErvényesTavolsagEgyseg(egyseg.Tavolsag) || !ErvényesHosszEgyseg(egyseg.Hossz))
            {
                return BadRequest("Ervenytelen mertekegyseg. Hasznald: GET /api/beallitasok/seged/egysegek");
            }

            var user = FelhasznaloTarolo.FelhasznaloLekerdezeseVagyLetrehozasa(userName);
            user.Egyseg = egyseg;
            FelhasznaloTarolo.FelhasznaloMentese(user);
            return Ok(user.Egyseg);
        }

        // --- NYELV ---

        [HttpGet("{userName}/nyelv")]
        public ActionResult<object> NyelvLekerdezes(string userName)
        {
            var user = FelhasznaloTarolo.FelhasznaloLekerdezeseVagyLetrehozasa(userName);
            return Ok(new { nyelv = user.Nyelv });
        }

        [HttpPut("{userName}/nyelv")]
        public ActionResult<object> NyelvMentes(string userName, [FromBody] Dictionary<string, string> keres)
        {
            if (!keres.TryGetValue("nyelv", out var nyelv) || string.IsNullOrWhiteSpace(nyelv))
            {
                return BadRequest("nyelv mezo kotelezo.");
            }

            if (!ErvényesNyelv(nyelv))
            {
                return BadRequest("Ervenytelen nyelv. Hasznald: GET /api/beallitasok/seged/nyelvek");
            }

            var user = FelhasznaloTarolo.FelhasznaloLekerdezeseVagyLetrehozasa(userName);
            user.Nyelv = nyelv.ToLowerInvariant();
            FelhasznaloTarolo.FelhasznaloMentese(user);
            return Ok(new { nyelv = user.Nyelv });
        }

        // --- TÉMA ---

        [HttpGet("{userName}/tema")]
        public ActionResult<TemaBeallitas> TemaLekerdezes(string userName)
        {
            var user = FelhasznaloTarolo.FelhasznaloLekerdezeseVagyLetrehozasa(userName);
            return Ok(user.Tema);
        }

        [HttpPut("{userName}/tema")]
        public ActionResult<TemaBeallitas> TemaMentes(string userName, [FromBody] TemaBeallitas tema)
        {
            if (!ErvényesTema(tema.Mod))
            {
                return BadRequest("Tema mod: vilagos, sotet, rendszer.");
            }

            var user = FelhasznaloTarolo.FelhasznaloLekerdezeseVagyLetrehozasa(userName);
            user.Tema = tema;
            FelhasznaloTarolo.FelhasznaloMentese(user);
            return Ok(user.Tema);
        }

        // --- INTEGRÁCIÓK ---

        [HttpGet("{userName}/integraciok")]
        public ActionResult<IntegracioBeallitas> IntegraciokLekerdezes(string userName)
        {
            var user = FelhasznaloTarolo.FelhasznaloLekerdezeseVagyLetrehozasa(userName);
            return Ok(user.Integraciok);
        }

        [HttpPut("{userName}/integraciok")]
        public ActionResult<IntegracioBeallitas> IntegraciokMentes(
            string userName, [FromBody] IntegracioBeallitas integraciok)
        {
            var user = FelhasznaloTarolo.FelhasznaloLekerdezeseVagyLetrehozasa(userName);
            user.Integraciok = integraciok;
            FelhasznaloTarolo.FelhasznaloMentese(user);
            return Ok(user.Integraciok);
        }

        // --- EXPORT / IMPORT ---

        [HttpGet("{userName}/export")]
        public ActionResult<FelhasznaloExportCsomag> AdatExport(string userName)
        {
            return Ok(FelhasznaloTarolo.ExportOsszeallitasa(userName));
        }

        [HttpPost("{userName}/import")]
        public ActionResult<object> AdatImport(string userName, [FromBody] FelhasznaloExportCsomag csomag)
        {
            csomag.UserName = userName;
            var (siker, hiba) = FelhasznaloTarolo.ImportVisszatoltes(csomag);
            if (!siker)
            {
                return BadRequest(hiba);
            }

            return Ok(new { uzenet = "Import sikeres.", userName });
        }

        // --- SEGÉD LISTÁK (frontend választókhoz) ---

        [HttpGet("seged/nyelvek")]
        public List<ValasztasiOpcio> NyelvekListaja() => new()
        {
            new() { Id = "hu", Cimke = "Magyar" },
            new() { Id = "en", Cimke = "English" },
            new() { Id = "de", Cimke = "Deutsch" }
        };

        [HttpGet("seged/egysegek")]
        public object EgysegekListaja() => new
        {
            suly = new[] { new ValasztasiOpcio { Id = "kg", Cimke = "Kilogramm (kg)" }, new ValasztasiOpcio { Id = "lbs", Cimke = "Font (lbs)" } },
            tavolsag = new[] { new ValasztasiOpcio { Id = "km", Cimke = "Kilometer (km)" }, new ValasztasiOpcio { Id = "mile", Cimke = "Mérföld (mile)" } },
            hossz = new[] { new ValasztasiOpcio { Id = "cm", Cimke = "Centimeter (cm)" }, new ValasztasiOpcio { Id = "inch", Cimke = "Hüvelyk (inch)" } }
        };

        [HttpGet("seged/temak")]
        public List<ValasztasiOpcio> TemakListaja() => new()
        {
            new() { Id = "vilagos", Cimke = "Vilagos" },
            new() { Id = "sotet", Cimke = "Sotet" },
            new() { Id = "rendszer", Cimke = "Rendszer alapjan" }
        };

        [HttpGet("seged/het-napjai")]
        public List<ValasztasiOpcio> HetNapjaiListaja() => new()
        {
            new() { Id = "hetfo", Cimke = "Hetfo" },
            new() { Id = "vasarnap", Cimke = "Vasarnap" }
        };

        [HttpGet("seged/lathatosag")]
        public List<ValasztasiOpcio> LathatosagListaja() => new()
        {
            new() { Id = "mindenki", Cimke = "Mindenki" },
            new() { Id = "kovetok", Cimke = "Csak kovetok" },
            new() { Id = "kozosseg", Cimke = "Kozosseg (megye alapu)" },
            new() { Id = "privat", Cimke = "Privat" }
        };

        // --- ÚTMUTATÓK ---

        [HttpGet("utmutatok/kezdes")]
        public object KezdoUtmutato() => new
        {
            cim = "Kezdo utmutato",
            lepesek = new[]
            {
                "1. Indits ures edzest vagy valassz rutint.",
                "2. Add hozza a gyakorlatokat es pipald ki a sorozatokat.",
                "3. Befejezes utan oszd meg a kozossegben szelfivel es megyevel.",
                "4. Fedezd fel a helyi edzéseket a Community feedben.",
                "5. Mentsd el a tetszo edzéseket rutinkent."
            }
        };

        [HttpGet("utmutatok/rutin")]
        public object RutinUtmutato() => new
        {
            cim = "Rutin segitseg",
            lepesek = new[]
            {
                "AI generalas: valassz nehezseget, izomcsoportot es sportagat.",
                "Mentes: POST /api/routine/mentes ha megtetszik egy terv.",
                "Inditas: POST /api/workout/inditas-rutinbol/{rutin_id}.",
                "Kozossegbol: mentsd el mas edzeset, majd inditsd rutinkent.",
                "Kovetkezo het: hasznald a progresszio csuszkat a suly noveleshez."
            }
        };

        // --- GYIK / KAPCSOLAT / RÓLUNK ---

        [HttpGet("gyik")]
        public object GyakoriKerdesek() => new
        {
            kerdesek = new[]
            {
                new { kerdes = "Hogyan oszthatom meg az edzesemet?", valasz = "Befejezes utan: POST /api/workout/aktiv/befejezes-es-megosztas szelfi URL-lel es megyevel." },
                new { kerdes = "Hogyan menthetek el mas edzeset?", valasz = "A Community poszton: POST /api/community/{post_id}/mentes-rutinkent" },
                new { kerdes = "Hol valthatok kg es lbs kozott?", valasz = "Beallitasok > Mertekegysegek: PUT /api/beallitasok/{userName}/egyseg" },
                new { kerdes = "Mi a Pro tagsag?", valasz = "Pro funkcio: AI rutin generalas, reszletes statisztikak (hamarosan)." }
            }
        };

        [HttpPost("kapcsolat")]
        public ActionResult<object> KapcsolatUzenet([FromBody] KapcsolatKeres keres)
        {
            if (string.IsNullOrWhiteSpace(keres.Email) || string.IsNullOrWhiteSpace(keres.Uzenet))
            {
                return BadRequest("Email es Uzenet kotelezo.");
            }

            FelhasznaloTarolo.KapcsolatUzenetMentese(keres);
            return Ok(new { uzenet = "Uzenet elkuldve. Hamarosan valaszolunk!" });
        }

        [HttpGet("rolunk")]
        public object Rolunk() => new
        {
            appNev = "Fitness App",
            verzio = "1.0.0",
            leiras = "Hevy + Yazio ihlette fitness alkalmazas magyar kozosseggel.",
            funkcio = new[] { "Edzes naplo", "Rutin generalas", "Etkezes naplo", "Receptek", "Helyi Community feed", "Beallitasok" }
        };

        // --- Segédfüggvények ---

        private static string SanitizeFileName(string nev)
        {
            var karakterek = nev.Where(c => char.IsLetterOrDigit(c) || c == '-' || c == '_').ToArray();
            var tisztitott = new string(karakterek);
            return string.IsNullOrWhiteSpace(tisztitott) ? "user" : tisztitott.ToLowerInvariant();
        }

        private static bool ErvényesHetNap(string nap) =>
            nap.Equals("hetfo", StringComparison.OrdinalIgnoreCase) ||
            nap.Equals("vasarnap", StringComparison.OrdinalIgnoreCase);

        private static bool ErvényesLathatosag(string lathatosag) =>
            new[] { "mindenki", "kovetok", "kozosseg", "privat" }
                .Any(l => l.Equals(lathatosag, StringComparison.OrdinalIgnoreCase));

        private static bool ErvényesSulyEgyseg(string egyseg) =>
            egyseg.Equals("kg", StringComparison.OrdinalIgnoreCase) ||
            egyseg.Equals("lbs", StringComparison.OrdinalIgnoreCase);

        private static bool ErvényesTavolsagEgyseg(string egyseg) =>
            egyseg.Equals("km", StringComparison.OrdinalIgnoreCase) ||
            egyseg.Equals("mile", StringComparison.OrdinalIgnoreCase);

        private static bool ErvényesHosszEgyseg(string egyseg) =>
            egyseg.Equals("cm", StringComparison.OrdinalIgnoreCase) ||
            egyseg.Equals("inch", StringComparison.OrdinalIgnoreCase);

        private static bool ErvényesNyelv(string nyelv) =>
            new[] { "hu", "en", "de" }.Any(n => n.Equals(nyelv, StringComparison.OrdinalIgnoreCase));

        private static bool ErvényesTema(string mod) =>
            new[] { "vilagos", "sotet", "rendszer" }.Any(t => t.Equals(mod, StringComparison.OrdinalIgnoreCase));
    }
}
