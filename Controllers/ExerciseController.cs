using Microsoft.AspNetCore.Mvc;
using FitnessBackend.Models;
using FitnessBackend.Services;

namespace FitnessBackend.Controllers
{
    [ApiController]
    [Route("api/exercise")]
    public class ExerciseController : ControllerBase
    {
        [HttpGet("download-all")]
        public async Task<string> DownloadAll() =>
            await ExerciseService.DownloadAllAsync();

        [HttpGet("muscles")]
        public List<string> Muscles() => ExerciseService.MuscleGroups;

        [HttpGet("equipment")]
        public List<string> Equipment() => ExerciseService.EquipmentTypes;

        [HttpGet("search")]
        public async Task<List<Exercise>> Search(
            [FromQuery] string? q = null,
            [FromQuery] string? muscle = null,
            [FromQuery] string? equipment = null,
            [FromQuery] string? category = null) =>
            await ExerciseService.SearchAsync(q, muscle, equipment, category);

        // Legacy aliases used by older Flutter builds
        [HttpGet("kereso")]
        public Task<List<Exercise>> SearchLegacy([FromQuery] string? keresoszo = null) =>
            ExerciseService.SearchAsync(q: keresoszo);

        [HttpGet("kereses")]
        public Task<List<Exercise>> SearchLegacyFull(
            string? kereses = null,
            string? izomcsoport = null,
            string? felszereles = null,
            string? kategoria = null) =>
            ExerciseService.SearchAsync(kereses, izomcsoport, felszereles, kategoria);

        [HttpGet("izomcsoportok")]
        public List<string> MusclesLegacy() => ExerciseService.MuscleGroups;

        [HttpGet("felszereles-tipusok")]
        public List<string> EquipmentLegacy() => ExerciseService.EquipmentTypes;

        [HttpGet]
        public async Task<List<Exercise>> GetAll() =>
            await ExerciseService.GetAllAsync();

        [HttpGet("{id}")]
        public async Task<ActionResult<Exercise>> GetById(string id)
        {
            var exercise = await ExerciseService.GetByIdAsync(id);
            if (exercise == null)
                return NotFound($"Nincs ilyen gyakorlat: {id}");
            return Ok(exercise);
        }

        [HttpGet("category/{category}")]
        public async Task<List<Exercise>> ByCategory(string category) =>
            await ExerciseService.ByCategoryAsync(category);

        [HttpGet("kategoria/{category}")]
        public Task<List<Exercise>> ByCategoryLegacy(string category) =>
            ExerciseService.ByCategoryAsync(category);
    }
}
