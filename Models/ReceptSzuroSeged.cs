namespace FitnessBackend.Models
{
    public static class ReceptSzuroSeged
    {
        public static readonly List<ReceptKategoria> OsszesKategoria = new List<ReceptKategoria>
        {
            // Étkezés szerint
            new() { Id = "reggeli", Nev = "Reggeli", Ikon = "coffee", SzuresTipus = "mealdb_kategoria", MealDbKategoria = "Breakfast" },
            new() { Id = "ebed", Nev = "Ebéd", Ikon = "bowl", SzuresTipus = "mealdb_kategoria", MealDbKategoria = "Miscellaneous" },
            new() { Id = "vacsora", Nev = "Vacsora", Ikon = "salad", SzuresTipus = "mealdb_kategoria", MealDbKategoria = "Chicken" },
            new() { Id = "magas_feherje", Nev = "Magas fehérje", Ikon = "egg", SzuresTipus = "magas_feherje", MealDbKategoria = "Chicken" },

            // Diéta / életmód
            new() { Id = "vega", Nev = "Vega", Ikon = "sprout", SzuresTipus = "vega", MealDbKategoria = "Vegan" },
            new() { Id = "vegan", Nev = "Vegán", Ikon = "leaf", SzuresTipus = "vega", MealDbKategoria = "Vegan" },
            new() { Id = "keves_szenhidrat", Nev = "Kevés szénhidrát", Ikon = "wheat_off", SzuresTipus = "keves_szenhidrat" },
            new() { Id = "alacsony_zsir", Nev = "Alacsony zsírtartalom", Ikon = "drop", SzuresTipus = "alacsony_zsir" },
            new() { Id = "cukormentes", Nev = "Cukormentes", Ikon = "no_sugar", SzuresTipus = "cukormentes" },

            // Elkészítés
            new() { Id = "keves_hozzavalo", Nev = "Kevés hozzávaló", Ikon = "list_short", SzuresTipus = "keves_hozzavalo" },
            new() { Id = "gyors_elkeszites", Nev = "Gyorsan elkészíthető", Ikon = "timer", SzuresTipus = "gyors_elkeszites" }
        };

        public static readonly string[] AlapKategoriaPool =
        {
            "Vegan", "Vegetarian", "Seafood", "Chicken", "Breakfast",
            "Side", "Starter", "Pasta", "Beef", "Miscellaneous"
        };

        public static void ReceptKiegeszitese(ReceptListaElem recept, int hozzavalo_szam, string leiras, List<ReceptOsszetevo> osszetevok)
        {
            var makrok = ReceptApiSeged.MakrokBecslese(recept.BecsultKaloria, recept.Kategoria);

            recept.HozzavaloSzam = hozzavalo_szam;
            recept.BecsultFeherje = makrok.feherje;
            recept.BecsultSzenhidrat = makrok.szenhidrat;
            recept.BecsultZsir = makrok.zsir;
            recept.GyorsElkeszitheto = GyorsElkeszithetoE(leiras, hozzavalo_szam);
            recept.YazioCimkek = YazioCimkekGeneralasa(recept, osszetevok);
        }

        public static bool IlleszkedikSzurore(ReceptListaElem recept, string szures_tipus, List<ReceptOsszetevo>? osszetevok = null)
        {
            return szures_tipus switch
            {
                "mealdb_kategoria" => true,
                "magas_feherje" => recept.BecsultFeherje >= 25,
                "vega" => VegaRecept(recept),
                "keves_szenhidrat" => recept.BecsultSzenhidrat <= 20,
                "alacsony_zsir" => recept.BecsultZsir <= 10,
                "cukormentes" => CukormentesRecept(recept, osszetevok),
                "keves_hozzavalo" => recept.HozzavaloSzam <= 5,
                "gyors_elkeszites" => recept.GyorsElkeszitheto,
                _ => true
            };
        }

        public static List<string> MealDbKategoriakSzurohoz(string szures_tipus, string? mealdb_kategoria)
        {
            if (szures_tipus == "mealdb_kategoria" && !string.IsNullOrWhiteSpace(mealdb_kategoria))
            {
                return new List<string> { mealdb_kategoria };
            }

            if (szures_tipus == "vega")
            {
                return new List<string> { "Vegan", "Vegetarian" };
            }

            if (szures_tipus == "magas_feherje")
            {
                return new List<string> { "Chicken", "Seafood", "Beef", "Lamb", "Pork" };
            }

            return AlapKategoriaPool.ToList();
        }

        private static bool VegaRecept(ReceptListaElem recept)
        {
            if (recept.Kategoria.Equals("Vegan", StringComparison.OrdinalIgnoreCase) ||
                recept.Kategoria.Equals("Vegetarian", StringComparison.OrdinalIgnoreCase))
            {
                return true;
            }

            return recept.Cimkek.Any(c =>
                c.Contains("vegan", StringComparison.OrdinalIgnoreCase) ||
                c.Contains("vegetarian", StringComparison.OrdinalIgnoreCase));
        }

        private static bool CukormentesRecept(ReceptListaElem recept, List<ReceptOsszetevo>? osszetevok)
        {
            if (recept.Kategoria.Equals("Dessert", StringComparison.OrdinalIgnoreCase))
            {
                return false;
            }

            string[] cukor_szavak = { "sugar", "honey", "syrup", "chocolate", "caramel", "nutella", "jam", "cukor", "méz" };

            if (osszetevok != null)
            {
                foreach (var hozzavalo in osszetevok)
                {
                    if (cukor_szavak.Any(s => hozzavalo.Nev.Contains(s, StringComparison.OrdinalIgnoreCase)))
                    {
                        return false;
                    }
                }
            }

            if (recept.Cimkek.Any(c => c.Contains("sweet", StringComparison.OrdinalIgnoreCase)))
            {
                return false;
            }

            return true;
        }

        private static bool GyorsElkeszithetoE(string leiras, int hozzavalo_szam)
        {
            return hozzavalo_szam <= 4 || leiras.Length <= 450;
        }

        private static List<string> YazioCimkekGeneralasa(ReceptListaElem recept, List<ReceptOsszetevo> osszetevok)
        {
            var cimkek = new List<string>();

            if (recept.BecsultSzenhidrat <= 20) cimkek.Add("Kevés szénhidrát");
            if (recept.BecsultZsir <= 10) cimkek.Add("Alacsony zsírtartalom");
            if (CukormentesRecept(recept, osszetevok)) cimkek.Add("Cukormentes");
            if (VegaRecept(recept)) cimkek.Add("Vega");
            if (recept.HozzavaloSzam <= 5) cimkek.Add("Kevés hozzávaló");
            if (recept.GyorsElkeszitheto) cimkek.Add("Gyorsan elkészíthető");
            if (recept.BecsultFeherje >= 25) cimkek.Add("Magas fehérje");

            return cimkek;
        }
    }
}
