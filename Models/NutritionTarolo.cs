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

            LoggedFood bejegyzes;

            // Ha a frontend elküldte a tápértékeket, nem kell külső API-hívás
            if (keres.KaloriaAdagonkent.HasValue && keres.KaloriaAdagonkent.Value > 0)
            {
                bejegyzes = new LoggedFood
                {
                    FoodId = keres.ReceptId,
                    FoodName = keres.ReceptNev ?? keres.ReceptId,
                    MealType = keres.EtkezesTipus,
                    Receptbol = true,
                    ReceptId = keres.ReceptId,
                    AdagSzam = keres.AdagSzam,
                    CaloriesPer100g = keres.KaloriaAdagonkent.Value,
                    ProteinPer100g = keres.FeherjeAdagonkent ?? 0,
                    CarbsPer100g = keres.SzenhidratAdagonkent ?? 0,
                    FatPer100g = keres.ZsirAdagonkent ?? 0,
                };
            }
            else
            {
                var recept = await NosaltyApiSeged.ReceptLekerdezese(keres.ReceptId);
                if (recept == null)
                    return (null, null, "Nincs ilyen recept.");

                bejegyzes = NosaltyApiSeged.ReceptbolNaploBejegyzes(recept, keres.AdagSzam, keres.EtkezesTipus);
            }

            var naplo = NaploLekerdezeseVagyLetrehozasa(DateTime.Today);
            naplo.EatenFoods.Add(bejegyzes);
            DataPersistence.NutritionMentese();

            return (naplo, bejegyzes, null);
        }
    }
}
