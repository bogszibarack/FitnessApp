namespace FitnessBackend.Models
{
    public class CommunityPost
    {
        public string Id { get; set; } = "";
        public string UserName { get; set; } = "";
        public string County { get; set; } = "";
        public string Region { get; set; } = "";
        public string SelfieUrl { get; set; } = "";
        public string ProfileImageUrl { get; set; } = "";
        public DateTime SharedAt { get; set; }
        public WorkoutSession Workout { get; set; } = new();
        public int LikeCount { get; set; }
        public List<string> LikedBy { get; set; } = new();
        public List<CommunityComment> Comments { get; set; } = new();
    }

    public class CommunityComment
    {
        public string Id { get; set; } = "";
        public string UserName { get; set; } = "";
        public string Text { get; set; } = "";
        public string ProfileImageUrl { get; set; } = "";
        public DateTime CreatedAt { get; set; }
    }

    public class ShareRequest
    {
        public string UserName { get; set; } = "";
        public string County { get; set; } = "";
        public string SelfieUrl { get; set; } = "";
        public WorkoutSession Workout { get; set; } = new();
    }

    public class CommentRequest
    {
        public string UserName { get; set; } = "";
        public string Text { get; set; } = "";
    }

    public class CountyInfo
    {
        public string Id { get; set; } = "";
        public string Name { get; set; } = "";
        public string Region { get; set; } = "";
    }

    /// <summary>County metadata (feed filters / share validation). Posts live in Postgres.</summary>
    public static class CommunityStore
    {
        public static readonly List<CountyInfo> Counties =
        [
            new() { Id = "budapest", Name = "Budapest", Region = "Kozep-Magyarorszag" },
            new() { Id = "pest", Name = "Pest", Region = "Kozep-Magyarorszag" },
            new() { Id = "fejer", Name = "Fejér", Region = "Kozep-Magyarorszag" },
            new() { Id = "komarom_esztergom", Name = "Komárom-Esztergom", Region = "Kozep-Dunantul" },
            new() { Id = "veszprem", Name = "Veszprém", Region = "Kozep-Dunantul" },
            new() { Id = "gyor_moson_sopron", Name = "Győr-Moson-Sopron", Region = "Nyugat-Dunantul" },
            new() { Id = "vas", Name = "Vas", Region = "Nyugat-Dunantul" },
            new() { Id = "zala", Name = "Zala", Region = "Nyugat-Dunantul" },
            new() { Id = "somogy", Name = "Somogy", Region = "Del-Dunantul" },
            new() { Id = "tolna", Name = "Tolna", Region = "Del-Dunantul" },
            new() { Id = "baranya", Name = "Baranya", Region = "Del-Dunantul" },
            new() { Id = "bacs_kiskun", Name = "Bács-Kiskun", Region = "Del-Alfold" },
            new() { Id = "csongrad_csanad", Name = "Csongrád-Csanád", Region = "Del-Alfold" },
            new() { Id = "bekes", Name = "Békés", Region = "Del-Alfold" },
            new() { Id = "jasz_nagykun_szolnok", Name = "Jász-Nagykun-Szolnok", Region = "Eszak-Alfold" },
            new() { Id = "hajdu_bihar", Name = "Hajdú-Bihar", Region = "Eszak-Alfold" },
            new() { Id = "szabolcs_szatmar_bereg", Name = "Szabolcs-Szatmár-Bereg", Region = "Eszak-Alfold" },
            new() { Id = "heves", Name = "Heves", Region = "Eszak-Magyarorszag" },
            new() { Id = "nograd", Name = "Nógrád", Region = "Eszak-Magyarorszag" },
            new() { Id = "borsod_abauj_zemplen", Name = "Borsod-Abaúj-Zemplén", Region = "Eszak-Magyarorszag" }
        ];

        public static CountyInfo? FindCounty(string idOrName) =>
            Counties.FirstOrDefault(c =>
                c.Id.Equals(idOrName, StringComparison.OrdinalIgnoreCase) ||
                c.Name.Equals(idOrName, StringComparison.OrdinalIgnoreCase));
    }
}
