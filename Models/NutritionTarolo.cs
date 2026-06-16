namespace FitnessBackend.Models
{
    public static class NutritionTarolo
    {
        public static List<DailyNutritionSession> NapiNaplok { get; } = new List<DailyNutritionSession>();

        public static DailyNutritionSession NaploLekerdezeseVagyLetrehozasa(DateTime datum)
        {
            var naplo = NapiNaplok.FirstOrDefault(n => n.Date.Date == datum.Date);
            if (naplo == null)
            {
                naplo = new DailyNutritionSession { Date = datum.Date, TargetCalories = 2200 };
                NapiNaplok.Add(naplo);
            }
            return naplo;
        }

        public static async Task<(DailyNutritionSession? naplo, LoggedFood? bejegyzes, string? hiba)>
            ReceptHozzaadasaAsync(ReceptNaplobaKeres keres)
        {
            if (string.IsNullOrWhiteSpace(keres.ReceptId))
            {
                return (null, null, "ReceptId kotelezo.");
            }

            if (keres.AdagSzam <= 0)
            {
                return (null, null, "AdagSzam kotelezo es nagyobb mint 0.");
            }

            var recept = await ReceptApiSeged.ReceptLekerdezese(keres.ReceptId);
            if (recept == null)
            {
                return (null, null, "Nincs ilyen recept.");
            }

            var bejegyzes = ReceptApiSeged.ReceptbolNaploBejegyzes(
                recept, keres.AdagSzam, keres.EtkezesTipus);

            var naplo = NaploLekerdezeseVagyLetrehozasa(DateTime.Today);
            naplo.EatenFoods.Add(bejegyzes);

            return (naplo, bejegyzes, null);
        }
    }
}
