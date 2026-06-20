namespace FitnessBackend.Models
{
    /// <summary>Recept kategóriák — fitness/egészséges fókusz, Spoonacular szűrő-paraméterekkel.</summary>
    public static class ReceptSzuroSeged
    {
        public static readonly List<ReceptKategoria> OsszesKategoria = new List<ReceptKategoria>
        {
            new() { Id = "reggeli", Nev = "Reggeli", Ikon = "coffee", SpoonParam = "type=breakfast&sort=healthiness" },
            new() { Id = "ebed", Nev = "Ebéd", Ikon = "bowl", SpoonParam = "type=main course&sort=healthiness" },
            new() { Id = "vacsora", Nev = "Vacsora", Ikon = "salad", SpoonParam = "type=main course&sort=time" },
            new() { Id = "magas_feherje", Nev = "Magas fehérje", Ikon = "egg", SpoonParam = "minProtein=25&sort=protein&sortDirection=desc" },
            new() { Id = "vega", Nev = "Vega", Ikon = "sprout", SpoonParam = "diet=vegetarian&sort=healthiness" },
            new() { Id = "vegan", Nev = "Vegán", Ikon = "leaf", SpoonParam = "diet=vegan&sort=healthiness" },
            new() { Id = "keves_szenhidrat", Nev = "Kevés szénhidrát", Ikon = "wheat_off", SpoonParam = "maxCarbs=25&sort=healthiness" },
            new() { Id = "alacsony_zsir", Nev = "Alacsony zsír", Ikon = "drop", SpoonParam = "maxFat=15&sort=healthiness" },
            new() { Id = "egeszseges", Nev = "Egészséges", Ikon = "heart", SpoonParam = "sort=healthiness&sortDirection=desc" },
            new() { Id = "gyors_elkeszites", Nev = "Gyors", Ikon = "timer", SpoonParam = "maxReadyTime=20&sort=time" }
        };

        public static ReceptKategoria? KategoriaById(string id)
        {
            return OsszesKategoria.FirstOrDefault(k => k.Id.Equals(id, StringComparison.OrdinalIgnoreCase));
        }
    }
}
