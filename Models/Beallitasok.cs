namespace FitnessBackend.Models
{
    // --- Teljes user beállítás csomag (Hevy Settings összes szekciója) ---

    public class UserBeallitasok
    {
        public string UserName { get; set; } = "";
        public ProfilBeallitas Profil { get; set; } = new ProfilBeallitas();
        public FiokBeallitas Fiok { get; set; } = new FiokBeallitas();
        public TagsagBeallitas Tagsag { get; set; } = new TagsagBeallitas();
        public ErtesitesBeallitas Ertesitesek { get; set; } = new ErtesitesBeallitas();
        public EdzesBeallitas Edzes { get; set; } = new EdzesBeallitas();
        public PrivatSzocialBeallitas PrivatSzocial { get; set; } = new PrivatSzocialBeallitas();
        public EgysegBeallitas Egyseg { get; set; } = new EgysegBeallitas();
        public string Nyelv { get; set; } = "hu";
        public TemaBeallitas Tema { get; set; } = new TemaBeallitas();
        public IntegracioBeallitas Integraciok { get; set; } = new IntegracioBeallitas();
        public DateTime Letrehozva { get; set; } = DateTime.Now;
        public DateTime Modositva { get; set; } = DateTime.Now;
    }

    // Profil: kép, név, social link, bio, szülinap (Miro + Hevy Profile)
    public class ProfilBeallitas
    {
        public string KepUrl { get; set; } = "";
        public string Nev { get; set; } = "";
        public string SocialLink { get; set; } = "";
        public string Bio { get; set; } = "";
        public DateTime? Szuletesnap { get; set; }
    }

    // Fiók: email, jelszó (Hevy Account)
    public class FiokBeallitas
    {
        public string Email { get; set; } = "";
        public string JelszoHash { get; set; } = "";
    }

    // Tagság / Pro (Hevy Manage Subscription)
    public class TagsagBeallitas
    {
        public bool ProAktiv { get; set; }
        public string Csomag { get; set; } = "ingyenes";
        public DateTime? Lejarat { get; set; }
    }

    // Értesítések (Miro: push/email, pihenő, követés, like, komment...)
    public class ErtesitesBeallitas
    {
        public bool PushEngedelyezve { get; set; } = true;
        public bool EmailEngedelyezve { get; set; } = true;
        public bool PihenoIdozito { get; set; } = true;
        public bool KovetesErtesites { get; set; } = true;
        public bool LikeValasz { get; set; } = true;
        public bool UjEdzesKozosseg { get; set; } = true;
        public bool SajatEdzesLike { get; set; } = true;
        public bool SajatEdzesKomment { get; set; } = true;
    }

    // Edzés beállítások (Miro: hangok, timer, PR, RPE, superset...)
    public class EdzesBeallitas
    {
        public bool Hangok { get; set; } = true;
        public int PihenoIdozitoMasodperc { get; set; } = 90;
        public bool PrHang { get; set; } = true;
        public string HetElsoNapja { get; set; } = "hetfo";
        public bool AutomatikusKitoltes { get; set; } = true;
        public bool KijelzoEbredve { get; set; } = true;
        public bool RpeKovetes { get; set; } = true;
        public bool OkosSuperset { get; set; } = true;
    }

    // Privát & közösségi (Hevy Privacy & Social + lokális community)
    public class PrivatSzocialBeallitas
    {
        public string ProfilLathatosag { get; set; } = "kozosseg";
        public bool EdzesMegosztasAlapertelmezett { get; set; } = true;
        public bool MegyeMutatasa { get; set; } = true;
        public bool SzelfiKizarolagKovetoknek { get; set; } = false;
        public bool RutinMasolhato { get; set; } = true;
    }

    // Mértékegységek (Hevy Units)
    public class EgysegBeallitas
    {
        public string Suly { get; set; } = "kg";
        public string Tavolsag { get; set; } = "km";
        public string Hossz { get; set; } = "cm";
    }

    public class TemaBeallitas
    {
        public string Mod { get; set; } = "rendszer";
    }

    // Integrációk (Apple Health, Watch, stb.)
    public class IntegracioBeallitas
    {
        public bool AppleHealth { get; set; }
        public bool AppleWatch { get; set; }
        public bool GoogleFit { get; set; }
        public bool Strava { get; set; }
    }

    // --- Kérések ---

    public class RegisztracioKeres
    {
        public string UserName { get; set; } = "";
        public string Email { get; set; } = "";
        public string Jelszo { get; set; } = "";
        public string Nev { get; set; } = "";
    }

    public class FelhasznalonevModositasKeres
    {
        public string UjUserName { get; set; } = "";
    }

    public class EmailModositasKeres
    {
        public string UjEmail { get; set; } = "";
        public string Jelszo { get; set; } = "";
    }

    public class JelszoModositasKeres
    {
        public string RegiJelszo { get; set; } = "";
        public string UjJelszo { get; set; } = "";
    }

    public class KapcsolatKeres
    {
        public string UserName { get; set; } = "";
        public string Email { get; set; } = "";
        public string Targy { get; set; } = "";
        public string Uzenet { get; set; } = "";
    }

    public class FelhasznaloExportCsomag
    {
        public string UserName { get; set; } = "";
        public DateTime Exportalva { get; set; } = DateTime.Now;
        public UserBeallitasok Beallitasok { get; set; } = new UserBeallitasok();
        public List<Routine> Rutinok { get; set; } = new List<Routine>();
        public List<CommunityPost> KozossegPosztok { get; set; } = new List<CommunityPost>();
        public ProgresszioBeallitas? Progresszio { get; set; }
    }

    // Frontend menü struktúra (Hevy Settings képernyő)
    public class BeallitasMenuSzekcio
    {
        public string Cim { get; set; } = "";
        public List<BeallitasMenuElem> Elemek { get; set; } = new List<BeallitasMenuElem>();
    }

    public class BeallitasMenuElem
    {
        public string Id { get; set; } = "";
        public string Cimke { get; set; } = "";
        public string Ikon { get; set; } = "";
        public string ApiUt { get; set; } = "";
        public bool ProFunkcio { get; set; }
    }

    public class ValasztasiOpcio
    {
        public string Id { get; set; } = "";
        public string Cimke { get; set; } = "";
    }

    public static class FelhasznaloTarolo
    {
        private static readonly Dictionary<string, UserBeallitasok> _felhasznalok =
            new Dictionary<string, UserBeallitasok>(StringComparer.OrdinalIgnoreCase);

        private static readonly List<KapcsolatKeres> _kapcsolatUzenetek = new List<KapcsolatKeres>();

        public static UserBeallitasok FelhasznaloLekerdezeseVagyLetrehozasa(string userName)
        {
            var kulcs = userName.Trim();
            if (!_felhasznalok.TryGetValue(kulcs, out var beallitasok))
            {
                beallitasok = new UserBeallitasok
                {
                    UserName = kulcs,
                    Profil = new ProfilBeallitas { Nev = kulcs }
                };
                _felhasznalok[kulcs] = beallitasok;
            }

            return beallitasok;
        }

        public static void FelhasznaloMentese(UserBeallitasok user)
        {
            user.Modositva = DateTime.Now;
            _felhasznalok[user.UserName] = user;
        }

        public static (bool siker, string? hiba) FelhasznalonevAtnevezese(string regiNev, string ujNev)
        {
            var regi_kulcs = regiNev.Trim();
            var uj_kulcs = ujNev.Trim();

            if (!_felhasznalok.TryGetValue(regi_kulcs, out var user))
            {
                user = FelhasznaloLekerdezeseVagyLetrehozasa(regi_kulcs);
            }

            if (_felhasznalok.ContainsKey(uj_kulcs) && !uj_kulcs.Equals(regi_kulcs, StringComparison.OrdinalIgnoreCase))
            {
                return (false, "Ez a felhasznalonev mar foglalt.");
            }

            _felhasznalok.Remove(regi_kulcs);
            user.UserName = uj_kulcs;
            FelhasznaloMentese(user);
            return (true, null);
        }

        public static bool FelhasznaloLetezik(string userName)
        {
            return _felhasznalok.ContainsKey(userName.Trim());
        }

        public static (UserBeallitasok? user, string? hiba) Regisztracio(RegisztracioKeres keres)
        {
            if (string.IsNullOrWhiteSpace(keres.UserName))
            {
                return (null, "UserName kotelezo.");
            }

            if (string.IsNullOrWhiteSpace(keres.Email))
            {
                return (null, "Email kotelezo.");
            }

            if (string.IsNullOrWhiteSpace(keres.Jelszo) || keres.Jelszo.Length < 6)
            {
                return (null, "Jelszo minimum 6 karakter.");
            }

            var kulcs = keres.UserName.Trim();
            if (_felhasznalok.ContainsKey(kulcs))
            {
                return (null, "Ez a felhasznalonev mar foglalt.");
            }

            if (_felhasznalok.Values.Any(u => u.Fiok.Email.Equals(keres.Email, StringComparison.OrdinalIgnoreCase)))
            {
                return (null, "Ez az email mar regisztralva van.");
            }

            var uj_user = new UserBeallitasok
            {
                UserName = kulcs,
                Profil = new ProfilBeallitas
                {
                    Nev = string.IsNullOrWhiteSpace(keres.Nev) ? kulcs : keres.Nev
                },
                Fiok = new FiokBeallitas
                {
                    Email = keres.Email.Trim(),
                    JelszoHash = JelszoHash(keres.Jelszo)
                }
            };

            _felhasznalok[kulcs] = uj_user;
            return (uj_user, null);
        }

        public static (bool siker, string? hiba) JelszoEllenorzes(string userName, string jelszo)
        {
            var user = FelhasznaloLekerdezeseVagyLetrehozasa(userName);
            if (string.IsNullOrEmpty(user.Fiok.JelszoHash))
            {
                return (true, null);
            }

            return user.Fiok.JelszoHash == JelszoHash(jelszo)
                ? (true, null)
                : (false, "Hibas jelszo.");
        }

        public static string JelszoHash(string jelszo) =>
            Convert.ToBase64String(System.Text.Encoding.UTF8.GetBytes(jelszo));

        public static void ModositasIdobelyeg(UserBeallitasok user)
        {
            user.Modositva = DateTime.Now;
        }

        public static void KapcsolatUzenetMentese(KapcsolatKeres uzenet)
        {
            _kapcsolatUzenetek.Add(uzenet);
        }

        public static FelhasznaloExportCsomag ExportOsszeallitasa(string userName)
        {
            var user = FelhasznaloLekerdezeseVagyLetrehozasa(userName);
            return new FelhasznaloExportCsomag
            {
                UserName = userName,
                Beallitasok = user,
                Rutinok = EdzesTervTarolo.MentettRutinok
                    .Where(r => r.CreatorName.Equals(userName, StringComparison.OrdinalIgnoreCase))
                    .ToList(),
                KozossegPosztok = CommunityTarolo.Posztok
                    .Where(p => p.UserName.Equals(userName, StringComparison.OrdinalIgnoreCase))
                    .ToList(),
                Progresszio = EdzesTervTarolo.ProgresszioBeallitas
            };
        }

        public static (bool siker, string? hiba) ImportVisszatoltes(FelhasznaloExportCsomag csomag)
        {
            if (string.IsNullOrWhiteSpace(csomag.UserName))
            {
                return (false, "UserName kotelezo az importban.");
            }

            var user = FelhasznaloLekerdezeseVagyLetrehozasa(csomag.UserName);
            if (csomag.Beallitasok != null)
            {
                user.Profil = csomag.Beallitasok.Profil;
                user.Ertesitesek = csomag.Beallitasok.Ertesitesek;
                user.Edzes = csomag.Beallitasok.Edzes;
                user.PrivatSzocial = csomag.Beallitasok.PrivatSzocial;
                user.Egyseg = csomag.Beallitasok.Egyseg;
                user.Nyelv = csomag.Beallitasok.Nyelv;
                user.Tema = csomag.Beallitasok.Tema;
                user.Integraciok = csomag.Beallitasok.Integraciok;
                FelhasznaloMentese(user);
            }

            foreach (var rutin in csomag.Rutinok)
            {
                if (!EdzesTervTarolo.MentettRutinok.Any(r => r.Id == rutin.Id))
                {
                    EdzesTervTarolo.MentettRutinok.Add(rutin);
                }
            }

            if (csomag.Progresszio != null)
            {
                EdzesTervTarolo.ProgresszioBeallitas = csomag.Progresszio;
            }

            return (true, null);
        }

        public static List<BeallitasMenuSzekcio> MenuStruktura(string userName)
        {
            var user = FelhasznaloLekerdezeseVagyLetrehozasa(userName);
            var api_alap = $"/api/beallitasok/{user.UserName}";

            return new List<BeallitasMenuSzekcio>
            {
                new()
                {
                    Cim = "Fiókom",
                    Elemek = new List<BeallitasMenuElem>
                    {
                        new() { Id = "profil",       Cimke = "Profil",         Ikon = "user",  ApiUt = $"{api_alap}/profil" },
                        new() { Id = "fiok",         Cimke = "Fiók",           Ikon = "lock",  ApiUt = $"{api_alap}/fiok" },
                        new() { Id = "ertesitesek",  Cimke = "Értesítések",    Ikon = "bell",  ApiUt = $"{api_alap}/ertesitesek" }
                    }
                },
                new()
                {
                    Cim = "Preferenciák",
                    Elemek = new List<BeallitasMenuElem>
                    {
                        new() { Id = "edzes",           Cimke = "Edzések",               Ikon = "dumbbell", ApiUt = $"{api_alap}/edzes" },
                        new() { Id = "privat-szocial",  Cimke = "Adatvédelem & közösség", Ikon = "shield",   ApiUt = $"{api_alap}/privat-szocial" },
                        new() { Id = "egyseg",          Cimke = "Mértékegységek",         Ikon = "ruler",    ApiUt = $"{api_alap}/egyseg" },
                        new() { Id = "nyelv",           Cimke = "Nyelv",                  Ikon = "flag",     ApiUt = $"{api_alap}/nyelv" },
                        new() { Id = "integraciok",     Cimke = "Apple Health",           Ikon = "heart",    ApiUt = $"{api_alap}/integraciok" }
                    }
                },
                new()
                {
                    Cim = "Eszközök és megjelenés",
                    Elemek = new List<BeallitasMenuElem>
                    {
                        new() { Id = "integraciok-watch", Cimke = "Apple Watch",    Ikon = "watch",  ApiUt = $"{api_alap}/integraciok" },
                        new() { Id = "integraciok-all",   Cimke = "Integrációk",    Ikon = "link",   ApiUt = $"{api_alap}/integraciok" },
                        new() { Id = "tema",              Cimke = "Megjelenés",     Ikon = "moon",   ApiUt = $"{api_alap}/tema" },
                        new() { Id = "export-import",     Cimke = "Export és import", Ikon = "export", ApiUt = $"{api_alap}/export" }
                    }
                },
                new()
                {
                    Cim = "Útmutatók",
                    Elemek = new List<BeallitasMenuElem>
                    {
                        new() { Id = "utmutato-kezdes", Cimke = "Kezdő útmutató", Ikon = "info",      ApiUt = "/api/beallitasok/utmutatok/kezdes" },
                        new() { Id = "utmutato-rutin",  Cimke = "Rutin segítség", Ikon = "clipboard", ApiUt = "/api/beallitasok/utmutatok/rutin" }
                    }
                },
                new()
                {
                    Cim = "Segítség",
                    Elemek = new List<BeallitasMenuElem>
                    {
                        new() { Id = "gyik",      Cimke = "Gyakori kérdések", Ikon = "help", ApiUt = "/api/beallitasok/gyik" },
                        new() { Id = "kapcsolat", Cimke = "Kapcsolat",        Ikon = "mail", ApiUt = "/api/beallitasok/kapcsolat" },
                        new() { Id = "rolunk",    Cimke = "Névjegy",          Ikon = "logo", ApiUt = "/api/beallitasok/rolunk" }
                    }
                }
            };
        }
    }
}
