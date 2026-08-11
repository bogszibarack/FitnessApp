using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using FitnessBackend.Data;
using FitnessBackend.Models;
using FitnessBackend.Services;

namespace FitnessBackend.Controllers
{
    [ApiController]
    [Route("api/community")]
    public class CommunityController : ControllerBase
    {
        private readonly IWebHostEnvironment _env;
        private readonly CommunityDbService _community;

        public CommunityController(IWebHostEnvironment env, CommunityDbService community)
        {
            _env = env;
            _community = community;
        }

        [HttpPost("selfie-upload")]
        [Authorize]
        [RequestSizeLimit(5 * 1024 * 1024)]
        public async Task<ActionResult<object>> UploadSelfie(IFormFile file)
        {
            var auth = CurrentUser.RequireUser(this, out var userName);
            if (auth != null) return auth;

            if (file == null || file.Length == 0)
                return BadRequest("Kep fajl kotelezo.");

            var allowed = new HashSet<string>(StringComparer.OrdinalIgnoreCase)
                { ".jpg", ".jpeg", ".png", ".webp" };

            var ext = Path.GetExtension(file.FileName);
            if (!allowed.Contains(ext))
                return BadRequest("Csak jpg, jpeg, png vagy webp formatum engedelyezett.");

            var dir = DataStore.SelfiesUploadDir;
            Directory.CreateDirectory(dir);

            var safeName = $"{CommunityDbService.SanitizeFileName(userName)}_{Guid.NewGuid():N}{ext.ToLowerInvariant()}";
            var path = Path.Combine(dir, safeName);

            await using (var stream = new FileStream(path, FileMode.Create))
                await file.CopyToAsync(stream);

            return Ok(new
            {
                selfieUrl = $"/uploads/selfies/{safeName}",
                message = "Szelfi feltoltve. Ezt az URL-t add meg a megosztasnal."
            });
        }

        [HttpGet("counties")]
        [AllowAnonymous]
        public List<CountyInfo> Counties() => CommunityStore.Counties;

        [HttpGet("regions")]
        [AllowAnonymous]
        public List<string> Regions() =>
            CommunityStore.Counties.Select(c => c.Region).Distinct().OrderBy(r => r).ToList();

        [HttpGet("feed")]
        [AllowAnonymous]
        public async Task<ActionResult<List<CommunityPost>>> Feed()
        {
            var viewer = await OptionalViewerAsync();
            return Ok(await _community.GetFeedAsync(viewer));
        }

        [HttpGet("feed/county/{countyId}")]
        [AllowAnonymous]
        public async Task<ActionResult<List<CommunityPost>>> FeedByCounty(string countyId)
        {
            if (CommunityStore.FindCounty(countyId) == null)
                return NotFound("Ismeretlen megye.");
            var viewer = await OptionalViewerAsync();
            return Ok(await _community.GetFeedAsync(viewer, countyId: countyId));
        }

        [HttpGet("feed/region/{region}")]
        [AllowAnonymous]
        public async Task<ActionResult<List<CommunityPost>>> FeedByRegion(string region)
        {
            var viewer = await OptionalViewerAsync();
            return Ok(await _community.GetFeedAsync(viewer, region: region));
        }

        [HttpPost("share")]
        [Authorize]
        public async Task<ActionResult<CommunityPost>> Share([FromBody] ShareRequest req)
        {
            var auth = CurrentUser.RequireUser(this, out var userName);
            if (auth != null) return auth;

            var user = await _community.FindUserByNameAsync(userName);
            if (user == null) return Unauthorized(new { error = "Bejelentkezés szükséges." });

            req.UserName = user.Username;
            if (string.IsNullOrWhiteSpace(req.County))
                req.County = user.County;

            var (post, err) = await _community.CreatePostAsync(user, req);
            if (err != null) return BadRequest(err);
            return Ok(post);
        }

        // ─── People / friends (before {postId}) ─────────────────────────────

        [HttpGet("people")]
        [Authorize]
        public async Task<ActionResult> People([FromQuery] string? q = null)
        {
            var auth = CurrentUser.RequireUser(this, out var userName);
            if (auth != null) return auth;

            var me = await _community.FindUserByNameAsync(userName);
            if (me == null) return Unauthorized(new { error = "Bejelentkezés szükséges." });

            return Ok(await _community.ListPeopleAsync(me, q));
        }

        [HttpGet("friends")]
        [Authorize]
        public async Task<ActionResult> Friends()
        {
            var auth = CurrentUser.RequireUser(this, out var userName);
            if (auth != null) return auth;
            var me = await _community.FindUserByNameAsync(userName);
            if (me == null) return Unauthorized(new { error = "Bejelentkezés szükséges." });
            return Ok(await _community.ListFriendsAsync(me));
        }

        [HttpGet("friends/pending")]
        [Authorize]
        public async Task<ActionResult> PendingFriends()
        {
            var auth = CurrentUser.RequireUser(this, out var userName);
            if (auth != null) return auth;
            var me = await _community.FindUserByNameAsync(userName);
            if (me == null) return Unauthorized(new { error = "Bejelentkezés szükséges." });
            return Ok(await _community.ListPendingIncomingAsync(me));
        }

        [HttpPost("friends/request/{username}")]
        [Authorize]
        public async Task<ActionResult> RequestFriend(string username)
        {
            var auth = CurrentUser.RequireUser(this, out var userName);
            if (auth != null) return auth;
            var me = await _community.FindUserByNameAsync(userName);
            if (me == null) return Unauthorized(new { error = "Bejelentkezés szükséges." });

            var (result, err, status) = await _community.SendFriendRequestAsync(me, username);
            if (err != null)
            {
                return status switch
                {
                    404 => NotFound(new { error = err }),
                    409 => Conflict(new { error = err }),
                    _ => BadRequest(new { error = err }),
                };
            }

            return Ok(result);
        }

        [HttpPost("friends/accept/{requestId:guid}")]
        [Authorize]
        public async Task<ActionResult> AcceptFriend(Guid requestId)
        {
            var auth = CurrentUser.RequireUser(this, out var userName);
            if (auth != null) return auth;
            var me = await _community.FindUserByNameAsync(userName);
            if (me == null) return Unauthorized(new { error = "Bejelentkezés szükséges." });

            var (result, err, status) = await _community.RespondFriendRequestAsync(me, requestId, accept: true);
            if (err != null)
            {
                return status switch
                {
                    404 => NotFound(new { error = err }),
                    403 => StatusCode(403, new { error = err }),
                    409 => Conflict(new { error = err }),
                    _ => BadRequest(new { error = err }),
                };
            }

            return Ok(result);
        }

        [HttpPost("friends/reject/{requestId:guid}")]
        [Authorize]
        public async Task<ActionResult> RejectFriend(Guid requestId)
        {
            var auth = CurrentUser.RequireUser(this, out var userName);
            if (auth != null) return auth;
            var me = await _community.FindUserByNameAsync(userName);
            if (me == null) return Unauthorized(new { error = "Bejelentkezés szükséges." });

            var (result, err, status) = await _community.RespondFriendRequestAsync(me, requestId, accept: false);
            if (err != null)
            {
                return status switch
                {
                    404 => NotFound(new { error = err }),
                    403 => StatusCode(403, new { error = err }),
                    409 => Conflict(new { error = err }),
                    _ => BadRequest(new { error = err }),
                };
            }

            return Ok(result);
        }

        [HttpDelete("friends/{username}")]
        [Authorize]
        public async Task<ActionResult> Unfriend(string username)
        {
            var auth = CurrentUser.RequireUser(this, out var userName);
            if (auth != null) return auth;
            var me = await _community.FindUserByNameAsync(userName);
            if (me == null) return Unauthorized(new { error = "Bejelentkezés szükséges." });

            var (ok, err, status) = await _community.UnfriendAsync(me, username);
            if (!ok)
                return status == 404 ? NotFound(new { error = err }) : BadRequest(new { error = err });
            return Ok(new { success = true });
        }

        [HttpGet("profile/{userName}")]
        [Authorize]
        public async Task<ActionResult> Profile(string userName)
        {
            var auth = CurrentUser.RequireUser(this, out var meName);
            if (auth != null) return auth;
            var me = await _community.FindUserByNameAsync(meName);
            var profile = await _community.GetProfileAsync(me, userName);
            if (profile == null) return NotFound(new { error = "Nincs ilyen felhasználó." });
            return Ok(profile);
        }

        // Legacy alias: registered users directory
        [HttpGet("users")]
        [Authorize]
        public async Task<ActionResult> SearchUsers([FromQuery] string? q = null) =>
            await People(q);

        [HttpGet("user/{userName}")]
        [AllowAnonymous]
        public async Task<ActionResult<List<CommunityPost>>> UserPosts(string userName)
        {
            var viewer = await OptionalViewerAsync();
            var feed = await _community.GetFeedAsync(viewer);
            return Ok(feed
                .Where(p => p.UserName.Equals(userName, StringComparison.OrdinalIgnoreCase))
                .ToList());
        }

        // ─── Post by id (catch-all style — keep after named routes) ─────────

        [HttpGet("{postId}")]
        [AllowAnonymous]
        public async Task<ActionResult<CommunityPost>> GetPost(string postId)
        {
            if (!CommunityDbService.TryParsePostId(postId, out var id))
                return NotFound("Nincs ilyen poszt.");
            var viewer = await OptionalViewerAsync();
            var post = await _community.GetPostByGuidAsync(id, viewer);
            if (post == null) return NotFound("Nincs ilyen poszt.");
            return Ok(post);
        }

        [HttpPost("{postId}/like")]
        [Authorize]
        public async Task<ActionResult<CommunityPost>> Like(string postId)
        {
            var auth = CurrentUser.RequireUser(this, out var userName);
            if (auth != null) return auth;
            var user = await _community.FindUserByNameAsync(userName);
            if (user == null) return Unauthorized(new { error = "Bejelentkezés szükséges." });
            if (!CommunityDbService.TryParsePostId(postId, out var id))
                return NotFound("Nincs ilyen poszt.");

            var (post, err) = await _community.LikeAsync(id, user);
            if (err != null) return NotFound(err);
            return Ok(post);
        }

        [HttpDelete("{postId}/like")]
        [Authorize]
        public async Task<ActionResult<CommunityPost>> Unlike(string postId)
        {
            var auth = CurrentUser.RequireUser(this, out var userName);
            if (auth != null) return auth;
            var user = await _community.FindUserByNameAsync(userName);
            if (user == null) return Unauthorized(new { error = "Bejelentkezés szükséges." });
            if (!CommunityDbService.TryParsePostId(postId, out var id))
                return NotFound("Nincs ilyen poszt.");

            var (post, err) = await _community.UnlikeAsync(id, user);
            if (err != null) return NotFound(err);
            return Ok(post);
        }

        [HttpPost("{postId}/comment")]
        [Authorize]
        public async Task<ActionResult<CommunityComment>> AddComment(string postId, [FromBody] CommentRequest req)
        {
            var auth = CurrentUser.RequireUser(this, out var userName);
            if (auth != null) return auth;
            var user = await _community.FindUserByNameAsync(userName);
            if (user == null) return Unauthorized(new { error = "Bejelentkezés szükséges." });
            if (!CommunityDbService.TryParsePostId(postId, out var id))
                return NotFound("Nincs ilyen poszt.");

            var (comment, err) = await _community.AddCommentAsync(id, user, req.Text);
            if (err != null)
                return err.Contains("poszt") ? NotFound(err) : BadRequest(err);
            return Ok(comment);
        }

        [HttpGet("{postId}/comments")]
        [AllowAnonymous]
        public async Task<ActionResult<List<CommunityComment>>> Comments(string postId)
        {
            if (!CommunityDbService.TryParsePostId(postId, out var id))
                return NotFound("Nincs ilyen poszt.");
            var comments = await _community.GetCommentsAsync(id);
            if (comments == null) return NotFound("Nincs ilyen poszt.");
            return Ok(comments);
        }

        [HttpPost("{postId}/save-as-plan")]
        [Authorize]
        public async Task<ActionResult<Plan>> SaveAsPlan(string postId)
        {
            var auth = CurrentUser.RequireUser(this, out var userName);
            if (auth != null) return auth;

            var user = await _community.FindUserByNameAsync(userName);
            if (user == null) return Unauthorized(new { error = "Bejelentkezés szükséges." });

            if (!CommunityDbService.TryParsePostId(postId, out var id))
                return NotFound("Nincs ilyen poszt.");

            var post = await _community.GetPostByGuidAsync(id, user);
            if (post == null) return NotFound("Nincs ilyen poszt.");
            if (post.Workout.Exercises.Count == 0)
                return BadRequest("A poszton nincs gyakorlat, rutin nem mentheto.");

            var plan = Plan.FromCommunityPost(post, userName);
            PlanStore.SavedPlans.Add(plan);
            DataStore.SavePlans();
            return Ok(plan);
        }

        // Legacy follow endpoints → friend request aliases for older clients
        [HttpPost("follow/{target}")]
        [Authorize]
        public async Task<ActionResult> Follow(string target) =>
            await RequestFriend(target);

        [HttpDelete("follow/{target}")]
        [Authorize]
        public async Task<ActionResult> Unfollow(string target) =>
            await Unfriend(target);

        [HttpGet("follows")]
        [Authorize]
        public async Task<ActionResult> Follows()
        {
            var auth = CurrentUser.RequireUser(this, out var userName);
            if (auth != null) return auth;
            var me = await _community.FindUserByNameAsync(userName);
            if (me == null) return Unauthorized(new { error = "Bejelentkezés szükséges." });

            var friends = await _community.ListFriendsAsync(me);
            var names = friends.Select(f => f.UserName).ToList();
            return Ok(new
            {
                following = names,
                followers = names,
                followingCount = names.Count,
                followerCount = names.Count,
            });
        }

        private async Task<AppUser?> OptionalViewerAsync()
        {
            var userName = CurrentUser.UserName(User);
            if (string.IsNullOrEmpty(userName)) return null;
            return await _community.FindUserByNameAsync(userName);
        }
    }
}
