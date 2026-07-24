using Microsoft.AspNetCore.Mvc;
using FitnessBackend.Models;
using FitnessBackend.Services;

namespace FitnessBackend.Controllers
{
    [ApiController]
    [Route("api/workout")]
    public class WorkoutController : ControllerBase
    {
        private static WorkoutSession? activeWorkout = null;
        private static List<WorkoutSession> workoutHistory = new();

        public static void LoadOnStartup()
        {
            DataStore.Load(workoutHistory, ref activeWorkout);
        }

        private static int NextHistoryId()
        {
            return workoutHistory.Count == 0 ? 1 : workoutHistory.Max(w => w.Id) + 1;
        }

        [HttpPost("inditas-rutinbol")]
        public ActionResult<WorkoutSession> StartFromPlan([FromBody] Plan plan)
        {
            if (activeWorkout != null)
                return BadRequest("Mar fut egy edzes! Eloszor fejezd be vagy dobd el.");

            activeWorkout = new WorkoutSession
            {
                Id = 0,
                Title = plan.Title,
                StartTime = DateTime.Now,
                IsActive = true,
                Exercises = Plan.ExercisesForStart(plan).Select(exercise =>
                {
                    if (exercise.Sets.Count == 0)
                        exercise.Sets = WorkoutService.CreateDefaultSets(plan.Difficulty);

                    if (plan.ExerciseTemplates.Count == 0)
                        WorkoutService.FillPreviousData(exercise, workoutHistory);

                    return exercise;
                }).ToList()
            };

            DataStore.SaveActive(activeWorkout);
            return Ok(activeWorkout);
        }

        [HttpPost("inditas-rutinbol/{plan_id}")]
        public ActionResult<WorkoutSession> StartSavedPlan(string plan_id)
        {
            var plan = PlanStore.SavedPlans
                .FirstOrDefault(p => p.Id.Equals(plan_id, StringComparison.OrdinalIgnoreCase));

            if (plan == null)
                return NotFound("Nincs ilyen mentett rutin.");

            return StartFromPlan(plan);
        }

        [HttpPost("uj-ures-edzes")]
        public ActionResult<WorkoutSession> StartEmptyWorkout()
        {
            if (activeWorkout != null)
                return BadRequest("Mar fut egy edzes! Eloszor fejezd be vagy dobd el.");

            activeWorkout = new WorkoutSession
            {
                Id = 0,
                Title = "Empty Workout",
                StartTime = DateTime.Now,
                IsActive = true,
                Exercises = new List<LoggedExercise>()
            };

            DataStore.SaveActive(activeWorkout);
            return Ok(activeWorkout);
        }

        [HttpGet("aktiv")]
        public ActionResult<WorkoutSession> GetActiveWorkout()
        {
            if (activeWorkout == null)
                return NotFound("Nincs futó edzés. Indíts egyet: POST /api/workout/uj-ures-edzes");

            return Ok(activeWorkout);
        }

        [HttpPut("aktiv")]
        public ActionResult<WorkoutSession> UpdateActiveWorkout([FromBody] EdzesModositasKeres update)
        {
            if (activeWorkout == null)
                return NotFound("Nincs futó edzés.");

            if (!string.IsNullOrWhiteSpace(update.Title))
                activeWorkout.Title = update.Title;

            DataStore.SaveActive(activeWorkout);
            return Ok(activeWorkout);
        }

        [HttpGet("aktiv/gyakorlat/{exercise_id}")]
        public ActionResult<LoggedExercise> GetExercise(string exercise_id)
        {
            if (activeWorkout == null)
                return NotFound("Nincs futó edzés.");

            var exercise = activeWorkout.Exercises
                .FirstOrDefault(g => g.ExerciseId == exercise_id);

            if (exercise == null)
                return NotFound($"Nincs ilyen gyakorlat az edzesben: {exercise_id}");

            return Ok(exercise);
        }

        [HttpPost("aktiv/gyakorlat-hozzaadas")]
        public ActionResult<LoggedExercise> AddExercise([FromBody] LoggedExercise newExercise)
        {
            if (activeWorkout == null)
                return NotFound("Nincs futó edzés.");

            if (string.IsNullOrWhiteSpace(newExercise.ExerciseId))
                return BadRequest("ExerciseId kötelező.");

            var existing = activeWorkout.Exercises
                .FirstOrDefault(g => g.ExerciseId == newExercise.ExerciseId);

            if (existing != null)
                return Ok(existing);

            var added = new LoggedExercise
            {
                ExerciseId = newExercise.ExerciseId,
                ExerciseName = newExercise.ExerciseName,
                Sets = newExercise.Sets ?? new List<LoggedSet>()
            };

            activeWorkout.Exercises.Add(added);
            DataStore.SaveActive(activeWorkout);
            return Ok(added);
        }

        [HttpDelete("aktiv/gyakorlat/{exercise_id}")]
        public ActionResult<string> RemoveExercise(string exercise_id)
        {
            if (activeWorkout == null)
                return NotFound("Nincs futó edzés.");

            var exercise = activeWorkout.Exercises
                .FirstOrDefault(g => g.ExerciseId == exercise_id);

            if (exercise == null)
                return NotFound($"Nincs ilyen gyakorlat az edzesben: {exercise_id}");

            activeWorkout.Exercises.Remove(exercise);
            DataStore.SaveActive(activeWorkout);
            return Ok($"Gyakorlat torolve: {exercise.ExerciseName}");
        }

        [HttpPut("aktiv/gyakorlat/{exercise_id}")]
        public ActionResult<LoggedExercise> UpdateExercise(string exercise_id, [FromBody] LoggedExercise updated)
        {
            if (activeWorkout == null)
                return NotFound("Nincs futó edzés.");

            var exercise = activeWorkout.Exercises
                .FirstOrDefault(g => g.ExerciseId == exercise_id);

            if (exercise == null)
                return NotFound($"Nincs ilyen gyakorlat az edzesben: {exercise_id}");

            if (!string.IsNullOrWhiteSpace(updated.ExerciseName))
                exercise.ExerciseName = updated.ExerciseName;

            if (updated.Sets != null)
                exercise.Sets = updated.Sets;

            DataStore.SaveActive(activeWorkout);
            return Ok(exercise);
        }

        [HttpPut("aktiv/gyakorlat/{exercise_id}/sorozatok")]
        public ActionResult<LoggedExercise> ReplaceSets(string exercise_id, [FromBody] List<LoggedSet> sets)
        {
            if (activeWorkout == null)
                return NotFound("Nincs futó edzés.");

            var exercise = activeWorkout.Exercises
                .FirstOrDefault(g => g.ExerciseId == exercise_id);

            if (exercise == null)
                return NotFound($"Nincs ilyen gyakorlat az edzesben: {exercise_id}");

            exercise.Sets = sets;
            DataStore.SaveActive(activeWorkout);
            return Ok(exercise);
        }

        [HttpPost("aktiv/gyakorlat/{exercise_id}/sorozat")]
        public ActionResult<LoggedSet> AddSet(string exercise_id, [FromBody] LoggedSet newSet)
        {
            if (activeWorkout == null)
                return NotFound("Nincs futó edzés.");

            var exercise = activeWorkout.Exercises
                .FirstOrDefault(g => g.ExerciseId == exercise_id);

            if (exercise == null)
                return NotFound($"Nincs ilyen gyakorlat az edzesben: {exercise_id}");

            if (newSet.SetNumber == 0)
                newSet.SetNumber = exercise.Sets.Count + 1;

            exercise.Sets.Add(newSet);
            DataStore.SaveActive(activeWorkout);
            return Ok(newSet);
        }

        [HttpPut("aktiv/gyakorlat/{exercise_id}/sorozat/{set_number}")]
        public ActionResult<LoggedSet> UpdateSet(string exercise_id, int set_number, [FromBody] LoggedSet updated)
        {
            if (activeWorkout == null)
                return NotFound("Nincs futó edzés.");

            var exercise = activeWorkout.Exercises
                .FirstOrDefault(g => g.ExerciseId == exercise_id);

            if (exercise == null)
                return NotFound($"Nincs ilyen gyakorlat az edzesben: {exercise_id}");

            var set = exercise.Sets.FirstOrDefault(s => s.SetNumber == set_number);

            if (set == null)
                return NotFound($"Nincs ilyen sorozat: {set_number}");

            set.Weight = updated.Weight;
            set.Reps = updated.Reps;
            set.Rpe = updated.Rpe;
            set.TargetReps = updated.TargetReps;

            DataStore.SaveActive(activeWorkout);
            return Ok(set);
        }

        [HttpPost("aktiv/gyakorlat/{exercise_id}/sorozat/{set_number}/pipa")]
        public ActionResult<LoggedSet> CheckSet(
            string exercise_id,
            int set_number,
            [FromBody] LoggedSet? entered = null)
        {
            if (activeWorkout == null)
                return NotFound("Nincs futó edzés.");

            var exercise = activeWorkout.Exercises
                .FirstOrDefault(g => g.ExerciseId == exercise_id);

            if (exercise == null)
                return NotFound($"Nincs ilyen gyakorlat az edzesben: {exercise_id}");

            var set = exercise.Sets.FirstOrDefault(s => s.SetNumber == set_number);

            if (set == null)
                return NotFound($"Nincs ilyen sorozat: {set_number}");

            if (entered != null)
            {
                set.Weight = entered.Weight;
                set.Reps = entered.Reps;
                set.Rpe = entered.Rpe;
            }

            set.IsDone = true;
            DataStore.SaveActive(activeWorkout);
            return Ok(set);
        }

        [HttpDelete("aktiv/gyakorlat/{exercise_id}/sorozat/{set_number}/pipa")]
        public ActionResult<LoggedSet> UncheckSet(string exercise_id, int set_number)
        {
            if (activeWorkout == null)
                return NotFound("Nincs futó edzés.");

            var exercise = activeWorkout.Exercises
                .FirstOrDefault(g => g.ExerciseId == exercise_id);

            if (exercise == null)
                return NotFound($"Nincs ilyen gyakorlat az edzesben: {exercise_id}");

            var set = exercise.Sets.FirstOrDefault(s => s.SetNumber == set_number);

            if (set == null)
                return NotFound($"Nincs ilyen sorozat: {set_number}");

            set.IsDone = false;
            DataStore.SaveActive(activeWorkout);
            return Ok(set);
        }

        [HttpDelete("aktiv/gyakorlat/{exercise_id}/sorozat/{set_number}")]
        public ActionResult<string> DeleteSet(string exercise_id, int set_number)
        {
            if (activeWorkout == null)
                return NotFound("Nincs futó edzés.");

            var exercise = activeWorkout.Exercises
                .FirstOrDefault(g => g.ExerciseId == exercise_id);

            if (exercise == null)
                return NotFound($"Nincs ilyen gyakorlat az edzesben: {exercise_id}");

            var set = exercise.Sets.FirstOrDefault(s => s.SetNumber == set_number);

            if (set == null)
                return NotFound($"Nincs ilyen sorozat: {set_number}");

            exercise.Sets.Remove(set);
            DataStore.SaveActive(activeWorkout);
            return Ok($"Sorozat torolve: #{set_number}");
        }

        [HttpPost("aktiv/befejezes")]
        public ActionResult<WorkoutSession> FinishActiveWorkout()
        {
            if (activeWorkout == null)
                return NotFound("Nincs futó edzés.");

            activeWorkout.DurationSeconds = activeWorkout.ElapsedSeconds;
            activeWorkout.IsActive = false;
            activeWorkout.Id = NextHistoryId();

            workoutHistory.Add(activeWorkout);
            var saved = activeWorkout;
            activeWorkout = null;

            DataStore.SaveHistory(workoutHistory);
            DataStore.ClearActive();

            return Ok(saved);
        }

        [HttpPost("aktiv/befejezes-es-megosztas")]
        public ActionResult<object> FinishAndShare([FromBody] ShareRequest shareRequest)
        {
            if (activeWorkout == null)
                return NotFound("Nincs futó edzés.");

            activeWorkout.DurationSeconds = activeWorkout.ElapsedSeconds;
            activeWorkout.IsActive = false;
            activeWorkout.Id = NextHistoryId();
            workoutHistory.Add(activeWorkout);

            shareRequest.Workout = activeWorkout;
            activeWorkout = null;

            DataStore.SaveHistory(workoutHistory);
            DataStore.ClearActive();

            var (post, error) = CommunityStore.CreatePost(shareRequest);

            if (error != null)
                return BadRequest(error);

            return Ok(new
            {
                message = "Edzes mentve es megosztva a kozossegiben!",
                workout = shareRequest.Workout,
                post
            });
        }

        [HttpPost("history/{workout_id:int}/megosztas")]
        public ActionResult<object> ShareHistoryWorkout(int workout_id, [FromBody] ShareRequest shareRequest)
        {
            var workout = workoutHistory.FirstOrDefault(w => w.Id == workout_id);
            if (workout == null)
                return NotFound("Nincs ilyen befejezett edzes.");

            shareRequest.Workout = workout;
            var (post, error) = CommunityStore.CreatePost(shareRequest);

            if (error != null)
                return BadRequest(error);

            return Ok(new
            {
                message = "Befejezett edzes megosztva a kozossegiben!",
                workout,
                post
            });
        }

        [HttpDelete("aktiv")]
        public string DiscardActiveWorkout()
        {
            if (activeWorkout == null)
                return "Nincs futó edzés, amit el lehetne vetni.";

            activeWorkout = null;
            DataStore.ClearActive();
            return "Az edzés elvetve.";
        }

        [HttpGet("history")]
        public List<WorkoutSession> GetHistory()
        {
            return workoutHistory;
        }

        [HttpPut("history/{workout_id:int}")]
        public ActionResult<WorkoutSession> UpdateHistoryWorkout(int workout_id, [FromBody] WorkoutSession updated)
        {
            var workout = workoutHistory.FirstOrDefault(w => w.Id == workout_id);
            if (workout == null)
                return NotFound("Nincs ilyen befejezett edzes.");

            if (!string.IsNullOrWhiteSpace(updated.Title))
                workout.Title = updated.Title;

            if (updated.Exercises != null)
                workout.Exercises = updated.Exercises;

            DataStore.SaveHistory(workoutHistory);
            return Ok(workout);
        }

        [HttpDelete("history/{workout_id:int}")]
        public ActionResult<string> DeleteHistoryWorkout(int workout_id)
        {
            var workout = workoutHistory.FirstOrDefault(w => w.Id == workout_id);
            if (workout == null)
                return NotFound("Nincs ilyen befejezett edzes.");

            workoutHistory.Remove(workout);
            DataStore.SaveHistory(workoutHistory);
            return Ok($"Edzes torolve: {workout.Title}");
        }

        [HttpGet("progress-settings")]
        public ProgressSettings GetProgressSettings()
        {
            return PlanStore.Progress;
        }

        [HttpPut("progress-settings")]
        public ProgressSettings SaveProgressSettings([FromBody] ProgressSettings settings)
        {
            PlanStore.Progress = settings;
            DataStore.SaveProgress();
            return PlanStore.Progress;
        }

        [HttpGet("progresszio-beallitas")]
        public ProgressSettings GetProgressSettingsLegacy()
        {
            return GetProgressSettings();
        }

        [HttpPut("progresszio-beallitas")]
        public ProgressSettings SaveProgressSettingsLegacy([FromBody] ProgressSettings settings)
        {
            return SaveProgressSettings(settings);
        }

        [HttpGet("diagnosztika")]
        public ActionResult<object> Diagnostics()
        {
            return Ok(DataStore.Diagnostics(workoutHistory.Count, activeWorkout != null));
        }

        [HttpPost("kovetkezo-het/elonezet")]
        public ActionResult<NextWeekResponse> PreviewNextWeek([FromBody] NextWeekRequest request)
        {
            var previousWorkout = workoutHistory.FirstOrDefault(w => w.Id == request.PreviousWorkoutId);
            if (previousWorkout == null)
                return NotFound("Nincs ilyen befejezett edzes az elozmenyekben.");

            var settings = request.ProgressSettings ?? PlanStore.Progress;
            var response = WorkoutService.GenerateNextWeek(previousWorkout, settings);
            return Ok(response);
        }

        [HttpPost("kovetkezo-het/inditas")]
        public ActionResult<WorkoutSession> StartNextWeek([FromBody] NextWeekRequest request)
        {
            if (activeWorkout != null)
                return BadRequest("Mar fut egy edzes! Eloszor fejezd be vagy dobd el.");

            var previousWorkout = workoutHistory.FirstOrDefault(w => w.Id == request.PreviousWorkoutId);
            if (previousWorkout == null)
                return NotFound("Nincs ilyen befejezett edzes az elozmenyekben.");

            var settings = request.ProgressSettings ?? PlanStore.Progress;
            var generated = WorkoutService.GenerateNextWeek(previousWorkout, settings);

            activeWorkout = generated.SuggestedWorkout;
            activeWorkout.IsActive = true;
            activeWorkout.StartTime = DateTime.Now;

            DataStore.SaveActive(activeWorkout);
            return Ok(activeWorkout);
        }

        [HttpPost("finish")]
        public string FinishWorkout([FromBody] WorkoutSession workout)
        {
            workout.Id = workoutHistory.Count + 1;
            workout.IsActive = false;

            if (workout.StartTime == DateTime.MinValue)
                workout.StartTime = DateTime.Now;

            if (workout.DurationSeconds == 0)
                workout.DurationSeconds = workout.ElapsedSeconds;

            workoutHistory.Add(workout);
            DataStore.SaveHistory(workoutHistory);
            return $"Sikeres mentés! Az edzésed elmentve {workout.Id} azonosítóval. Összesen {workout.Exercises.Count} gyakorlatot végeztél.";
        }
    }
}
