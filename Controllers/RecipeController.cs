using Microsoft.AspNetCore.Mvc;
using FitnessBackend.Models;
using FitnessBackend.Services;

namespace FitnessBackend.Controllers
{
    [ApiController]
    [Route("api/recipe")]
    public class RecipeController : ControllerBase
    {
        [HttpGet("categories")]
        public List<RecipeCategory> Categories() => RecipeService.Categories;

        [HttpGet("calorie-bands")]
        public List<CalorieRange> CalorieBands() => RecipeService.CalorieBands;

        [HttpGet("search")]
        public async Task<ActionResult<List<RecipeListItem>>> Search([FromQuery] string? q = null)
        {
            if (string.IsNullOrWhiteSpace(q))
                return BadRequest("Add meg a keresoszot.");
            return Ok(await RecipeService.SearchAsync(q));
        }

        [HttpGet("category/{*categoryId}")]
        public async Task<ActionResult<List<RecipeListItem>>> ByCategory(string categoryId)
        {
            var (items, err) = await RecipeService.ByCategoryAsync(categoryId);
            if (err != null) return BadRequest(err);
            return Ok(items);
        }

        [HttpGet("by-calories")]
        public async Task<ActionResult<List<RecipeListItem>>> ByCalories([FromQuery] int min, [FromQuery] int max) =>
            Ok(await RecipeService.ByCaloriesAsync(min, max));

        [HttpGet("discover")]
        public async Task<ActionResult<List<RecipeListItem>>> Discover([FromQuery] int count = 12) =>
            Ok(await RecipeService.DiscoverAsync(count));

        [HttpGet("favorites")]
        public List<RecipeListItem> Favorites() => RecipeService.Favorites;

        [HttpPost("favorites/{id}")]
        public async Task<ActionResult<RecipeListItem>> AddFavorite(string id)
        {
            var (item, err) = await RecipeService.AddFavoriteAsync(id);
            if (err != null) return NotFound(err);
            return Ok(item);
        }

        [HttpDelete("favorites/{id}")]
        public ActionResult<string> RemoveFavorite(string id)
        {
            var (msg, err) = RecipeService.RemoveFavorite(id);
            if (err != null) return NotFound(err);
            return Ok(msg);
        }

        [HttpPost("{id}/log")]
        public async Task<ActionResult<object>> AddToLog(string id, [FromBody] AddRecipeRequest request)
        {
            var (result, err) = await RecipeService.AddToLogAsync(id, request);
            if (err != null)
                return err.Contains("Nincs") ? NotFound(err) : BadRequest(err);
            return Ok(result);
        }

        [HttpGet("{id}")]
        public async Task<ActionResult<RecipeDetail>> GetById(string id)
        {
            var (recipe, err) = await RecipeService.GetByIdAsync(id);
            if (err != null) return NotFound(err);
            return Ok(recipe);
        }

        // --- Legacy aliases ---

        [HttpGet("kategoriak")]
        public List<RecipeCategory> CategoriesLegacy() => Categories();

        [HttpGet("kaloria-tartomanyok")]
        public List<CalorieRange> CalorieBandsLegacy() => CalorieBands();

        [HttpGet("kereso")]
        public Task<ActionResult<List<RecipeListItem>>> SearchLegacy([FromQuery] string keresoszo) =>
            Search(keresoszo);

        [HttpGet("kategoria/{*kategoria_id}")]
        public Task<ActionResult<List<RecipeListItem>>> ByCategoryLegacy(string kategoria_id) =>
            ByCategory(kategoria_id);

        [HttpGet("kaloria")]
        public Task<ActionResult<List<RecipeListItem>>> ByCaloriesLegacy([FromQuery] int min, [FromQuery] int max) =>
            ByCalories(min, max);

        [HttpGet("felfedezes")]
        public Task<ActionResult<List<RecipeListItem>>> DiscoverLegacy([FromQuery] int darab = 12) =>
            Discover(darab);

        [HttpGet("kedvencek")]
        public List<RecipeListItem> FavoritesLegacy() => Favorites();

        [HttpPost("kedvencek/{recept_id}")]
        public Task<ActionResult<RecipeListItem>> AddFavoriteLegacy(string recept_id) =>
            AddFavorite(recept_id);

        [HttpDelete("kedvencek/{recept_id}")]
        public ActionResult<string> RemoveFavoriteLegacy(string recept_id) =>
            RemoveFavorite(recept_id);

        [HttpPost("{recept_id}/naplohoz-ad")]
        public Task<ActionResult<object>> AddToLogLegacy(string recept_id, [FromBody] AddRecipeRequest keres) =>
            AddToLog(recept_id, keres);
    }
}
