using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using FitnessBackend.Models;
using FitnessBackend.Services;

namespace FitnessBackend.Controllers
{
    [ApiController]
    [Route("api/plan")]
    [Authorize]
    public class PlanController : ControllerBase
    {
        [HttpPost("ai-generate")]
        public async Task<ActionResult<List<Plan>>> AiGenerate([FromBody] AiGenerateRequest request)
        {
            var auth = CurrentUser.RequireUser(this, out _);
            if (auth != null) return auth;

            var plans = await PlanService.GenerateAiPlansAsync(request);

            if (plans.Count == 0)
                return BadRequest("Nincs gyakorlat ehhez a szureshez. Probald mas kategoriaval!");

            return Ok(plans);
        }

        [HttpGet("templates")]
        [AllowAnonymous]
        public ActionResult<List<Plan>> Templates()
        {
            return Ok(new List<Plan>());
        }

        [HttpPut("{id}")]
        public ActionResult<Plan> UpdatePlan(string id, [FromBody] Plan updated)
        {
            var auth = CurrentUser.RequireUser(this, out var user);
            if (auth != null) return auth;

            var plan = PlanStore.SavedPlans
                .FirstOrDefault(p => p.Id.Equals(id, StringComparison.OrdinalIgnoreCase));

            if (plan == null || !Owns(plan, user))
                return NotFound("Nincs ilyen mentett rutin.");

            if (!string.IsNullOrWhiteSpace(updated.Title))
                plan.Title = updated.Title;

            if (updated.ExerciseIds != null && updated.ExerciseIds.Count > 0)
            {
                plan.ExerciseIds = updated.ExerciseIds;
                plan.ExerciseNames = updated.ExerciseNames ?? updated.ExerciseIds;
            }

            if (updated.ExerciseTemplates != null && updated.ExerciseTemplates.Count > 0)
                plan.ExerciseTemplates = updated.ExerciseTemplates;

            if (!string.IsNullOrWhiteSpace(updated.Difficulty))
                plan.Difficulty = updated.Difficulty;

            if (!string.IsNullOrWhiteSpace(updated.TargetMuscle))
                plan.TargetMuscle = updated.TargetMuscle;

            plan.CreatorName = user;
            DataStore.SavePlans();
            return Ok(plan);
        }

        [HttpPost("save")]
        public ActionResult<Plan> SavePlan([FromBody] Plan newPlan)
        {
            var auth = CurrentUser.RequireUser(this, out var user);
            if (auth != null) return auth;

            newPlan.Id = $"rutin_{Random.Shared.Next(100000, 999999)}";
            newPlan.CreatorName = user;

            PlanStore.SavedPlans.Add(newPlan);
            DataStore.SavePlans();
            return Ok(newPlan);
        }

        [HttpGet("share/{id}")]
        [AllowAnonymous]
        public ActionResult<Plan> GetSharedPlan(string id)
        {
            var plan = PlanStore.SavedPlans
                .FirstOrDefault(p => p.Id.Equals(id, StringComparison.OrdinalIgnoreCase));

            if (plan == null)
                return NotFound("Ez az edzesterv nem talalhato. Ellenorizd a megosztasi kodot!");

            return Ok(plan);
        }

        [HttpGet("mine")]
        public ActionResult<List<Plan>> MyPlans()
        {
            var auth = CurrentUser.RequireUser(this, out var user);
            if (auth != null) return auth;

            return Ok(PlanStore.SavedPlans
                .Where(p => Owns(p, user))
                .ToList());
        }

        [HttpDelete("{id}")]
        public ActionResult<string> DeletePlan(string id)
        {
            var auth = CurrentUser.RequireUser(this, out var user);
            if (auth != null) return auth;

            var plan = PlanStore.SavedPlans
                .FirstOrDefault(p => p.Id.Equals(id, StringComparison.OrdinalIgnoreCase));

            if (plan == null || !Owns(plan, user))
                return NotFound("Nincs ilyen mentett rutin.");

            PlanStore.SavedPlans.Remove(plan);
            DataStore.SavePlans();
            return Ok($"Rutin torolve: {plan.Title}");
        }

        private static bool Owns(Plan plan, string user) =>
            plan.CreatorName.Equals(user, StringComparison.OrdinalIgnoreCase);
    }
}
