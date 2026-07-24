using Microsoft.AspNetCore.Mvc;
using FitnessBackend.Models;
using FitnessBackend.Services;

namespace FitnessBackend.Controllers
{
    [ApiController]
    [Route("api/nutrition")]
    public class NutritionController : ControllerBase
    {
        [HttpGet("search")]
        public async Task<ActionResult<List<FoodItem>>> Search([FromQuery] string? q = null)
        {
            if (string.IsNullOrWhiteSpace(q))
                return BadRequest("Add meg a keresoszot: ?q=alma");
            return Ok(await NutritionService.SearchFoodAsync(q));
        }

        [HttpGet("search/{name}")]
        public async Task<ActionResult<List<FoodItem>>> SearchByName(string name)
        {
            if (string.IsNullOrWhiteSpace(name) || name.Contains("etel_neve"))
                return BadRequest("Az etel_neve mezobe ird be a keresett etelt, pl: alma");
            return Ok(await NutritionService.SearchFoodAsync(name));
        }

        [HttpGet("barcode/{code}")]
        public async Task<ActionResult<FoodItem>> Barcode(string code)
        {
            var (food, err, status) = await NutritionService.LookupBarcodeAsync(code);
            if (err != null)
            {
                return status switch
                {
                    404 => NotFound(err),
                    503 => StatusCode(503, err),
                    _ => BadRequest(err),
                };
            }
            return Ok(food);
        }

        [HttpGet("log/today")]
        public ActionResult<DailyNutritionSession> LogToday() =>
            Ok(NutritionService.GetLog(DateTime.Today));

        [HttpGet("log/{year}/{month}/{day}")]
        public ActionResult<DailyNutritionSession> LogOnDate(int year, int month, int day) =>
            Ok(NutritionService.GetLog(new DateTime(year, month, day)));

        [HttpGet("log/today/{mealType}")]
        public ActionResult<object> LogTodayByMeal(string mealType) =>
            Ok(NutritionService.MealSummary(mealType));

        [HttpGet("log/today/recipes")]
        public ActionResult<List<LoggedFood>> TodaysRecipes() =>
            Ok(NutritionService.TodaysRecipes());

        [HttpPut("target-calories")]
        public ActionResult<DailyNutritionSession> SetTargetCalories([FromBody] double target) =>
            Ok(NutritionService.SetTargetCalories(target));

        [HttpPost("food")]
        public ActionResult<DailyNutritionSession> AddFood([FromBody] LoggedFood food)
        {
            var (log, err) = NutritionService.AddFood(food);
            if (err != null) return BadRequest(err);
            return Ok(log);
        }

        [HttpPost("recipe")]
        public async Task<ActionResult<DailyNutritionSession>> AddRecipe([FromBody] AddRecipeRequest request)
        {
            var (log, _, err) = await NutritionService.AddRecipeAsync(request);
            if (err != null)
                return err.Contains("Nincs") ? NotFound(err) : BadRequest(err);
            return Ok(log);
        }

        [HttpPut("food/{index}")]
        public ActionResult<DailyNutritionSession> UpdateFood(int index, [FromBody] LoggedFood food)
        {
            var (log, err) = NutritionService.UpdateFood(index, food);
            if (err != null) return NotFound(err);
            return Ok(log);
        }

        [HttpDelete("food/{index}")]
        public ActionResult<DailyNutritionSession> DeleteFood(int index)
        {
            var (log, err) = NutritionService.DeleteFood(index);
            if (err != null) return NotFound(err);
            return Ok(log);
        }

        [HttpGet("streak")]
        public ActionResult<object> GetStreak([FromQuery] string? userName)
        {
            var state = StreakStore.Get(userName ?? "");
            return Ok(new { streak = state.Streak, lastDate = state.LastDate });
        }

        [HttpPost("streak")]
        public ActionResult<object> UpdateStreak([FromBody] StreakUpdateRequest request)
        {
            var state = StreakStore.Update(request.UserName ?? "", request.HasFoodToday);
            return Ok(new { streak = state.Streak, lastDate = state.LastDate });
        }

        // --- Legacy aliases (older Flutter builds) ---

        [HttpGet("kereso")]
        public Task<ActionResult<List<FoodItem>>> SearchLegacy([FromQuery] string keresoszo) =>
            Search(keresoszo);

        [HttpGet("kereses/{etel_neve}")]
        public Task<ActionResult<List<FoodItem>>> SearchPathLegacy(string etel_neve) =>
            SearchByName(etel_neve);

        [HttpGet("vonalkod/{vonalkod}")]
        public Task<ActionResult<FoodItem>> BarcodeLegacy(string vonalkod) =>
            Barcode(vonalkod);

        [HttpGet("mai-naplo")]
        public ActionResult<DailyNutritionSession> LogTodayLegacy() => LogToday();

        [HttpGet("naplo/{ev}/{honap}/{nap}")]
        public ActionResult<DailyNutritionSession> LogOnDateLegacy(int ev, int honap, int nap) =>
            LogOnDate(ev, honap, nap);

        [HttpGet("mai-naplo/receptek")]
        public ActionResult<List<LoggedFood>> TodaysRecipesLegacy() => TodaysRecipes();

        [HttpGet("mai-naplo/{etkezes_tipus}")]
        public ActionResult<object> LogTodayByMealLegacy(string etkezes_tipus) =>
            LogTodayByMeal(etkezes_tipus);

        [HttpPut("cel-kaloria")]
        public ActionResult<DailyNutritionSession> SetTargetCaloriesLegacy([FromBody] double cel_kaloria) =>
            SetTargetCalories(cel_kaloria);

        [HttpPost("etel-hozzaadas")]
        public ActionResult<DailyNutritionSession> AddFoodLegacy([FromBody] LoggedFood uj_etel) =>
            AddFood(uj_etel);

        [HttpPost("recept-hozzaadas")]
        public Task<ActionResult<DailyNutritionSession>> AddRecipeLegacy([FromBody] AddRecipeRequest keres) =>
            AddRecipe(keres);

        [HttpPut("etel-modositas/{etel_index}")]
        public ActionResult<DailyNutritionSession> UpdateFoodLegacy(int etel_index, [FromBody] LoggedFood modositott_etel) =>
            UpdateFood(etel_index, modositott_etel);

        [HttpDelete("etel-torles/{etel_index}")]
        public ActionResult<DailyNutritionSession> DeleteFoodLegacy(int etel_index) =>
            DeleteFood(etel_index);
    }
}
