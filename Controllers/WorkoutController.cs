using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using FitnessBackend.Models;
using FitnessBackend.Services;

namespace FitnessBackend.Controllers
{
    [ApiController]
    [Route("api/workout")]
    [Authorize]
    public class WorkoutController : ControllerBase
    {
        private static readonly Dictionary<string, WorkoutSession> ActiveByUser = new(StringComparer.OrdinalIgnoreCase);
        private static List<WorkoutSession> workoutHistory = new();

        private readonly CommunityDbService _community;

        public WorkoutController(CommunityDbService community) => _community = community;

        public static void LoadOnStartup()
        {
            DataStore.Load(workoutHistory, ActiveByUser);
        }

        /// <summary>Public read of another user's history (community profiles — test mode).</summary>
        public static List<WorkoutSession> HistoryForUserPublic(string userName) =>
            workoutHistory
                .Where(w => w.UserName.Equals(userName, StringComparison.OrdinalIgnoreCase))
                .OrderByDescending(w => w.StartTime)
                .ToList();

        public static void AssignLegacyOwner(string ownerUserName)
        {
            if (string.IsNullOrWhiteSpace(ownerUserName)) return;
            var changed = false;
            foreach (var w in workoutHistory.Where(w => string.IsNullOrWhiteSpace(w.UserName)))
            {
                w.UserName = ownerUserName;
                changed = true;
            }
            if (ActiveByUser.Remove("_legacy", out var legacyActive))
            {
                legacyActive.UserName = ownerUserName;
                ActiveByUser[ownerUserName] = legacyActive;
                changed = true;
            }
            if (ActiveByUser.Remove("", out var emptyActive))
            {
                emptyActive.UserName = ownerUserName;
                ActiveByUser[ownerUserName] = emptyActive;
                changed = true;
            }
            var legacyPlanNames = new HashSet<string>(StringComparer.OrdinalIgnoreCase)
                { "", "Anonim", "Sajat terv", "Saját terv", "Hevy AI Trainer", "AI Edzesterv" };
            foreach (var p in PlanStore.SavedPlans.Where(p => legacyPlanNames.Contains(p.CreatorName ?? "")))
            {
                p.CreatorName = ownerUserName;
                changed = true;
            }
            if (changed)
            {
                DataStore.SaveHistory(workoutHistory);
                DataStore.SaveActiveMap(ActiveByUser);
                DataStore.SavePlans();
                Console.WriteLine($"[Workout] Assigned legacy workouts/plans to {ownerUserName}");
            }
        }

        /// <summary>
        /// One-time: move ALL workouts/plans to <paramref name="ownerUserName"/>.
        /// Fixes Phase-2 fallback that wrongly attached shared JSON to the first registered user.
        /// </summary>
        public static void ConsolidateAllToOwnerOnce(string ownerUserName)
        {
            if (string.IsNullOrWhiteSpace(ownerUserName)) return;

            var dataDir = Environment.GetEnvironmentVariable("DATA_DIR");
            if (string.IsNullOrWhiteSpace(dataDir))
                dataDir = Path.Combine(Directory.GetCurrentDirectory(), "data");
            Directory.CreateDirectory(dataDir);
            var marker = Path.Combine(dataDir, ".legacy_consolidated_v1");
            if (System.IO.File.Exists(marker)) return;

            foreach (var w in workoutHistory)
                w.UserName = ownerUserName;

            var actives = ActiveByUser.Values.ToList();
            ActiveByUser.Clear();
            foreach (var session in actives)
            {
                session.UserName = ownerUserName;
                ActiveByUser[ownerUserName] = session;
            }

            foreach (var p in PlanStore.SavedPlans)
                p.CreatorName = ownerUserName;

            DataStore.SaveHistory(workoutHistory);
            DataStore.SaveActiveMap(ActiveByUser);
            DataStore.SavePlans();
            System.IO.File.WriteAllText(marker, $"{DateTime.UtcNow:O}|{ownerUserName}");
            Console.WriteLine($"[Workout] Consolidated ALL workouts/plans → {ownerUserName}");
        }

        private static int NextHistoryId() => workoutHistory.Count == 0 ? 1 : workoutHistory.Max(w => w.Id) + 1;

        private List<WorkoutSession> HistoryFor(string user) =>
            workoutHistory.Where(w => w.UserName.Equals(user, StringComparison.OrdinalIgnoreCase)).ToList();

        private WorkoutSession? GetActive(string user) =>
            ActiveByUser.TryGetValue(user, out var w) ? w : null;

        private void SetActive(string user, WorkoutSession? session)
        {
            if (session == null) ActiveByUser.Remove(user);
            else { session.UserName = user; ActiveByUser[user] = session; }
            DataStore.SaveActiveMap(ActiveByUser);
        }

        [HttpPost("inditas-rutinbol")]
        public ActionResult<WorkoutSession> StartFromPlan([FromBody] Plan plan)
        {
            var auth = CurrentUser.RequireUser(this, out var user);
            if (auth != null) return auth;

            return StartWorkoutFromPlan(user, plan);
        }

        [HttpPost("inditas-rutinbol/{plan_id}")]
        public ActionResult<WorkoutSession> StartSavedPlan(string plan_id)
        {
            var auth = CurrentUser.RequireUser(this, out var user);
            if (auth != null) return auth;

            var plan = PlanStore.SavedPlans
                .FirstOrDefault(p => p.Id.Equals(plan_id, StringComparison.OrdinalIgnoreCase));

            if (plan == null)
                return NotFound("Nincs ilyen mentett rutin.");

            if (!plan.CreatorName.Equals(user, StringComparison.OrdinalIgnoreCase))
                return NotFound("Nincs ilyen mentett rutin.");

            return StartWorkoutFromPlan(user, plan);
        }

        private ActionResult<WorkoutSession> StartWorkoutFromPlan(string user, Plan plan)
        {
            if (GetActive(user) != null)
                return BadRequest("Mar fut egy edzes! Eloszor fejezd be vagy dobd el.");

            var userHistory = HistoryFor(user);
            var session = new WorkoutSession
            {
                Id = 0,
                UserName = user,
                Title = plan.Title,
                StartTime = DateTime.Now,
                IsActive = true,
                Exercises = Plan.ExercisesForStart(plan).Select(exercise =>
                {
                    if (exercise.Sets.Count == 0)
                        exercise.Sets = WorkoutService.CreateDefaultSets(plan.Difficulty);

                    if (plan.ExerciseTemplates.Count == 0)
                        WorkoutService.FillPreviousData(exercise, userHistory);

                    return exercise;
                }).ToList()
            };

            SetActive(user, session);
            return Ok(session);
        }

        [HttpPost("uj-ures-edzes")]
        public ActionResult<WorkoutSession> StartEmptyWorkout()
        {
            var auth = CurrentUser.RequireUser(this, out var user);
            if (auth != null) return auth;

            if (GetActive(user) != null)
                return BadRequest("Mar fut egy edzes! Eloszor fejezd be vagy dobd el.");

            var session = new WorkoutSession
            {
                Id = 0,
                UserName = user,
                Title = "Empty Workout",
                StartTime = DateTime.Now,
                IsActive = true,
                Exercises = new List<LoggedExercise>()
            };

            SetActive(user, session);
            return Ok(session);
        }

        [HttpGet("aktiv")]
        public ActionResult<WorkoutSession> GetActiveWorkout()
        {
            var auth = CurrentUser.RequireUser(this, out var user);
            if (auth != null) return auth;

            var activeWorkout = GetActive(user);
            if (activeWorkout == null)
                return NotFound("Nincs futó edzés. Indíts egyet: POST /api/workout/uj-ures-edzes");

            return Ok(activeWorkout);
        }

        [HttpPut("aktiv")]
        public ActionResult<WorkoutSession> UpdateActiveWorkout([FromBody] EdzesModositasKeres update)
        {
            var auth = CurrentUser.RequireUser(this, out var user);
            if (auth != null) return auth;

            var activeWorkout = GetActive(user);
            if (activeWorkout == null)
                return NotFound("Nincs futó edzés.");

            if (!string.IsNullOrWhiteSpace(update.Title))
                activeWorkout.Title = update.Title;

            SetActive(user, activeWorkout);
            return Ok(activeWorkout);
        }

        [HttpGet("aktiv/gyakorlat/{exercise_id}")]
        public ActionResult<LoggedExercise> GetExercise(string exercise_id)
        {
            var auth = CurrentUser.RequireUser(this, out var user);
            if (auth != null) return auth;

            var activeWorkout = GetActive(user);
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
            var auth = CurrentUser.RequireUser(this, out var user);
            if (auth != null) return auth;

            var activeWorkout = GetActive(user);
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
            SetActive(user, activeWorkout);
            return Ok(added);
        }

        [HttpDelete("aktiv/gyakorlat/{exercise_id}")]
        public ActionResult<string> RemoveExercise(string exercise_id)
        {
            var auth = CurrentUser.RequireUser(this, out var user);
            if (auth != null) return auth;

            var activeWorkout = GetActive(user);
            if (activeWorkout == null)
                return NotFound("Nincs futó edzés.");

            var exercise = activeWorkout.Exercises
                .FirstOrDefault(g => g.ExerciseId == exercise_id);

            if (exercise == null)
                return NotFound($"Nincs ilyen gyakorlat az edzesben: {exercise_id}");

            activeWorkout.Exercises.Remove(exercise);
            SetActive(user, activeWorkout);
            return Ok($"Gyakorlat torolve: {exercise.ExerciseName}");
        }

        [HttpPut("aktiv/gyakorlat/{exercise_id}")]
        public ActionResult<LoggedExercise> UpdateExercise(string exercise_id, [FromBody] LoggedExercise updated)
        {
            var auth = CurrentUser.RequireUser(this, out var user);
            if (auth != null) return auth;

            var activeWorkout = GetActive(user);
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

            SetActive(user, activeWorkout);
            return Ok(exercise);
        }

        [HttpPut("aktiv/gyakorlat/{exercise_id}/sorozatok")]
        public ActionResult<LoggedExercise> ReplaceSets(string exercise_id, [FromBody] List<LoggedSet> sets)
        {
            var auth = CurrentUser.RequireUser(this, out var user);
            if (auth != null) return auth;

            var activeWorkout = GetActive(user);
            if (activeWorkout == null)
                return NotFound("Nincs futó edzés.");

            var exercise = activeWorkout.Exercises
                .FirstOrDefault(g => g.ExerciseId == exercise_id);

            if (exercise == null)
                return NotFound($"Nincs ilyen gyakorlat az edzesben: {exercise_id}");

            exercise.Sets = sets;
            SetActive(user, activeWorkout);
            return Ok(exercise);
        }

        [HttpPost("aktiv/gyakorlat/{exercise_id}/sorozat")]
        public ActionResult<LoggedSet> AddSet(string exercise_id, [FromBody] LoggedSet newSet)
        {
            var auth = CurrentUser.RequireUser(this, out var user);
            if (auth != null) return auth;

            var activeWorkout = GetActive(user);
            if (activeWorkout == null)
                return NotFound("Nincs futó edzés.");

            var exercise = activeWorkout.Exercises
                .FirstOrDefault(g => g.ExerciseId == exercise_id);

            if (exercise == null)
                return NotFound($"Nincs ilyen gyakorlat az edzesben: {exercise_id}");

            if (newSet.SetNumber == 0)
                newSet.SetNumber = exercise.Sets.Count + 1;

            exercise.Sets.Add(newSet);
            SetActive(user, activeWorkout);
            return Ok(newSet);
        }

        [HttpPut("aktiv/gyakorlat/{exercise_id}/sorozat/{set_number}")]
        public ActionResult<LoggedSet> UpdateSet(string exercise_id, int set_number, [FromBody] LoggedSet updated)
        {
            var auth = CurrentUser.RequireUser(this, out var user);
            if (auth != null) return auth;

            var activeWorkout = GetActive(user);
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

            SetActive(user, activeWorkout);
            return Ok(set);
        }

        [HttpPost("aktiv/gyakorlat/{exercise_id}/sorozat/{set_number}/pipa")]
        public ActionResult<LoggedSet> CheckSet(
            string exercise_id,
            int set_number,
            [FromBody] LoggedSet? entered = null)
        {
            var auth = CurrentUser.RequireUser(this, out var user);
            if (auth != null) return auth;

            var activeWorkout = GetActive(user);
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
            SetActive(user, activeWorkout);
            return Ok(set);
        }

        [HttpDelete("aktiv/gyakorlat/{exercise_id}/sorozat/{set_number}/pipa")]
        public ActionResult<LoggedSet> UncheckSet(string exercise_id, int set_number)
        {
            var auth = CurrentUser.RequireUser(this, out var user);
            if (auth != null) return auth;

            var activeWorkout = GetActive(user);
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
            SetActive(user, activeWorkout);
            return Ok(set);
        }

        [HttpDelete("aktiv/gyakorlat/{exercise_id}/sorozat/{set_number}")]
        public ActionResult<string> DeleteSet(string exercise_id, int set_number)
        {
            var auth = CurrentUser.RequireUser(this, out var user);
            if (auth != null) return auth;

            var activeWorkout = GetActive(user);
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
            SetActive(user, activeWorkout);
            return Ok($"Sorozat torolve: #{set_number}");
        }

        [HttpPost("aktiv/befejezes")]
        public ActionResult<WorkoutSession> FinishActiveWorkout()
        {
            var auth = CurrentUser.RequireUser(this, out var user);
            if (auth != null) return auth;

            var activeWorkout = GetActive(user);
            if (activeWorkout == null)
                return NotFound("Nincs futó edzés.");

            activeWorkout.UserName = user;
            activeWorkout.DurationSeconds = activeWorkout.ElapsedSeconds;
            activeWorkout.IsActive = false;
            activeWorkout.Id = NextHistoryId();

            workoutHistory.Add(activeWorkout);
            var saved = activeWorkout;
            ActiveByUser.Remove(user);

            DataStore.SaveActiveMap(ActiveByUser);
            DataStore.SaveHistory(workoutHistory);

            return Ok(saved);
        }

        [HttpPost("aktiv/befejezes-es-megosztas")]
        public async Task<ActionResult<object>> FinishAndShare([FromBody] ShareRequest shareRequest)
        {
            var auth = CurrentUser.RequireUser(this, out var user);
            if (auth != null) return auth;

            var appUser = await _community.FindUserByNameAsync(user);
            if (appUser == null) return Unauthorized(new { error = "Bejelentkezés szükséges." });

            var activeWorkout = GetActive(user);
            if (activeWorkout == null)
                return NotFound("Nincs futó edzés.");

            activeWorkout.UserName = user;
            activeWorkout.DurationSeconds = activeWorkout.ElapsedSeconds;
            activeWorkout.IsActive = false;
            activeWorkout.Id = NextHistoryId();
            workoutHistory.Add(activeWorkout);

            shareRequest.UserName = user;
            shareRequest.Workout = activeWorkout;
            if (string.IsNullOrWhiteSpace(shareRequest.County))
                shareRequest.County = appUser.County;
            ActiveByUser.Remove(user);

            DataStore.SaveActiveMap(ActiveByUser);
            DataStore.SaveHistory(workoutHistory);

            var (post, error) = await _community.CreatePostAsync(appUser, shareRequest);

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
        public async Task<ActionResult<object>> ShareHistoryWorkout(int workout_id, [FromBody] ShareRequest shareRequest)
        {
            var auth = CurrentUser.RequireUser(this, out var user);
            if (auth != null) return auth;

            var appUser = await _community.FindUserByNameAsync(user);
            if (appUser == null) return Unauthorized(new { error = "Bejelentkezés szükséges." });

            var workout = workoutHistory.FirstOrDefault(w => w.Id == workout_id);
            if (workout == null)
                return NotFound("Nincs ilyen befejezett edzes.");

            if (!workout.UserName.Equals(user, StringComparison.OrdinalIgnoreCase))
                return NotFound("Nincs ilyen befejezett edzes.");

            shareRequest.UserName = user;
            shareRequest.Workout = workout;
            if (string.IsNullOrWhiteSpace(shareRequest.County))
                shareRequest.County = appUser.County;

            var (post, error) = await _community.CreatePostAsync(appUser, shareRequest);

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
        public ActionResult<string> DiscardActiveWorkout()
        {
            var auth = CurrentUser.RequireUser(this, out var user);
            if (auth != null) return auth;

            if (GetActive(user) == null)
                return Ok("Nincs futó edzés, amit el lehetne vetni.");

            SetActive(user, null);
            return Ok("Az edzés elvetve.");
        }

        [HttpGet("history")]
        public ActionResult<List<WorkoutSession>> GetHistory()
        {
            var auth = CurrentUser.RequireUser(this, out var user);
            if (auth != null) return auth;

            return Ok(HistoryFor(user));
        }

        /// <summary>Delete this user's workout history, active session, and saved plans.</summary>
        [HttpPost("clear-mine")]
        public ActionResult<object> ClearMine()
        {
            var auth = CurrentUser.RequireUser(this, out var user);
            if (auth != null) return auth;

            var removedHistory = workoutHistory.RemoveAll(w =>
                w.UserName.Equals(user, StringComparison.OrdinalIgnoreCase));
            SetActive(user, null);
            var removedPlans = PlanStore.SavedPlans.RemoveAll(p =>
                p.CreatorName.Equals(user, StringComparison.OrdinalIgnoreCase));

            DataStore.SaveHistory(workoutHistory);
            DataStore.SavePlans();

            return Ok(new
            {
                success = true,
                user,
                removedHistory,
                removedPlans,
                message = "A fiókod edzései és rutinjai törölve.",
            });
        }

        [HttpPut("history/{workout_id:int}")]
        public ActionResult<WorkoutSession> UpdateHistoryWorkout(int workout_id, [FromBody] WorkoutSession updated)
        {
            var auth = CurrentUser.RequireUser(this, out var user);
            if (auth != null) return auth;

            var workout = workoutHistory.FirstOrDefault(w => w.Id == workout_id);
            if (workout == null)
                return NotFound("Nincs ilyen befejezett edzes.");

            if (!workout.UserName.Equals(user, StringComparison.OrdinalIgnoreCase))
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
            var auth = CurrentUser.RequireUser(this, out var user);
            if (auth != null) return auth;

            var workout = workoutHistory.FirstOrDefault(w => w.Id == workout_id);
            if (workout == null)
                return NotFound("Nincs ilyen befejezett edzes.");

            if (!workout.UserName.Equals(user, StringComparison.OrdinalIgnoreCase))
                return NotFound("Nincs ilyen befejezett edzes.");

            workoutHistory.Remove(workout);
            DataStore.SaveHistory(workoutHistory);
            return Ok($"Edzes torolve: {workout.Title}");
        }

        [HttpGet("progress-settings")]
        public ActionResult<ProgressSettings> GetProgressSettings()
        {
            var auth = CurrentUser.RequireUser(this, out var user);
            if (auth != null) return auth;

            return Ok(PlanStore.Progress);
        }

        [HttpPut("progress-settings")]
        public ActionResult<ProgressSettings> SaveProgressSettings([FromBody] ProgressSettings settings)
        {
            var auth = CurrentUser.RequireUser(this, out var user);
            if (auth != null) return auth;

            PlanStore.Progress = settings;
            DataStore.SaveProgress();
            return Ok(PlanStore.Progress);
        }

        [HttpGet("progresszio-beallitas")]
        public ActionResult<ProgressSettings> GetProgressSettingsLegacy()
        {
            return GetProgressSettings();
        }

        [HttpPut("progresszio-beallitas")]
        public ActionResult<ProgressSettings> SaveProgressSettingsLegacy([FromBody] ProgressSettings settings)
        {
            return SaveProgressSettings(settings);
        }

        [AllowAnonymous]
        [HttpGet("diagnosztika")]
        public ActionResult<object> Diagnostics()
        {
            var byUser = workoutHistory
                .GroupBy(w => string.IsNullOrWhiteSpace(w.UserName) ? "(ures)" : w.UserName)
                .ToDictionary(g => g.Key, g => g.Count(), StringComparer.OrdinalIgnoreCase);
            var plansByUser = PlanStore.SavedPlans
                .GroupBy(p => string.IsNullOrWhiteSpace(p.CreatorName) ? "(ures)" : p.CreatorName)
                .ToDictionary(g => g.Key, g => g.Count(), StringComparer.OrdinalIgnoreCase);

            return Ok(new
            {
                baseDiag = DataStore.Diagnostics(workoutHistory.Count, ActiveByUser.Count > 0),
                edzesTulajdonosonkent = byUser,
                rutinTulajdonosonkent = plansByUser,
                aktivUserek = ActiveByUser.Keys.ToList(),
            });
        }

        [HttpPost("kovetkezo-het/elonezet")]
        public ActionResult<NextWeekResponse> PreviewNextWeek([FromBody] NextWeekRequest request)
        {
            var auth = CurrentUser.RequireUser(this, out var user);
            if (auth != null) return auth;

            var previousWorkout = workoutHistory.FirstOrDefault(w => w.Id == request.PreviousWorkoutId);
            if (previousWorkout == null)
                return NotFound("Nincs ilyen befejezett edzes az elozmenyekben.");

            if (!previousWorkout.UserName.Equals(user, StringComparison.OrdinalIgnoreCase))
                return NotFound("Nincs ilyen befejezett edzes az elozmenyekben.");

            var settings = request.ProgressSettings ?? PlanStore.Progress;
            var response = WorkoutService.GenerateNextWeek(previousWorkout, settings);
            return Ok(response);
        }

        [HttpPost("kovetkezo-het/inditas")]
        public ActionResult<WorkoutSession> StartNextWeek([FromBody] NextWeekRequest request)
        {
            var auth = CurrentUser.RequireUser(this, out var user);
            if (auth != null) return auth;

            if (GetActive(user) != null)
                return BadRequest("Mar fut egy edzes! Eloszor fejezd be vagy dobd el.");

            var previousWorkout = workoutHistory.FirstOrDefault(w => w.Id == request.PreviousWorkoutId);
            if (previousWorkout == null)
                return NotFound("Nincs ilyen befejezett edzes az elozmenyekben.");

            if (!previousWorkout.UserName.Equals(user, StringComparison.OrdinalIgnoreCase))
                return NotFound("Nincs ilyen befejezett edzes az elozmenyekben.");

            var settings = request.ProgressSettings ?? PlanStore.Progress;
            var generated = WorkoutService.GenerateNextWeek(previousWorkout, settings);

            var activeWorkout = generated.SuggestedWorkout;
            activeWorkout.UserName = user;
            activeWorkout.IsActive = true;
            activeWorkout.StartTime = DateTime.Now;

            SetActive(user, activeWorkout);
            return Ok(activeWorkout);
        }

        [HttpPost("finish")]
        public ActionResult<string> FinishWorkout([FromBody] WorkoutSession workout)
        {
            var auth = CurrentUser.RequireUser(this, out var user);
            if (auth != null) return auth;

            workout.UserName = user;
            workout.Id = NextHistoryId();
            workout.IsActive = false;

            if (workout.StartTime == DateTime.MinValue)
                workout.StartTime = DateTime.Now;

            if (workout.DurationSeconds == 0)
                workout.DurationSeconds = workout.ElapsedSeconds;

            workoutHistory.Add(workout);
            DataStore.SaveHistory(workoutHistory);
            return Ok($"Sikeres mentés! Az edzésed elmentve {workout.Id} azonosítóval. Összesen {workout.Exercises.Count} gyakorlatot végeztél.");
        }

        /// <summary>
        /// Import external activities (Strava / Health / Watch) into workout history.
        /// Dedupes by ExternalId + ExternalSource per user.
        /// </summary>
        [HttpPost("import")]
        public ActionResult<object> ImportExternal([FromBody] ExternalWorkoutImportRequest request)
        {
            var auth = CurrentUser.RequireUser(this, out var user);
            if (auth != null) return auth;

            if (request?.Items == null || request.Items.Count == 0)
                return BadRequest("Nincs importálandó edzés.");

            var imported = 0;
            var skipped = 0;
            var ids = new List<int>();

            foreach (var item in request.Items)
            {
                var externalId = (item.ExternalId ?? "").Trim();
                var source = (item.Source ?? "").Trim().ToLowerInvariant();
                if (string.IsNullOrEmpty(externalId) || string.IsNullOrEmpty(source))
                {
                    skipped++;
                    continue;
                }

                var exists = workoutHistory.Any(w =>
                    w.UserName.Equals(user, StringComparison.OrdinalIgnoreCase) &&
                    w.ExternalId.Equals(externalId, StringComparison.OrdinalIgnoreCase) &&
                    w.ExternalSource.Equals(source, StringComparison.OrdinalIgnoreCase));
                if (exists)
                {
                    skipped++;
                    continue;
                }

                var duration = Math.Max(0, item.DurationSeconds);
                var title = string.IsNullOrWhiteSpace(item.Title)
                    ? (string.IsNullOrWhiteSpace(item.ActivityType) ? "Importált edzés" : item.ActivityType!)
                    : item.Title.Trim();

                var session = new WorkoutSession
                {
                    Id = NextHistoryId(),
                    UserName = user,
                    Title = title,
                    StartTime = item.StartTime ?? DateTime.UtcNow,
                    DurationSeconds = duration,
                    IsActive = false,
                    Exercises = new List<LoggedExercise>(),
                    ExternalId = externalId,
                    ExternalSource = source,
                    DistanceKm = item.DistanceKm,
                    ActivityType = item.ActivityType?.Trim() ?? "",
                };

                workoutHistory.Add(session);
                ids.Add(session.Id);
                imported++;
            }

            if (imported > 0)
                DataStore.SaveHistory(workoutHistory);

            return Ok(new
            {
                imported,
                skipped,
                ids,
                message = imported > 0
                    ? $"{imported} edzés bekerült a naplóba ({skipped} kihagyva / már megvolt)."
                    : "Nincs új edzés a naplóba (mind már importálva volt).",
            });
        }
    }
}
