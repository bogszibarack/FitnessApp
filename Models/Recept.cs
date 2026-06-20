namespace FitnessBackend.Models
{
    // Recept lista nézet (Yazio: főoldal kártyák)
    public class ReceptListaElem
    {
        public string Id { get; set; } = "";
        public string Nev { get; set; } = "";
        public string Kategoria { get; set; } = "";
        public string KepUrl { get; set; } = "";
        public int BecsultKaloria { get; set; }
        public int HozzavaloSzam { get; set; }
        public double BecsultFeherje { get; set; }
        public double BecsultSzenhidrat { get; set; }
        public double BecsultZsir { get; set; }
        public bool GyorsElkeszitheto { get; set; }
        public List<string> Cimkek { get; set; } = new List<string>();
        public List<string> YazioCimkek { get; set; } = new List<string>();
    }

    // Recept részletes nézet (Yazio: recept oldal)
    public class ReceptReszletes : ReceptListaElem
    {
        public string Leiras { get; set; } = "";
        public string YoutubeUrl { get; set; } = "";
        public string SzarmazasiTerulet { get; set; } = "";
        public List<ReceptOsszetevo> Osszetevok { get; set; } = new List<ReceptOsszetevo>();
    }

    public class ReceptOsszetevo
    {
        public string Nev { get; set; } = "";
        public string Mennyiseg { get; set; } = "";
    }

    // Yazio: Népszerű kategóriák + kalória tartományok
    public class ReceptKategoria
    {
        public string Id { get; set; } = "";
        public string Nev { get; set; } = "";
        public string Ikon { get; set; } = "";

        // Spoonacular complexSearch query-fragment, pl. "diet=vegan&maxCarbs=25"
        public string SpoonParam { get; set; } = "";
    }

    public class KaloriaTartomany
    {
        public int Min { get; set; }
        public int Max { get; set; }
        public string Nev { get; set; } = "";
    }

    public static class ReceptTarolo
    {
        public static List<ReceptListaElem> KedvencReceptek { get; } = new List<ReceptListaElem>();
    }

    // Recept hozzáadása a naplóhoz (Yazio: recept → napló)
    public class ReceptNaplobaKeres
    {
        public string ReceptId { get; set; } = "";
        public double AdagSzam { get; set; } = 1;
        public string EtkezesTipus { get; set; } = "reggeli";
    }
}
