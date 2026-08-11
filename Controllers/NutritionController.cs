using Microsoft.AspNetCore.Authorization;
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
        [AllowAnonymous]
        public async Task<ActionResult<List<FoodItem>>> Search([FromQuery] string? q = null)
        {
            if (string.IsNullOrWhiteSpace(q))
                return BadRequest("Add meg a keresoszot: ?q=alma");
            var user = CurrentUser.UserName(User);
            return Ok(await NutritionService.SearchFoodAsync(q, user));
        }

        [HttpGet("search/{name}")]
        [AllowAnonymous]
        public async Task<ActionResult<List<FoodItem>>> SearchByName(string name)
        {
            if (string.IsNullOrWhiteSpace(name) || name.Contains("etel_neve"))
                return BadRequest("Az etel_neve mezobe ird be a keresett etelt, pl: alma");
            var user = CurrentUser.UserName(User);
            return Ok(await NutritionService.SearchFoodAsync(name, user));
        }

        [HttpGet("barcode/{code}")]
        [AllowAnonymous]
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

        [Authorize]
        [HttpGet("log/today")]
        public ActionResult<DailyNutritionSession> LogToday()
        {
            if (CurrentUser.RequireUser(this, out var user) is { } deny) return deny;
            return Ok(NutritionService.GetLog(user, DateTime.Today));
        }

        [Authorize]
        [HttpGet("log/{year}/{month}/{day}")]
        public ActionResult<DailyNutritionSession> LogOnDate(int year, int month, int day)
        {
            if (CurrentUser.RequireUser(this, out var user) is { } deny) return deny;
            return Ok(NutritionService.GetLog(user, new DateTime(year, month, day)));
        }

        [Authorize]
        [HttpGet("log/today/{mealType}")]
        public ActionResult<object> LogTodayByMeal(string mealType)
        {
            if (CurrentUser.RequireUser(this, out var user) is { } deny) return deny;
            return Ok(NutritionService.MealSummary(user, mealType));
        }

        [Authorize]
        [HttpGet("log/today/recipes")]
        public ActionResult<List<LoggedFood>> TodaysRecipes()
        {
            if (CurrentUser.RequireUser(this, out var user) is { } deny) return deny;
            return Ok(NutritionService.TodaysRecipes(user));
        }

        [Authorize]
        [HttpPut("target-calories")]
        public ActionResult<DailyNutritionSession> SetTargetCalories([FromBody] double target)
        {
            if (CurrentUser.RequireUser(this, out var user) is { } deny) return deny;
            return Ok(NutritionService.SetTargetCalories(user, target));
        }

        [Authorize]
        [HttpPost("food")]
        public ActionResult<DailyNutritionSession> AddFood([FromBody] LoggedFood food)
        {
            if (CurrentUser.RequireUser(this, out var user) is { } deny) return deny;
            var (log, err) = NutritionService.AddFood(user, food);
            if (err != null) return BadRequest(err);
            return Ok(log);
        }

        [Authorize]
        [HttpPost("recipe")]
        public async Task<ActionResult<DailyNutritionSession>> AddRecipe([FromBody] AddRecipeRequest request)
        {
            if (CurrentUser.RequireUser(this, out var user) is { } deny) return deny;
            var (log, _, err) = await NutritionService.AddRecipeAsync(user, request);
            if (err != null)
                return err.Contains("Nincs") ? NotFound(err) : BadRequest(err);
            return Ok(log);
        }

        [Authorize]
        [HttpPut("food/{index}")]
        public ActionResult<DailyNutritionSession> UpdateFood(int index, [FromBody] LoggedFood food)
        {
            if (CurrentUser.RequireUser(this, out var user) is { } deny) return deny;
            var (log, err) = NutritionService.UpdateFood(user, index, food);
            if (err != null) return NotFound(err);
            return Ok(log);
        }

        [Authorize]
        [HttpDelete("food/{index}")]
        public ActionResult<DailyNutritionSession> DeleteFood(int index)
        {
            if (CurrentUser.RequireUser(this, out var user) is { } deny) return deny;
            var (log, err) = NutritionService.DeleteFood(user, index);
            if (err != null) return NotFound(err);
            return Ok(log);
        }

        [Authorize]
        [HttpGet("custom-foods")]
        public ActionResult<List<CustomFood>> ListCustomFoods()
        {
            if (CurrentUser.RequireUser(this, out var user) is { } deny) return deny;
            return Ok(NutritionService.ListCustomFoods(user));
        }

        [Authorize]
        [HttpPost("custom-foods")]
        public ActionResult<CustomFood> CreateCustomFood([FromBody] CustomFoodRequest request)
        {
            if (CurrentUser.RequireUser(this, out var user) is { } deny) return deny;
            var (food, err) = NutritionService.CreateCustomFood(user, request);
            if (err != null) return BadRequest(err);
            return Ok(food);
        }

        [Authorize]
        [HttpDelete("custom-foods/{id}")]
        public ActionResult DeleteCustomFood(string id)
        {
            if (CurrentUser.RequireUser(this, out var user) is { } deny) return deny;
            if (!NutritionService.DeleteCustomFood(user, id)) return NotFound("Nincs ilyen sajat etel.");
            return NoContent();
        }

        [HttpGet("streak")]
        public ActionResult<object> GetStreak([FromQuery] string? userName)
        {
            var fromJwt = CurrentUser.UserName(User);
            var state = StreakStore.Get(fromJwt ?? userName ?? "");
            return Ok(new { streak = state.Streak, lastDate = state.LastDate });
        }

        [HttpPost("streak")]
        public ActionResult<object> UpdateStreak([FromBody] StreakUpdateRequest request)
        {
            var fromJwt = CurrentUser.UserName(User);
            var name = fromJwt ?? request.UserName ?? "";
            var state = StreakStore.Update(name, request.HasFoodToday);
            return Ok(new { streak = state.Streak, lastDate = state.LastDate });
        }

        // --- Legacy aliases ---

        [HttpGet("kereso")]
        [AllowAnonymous]
        public Task<ActionResult<List<FoodItem>>> SearchLegacy([FromQuery] string keresoszo) =>
            Search(keresoszo);

        [HttpGet("kereses/{etel_neve}")]
        [AllowAnonymous]
        public Task<ActionResult<List<FoodItem>>> SearchPathLegacy(string etel_neve) =>
            SearchByName(etel_neve);

        [HttpGet("vonalkod/{vonalkod}")]
        [AllowAnonymous]
        public Task<ActionResult<FoodItem>> BarcodeLegacy(string vonalkod) =>
            Barcode(vonalkod);

        [Authorize]
        [HttpGet("mai-naplo")]
        public ActionResult<DailyNutritionSession> LogTodayLegacy() => LogToday();

        [Authorize]
        [HttpGet("naplo/{ev}/{honap}/{nap}")]
        public ActionResult<DailyNutritionSession> LogOnDateLegacy(int ev, int honap, int nap) =>
            LogOnDate(ev, honap, nap);

        [Authorize]
        [HttpGet("mai-naplo/receptek")]
        public ActionResult<List<LoggedFood>> TodaysRecipesLegacy() => TodaysRecipes();

        [Authorize]
        [HttpGet("mai-naplo/{etkezes_tipus}")]
        public ActionResult<object> LogTodayByMealLegacy(string etkezes_tipus) =>
            LogTodayByMeal(etkezes_tipus);

        [Authorize]
        [HttpPut("cel-kaloria")]
        public ActionResult<DailyNutritionSession> SetTargetCaloriesLegacy([FromBody] double cel_kaloria) =>
            SetTargetCalories(cel_kaloria);

        [Authorize]
        [HttpPost("etel-hozzaadas")]
        public ActionResult<DailyNutritionSession> AddFoodLegacy([FromBody] LoggedFood uj_etel) =>
            AddFood(uj_etel);

        [Authorize]
        [HttpPost("recept-hozzaadas")]
        public Task<ActionResult<DailyNutritionSession>> AddRecipeLegacy([FromBody] AddRecipeRequest keres) =>
            AddRecipe(keres);

        [Authorize]
        [HttpPut("etel-modositas/{etel_index}")]
        public ActionResult<DailyNutritionSession> UpdateFoodLegacy(int etel_index, [FromBody] LoggedFood modositott_etel) =>
            UpdateFood(etel_index, modositott_etel);

        [Authorize]
        [HttpDelete("etel-torles/{etel_index}")]
        public ActionResult<DailyNutritionSession> DeleteFoodLegacy(int etel_index) =>
            DeleteFood(etel_index);
    }
}
