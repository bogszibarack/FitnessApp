namespace FitnessBackend.Models
{
    // Közösségi poszt: szelfi + befejezett edzés + megye
    public class CommunityPost
    {
        public string Id { get; set; } = "";
        public string UserName { get; set; } = "";
        public string Megye { get; set; } = "";
        public string Regio { get; set; } = "";
        public string SelfieUrl { get; set; } = "";
        public DateTime Megosztva { get; set; }
        public WorkoutSession Edzes { get; set; } = new WorkoutSession();
        public int LikeSzam { get; set; }
        public List<string> Likeolok { get; set; } = new List<string>();
        public List<CommunityComment> Kommentek { get; set; } = new List<CommunityComment>();
    }

    public class CommunityComment
    {
        public string Id { get; set; } = "";
        public string UserName { get; set; } = "";
        public string Szoveg { get; set; } = "";
        public DateTime Idobelyeg { get; set; }
    }

    // Telefon küldi edzés után: szelfi + megye + edzés adatok
    public class MegosztasKeres
    {
        public string UserName { get; set; } = "";
        public string Megye { get; set; } = "";
        public string SelfieUrl { get; set; } = "";
        public WorkoutSession Edzes { get; set; } = new WorkoutSession();
    }

    public class KommentKeres
    {
        public string UserName { get; set; } = "";
        public string Szoveg { get; set; } = "";
    }

    public class LikeKeres
    {
        public string UserName { get; set; } = "";
    }

    public class MegyeInfo
    {
        public string Id { get; set; } = "";
        public string Nev { get; set; } = "";
        public string Regio { get; set; } = "";
    }

    public static class CommunityTarolo
    {
        public static List<CommunityPost> Posztok { get; } = new List<CommunityPost>();

        public static readonly List<MegyeInfo> MagyarMegyek = new List<MegyeInfo>
        {
            new() { Id = "budapest", Nev = "Budapest", Regio = "Kozep-Magyarorszag" },
            new() { Id = "pest", Nev = "Pest", Regio = "Kozep-Magyarorszag" },
            new() { Id = "fejer", Nev = "Fejér", Regio = "Kozep-Magyarorszag" },
            new() { Id = "komarom_esztergom", Nev = "Komárom-Esztergom", Regio = "Kozep-Dunantul" },
            new() { Id = "veszprem", Nev = "Veszprém", Regio = "Kozep-Dunantul" },
            new() { Id = "gyor_moson_sopron", Nev = "Győr-Moson-Sopron", Regio = "Nyugat-Dunantul" },
            new() { Id = "vas", Nev = "Vas", Regio = "Nyugat-Dunantul" },
            new() { Id = "zala", Nev = "Zala", Regio = "Nyugat-Dunantul" },
            new() { Id = "somogy", Nev = "Somogy", Regio = "Del-Dunantul" },
            new() { Id = "tolna", Nev = "Tolna", Regio = "Del-Dunantul" },
            new() { Id = "baranya", Nev = "Baranya", Regio = "Del-Dunantul" },
            new() { Id = "bacs_kiskun", Nev = "Bács-Kiskun", Regio = "Del-Alfold" },
            new() { Id = "csongrad_csanad", Nev = "Csongrád-Csanád", Regio = "Del-Alfold" },
            new() { Id = "bekes", Nev = "Békés", Regio = "Del-Alfold" },
            new() { Id = "jasz_nagykun_szolnok", Nev = "Jász-Nagykun-Szolnok", Regio = "Eszak-Alfold" },
            new() { Id = "hajdu_bihar", Nev = "Hajdú-Bihar", Regio = "Eszak-Alfold" },
            new() { Id = "szabolcs_szatmar_bereg", Nev = "Szabolcs-Szatmár-Bereg", Regio = "Eszak-Alfold" },
            new() { Id = "heves", Nev = "Heves", Regio = "Eszak-Magyarorszag" },
            new() { Id = "nograd", Nev = "Nógrád", Regio = "Eszak-Magyarorszag" },
            new() { Id = "borsod_abauj_zemplen", Nev = "Borsod-Abaúj-Zemplén", Regio = "Eszak-Magyarorszag" }
        };

        public static (CommunityPost? poszt, string? hiba) UjPosztLetrehozasa(MegosztasKeres keres)
        {
            if (string.IsNullOrWhiteSpace(keres.UserName))
            {
                return (null, "UserName kotelezo.");
            }

            if (string.IsNullOrWhiteSpace(keres.Megye))
            {
                return (null, "Megye kotelezo.");
            }

            var megye_info = MagyarMegyek.FirstOrDefault(m =>
                m.Id.Equals(keres.Megye, StringComparison.OrdinalIgnoreCase) ||
                m.Nev.Equals(keres.Megye, StringComparison.OrdinalIgnoreCase));

            if (megye_info == null)
            {
                return (null, "Ismeretlen megye. Hasznald: GET /api/community/megyek");
            }

            if (keres.Edzes == null || keres.Edzes.Exercises.Count == 0)
            {
                return (null, "Az edzes adatok kotelezoek (legalabb 1 gyakorlat).");
            }

            var uj_poszt = new CommunityPost
            {
                Id = $"post_{Guid.NewGuid().ToString("N")[..8]}",
                UserName = keres.UserName,
                Megye = megye_info.Nev,
                Regio = megye_info.Regio,
                SelfieUrl = keres.SelfieUrl,
                Megosztva = DateTime.Now,
                Edzes = keres.Edzes
            };

            Posztok.Insert(0, uj_poszt);
            return (uj_poszt, null);
        }
    }
}
