using Microsoft.AspNetCore.Mvc;
using FitnessBackend.Models;
using FitnessBackend.Services;

namespace FitnessBackend.Controllers
{
    [ApiController]
    [Route("api/community")]
    public class CommunityController : ControllerBase
    {
        private readonly IWebHostEnvironment _env;

        public CommunityController(IWebHostEnvironment env) => _env = env;

        [HttpPost("selfie-upload")]
        [RequestSizeLimit(5 * 1024 * 1024)]
        public async Task<ActionResult<object>> UploadSelfie(IFormFile file, [FromQuery] string userName)
        {
            if (file == null || file.Length == 0)
                return BadRequest("Kep fajl kotelezo.");

            if (string.IsNullOrWhiteSpace(userName))
                return BadRequest("userName query parameter kotelezo.");

            var allowed = new HashSet<string>(StringComparer.OrdinalIgnoreCase)
                { ".jpg", ".jpeg", ".png", ".webp" };

            var ext = Path.GetExtension(file.FileName);
            if (!allowed.Contains(ext))
                return BadRequest("Csak jpg, jpeg, png vagy webp formatum engedelyezett.");

            var dir = Path.Combine(_env.WebRootPath ?? "", "uploads", "selfies");
            Directory.CreateDirectory(dir);

            var safeName = $"{CommunityService.SanitizeFileName(userName)}_{Guid.NewGuid():N}{ext.ToLowerInvariant()}";
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
        public List<CountyInfo> Counties() => CommunityStore.Counties;

        [HttpGet("regions")]
        public List<string> Regions() =>
            CommunityStore.Counties.Select(c => c.Region).Distinct().OrderBy(r => r).ToList();

        [HttpGet("feed")]
        public List<CommunityPost> Feed() => CommunityService.SortFeed(CommunityStore.Posts);

        [HttpGet("feed/county/{countyId}")]
        public ActionResult<List<CommunityPost>> FeedByCounty(string countyId)
        {
            if (CommunityStore.FindCounty(countyId) == null)
                return NotFound("Ismeretlen megye.");
            return Ok(CommunityService.FeedByCounty(countyId));
        }

        [HttpGet("feed/region/{region}")]
        public ActionResult<List<CommunityPost>> FeedByRegion(string region) =>
            Ok(CommunityService.FeedByRegion(region));

        [HttpPost("share")]
        public ActionResult<CommunityPost> Share([FromBody] ShareRequest req)
        {
            var (post, err) = CommunityStore.CreatePost(req);
            if (err != null) return BadRequest(err);
            return Ok(post);
        }

        [HttpGet("{postId}")]
        public ActionResult<CommunityPost> GetPost(string postId)
        {
            var post = CommunityStore.FindPost(postId);
            if (post == null) return NotFound("Nincs ilyen poszt.");
            return Ok(post);
        }

        [HttpPost("{postId}/like")]
        public ActionResult<CommunityPost> Like([FromBody] LikeRequest req, string postId)
        {
            var post = CommunityStore.FindPost(postId);
            if (post == null) return NotFound("Nincs ilyen poszt.");
            if (string.IsNullOrWhiteSpace(req.UserName))
                return BadRequest("UserName kotelezo.");

            if (!post.LikedBy.Contains(req.UserName))
            {
                post.LikedBy.Add(req.UserName);
                post.LikeCount = post.LikedBy.Count;
            }
            return Ok(post);
        }

        [HttpDelete("{postId}/like")]
        public ActionResult<CommunityPost> Unlike([FromQuery] string userName, string postId)
        {
            var post = CommunityStore.FindPost(postId);
            if (post == null) return NotFound("Nincs ilyen poszt.");

            post.LikedBy.Remove(userName);
            post.LikeCount = post.LikedBy.Count;
            return Ok(post);
        }

        [HttpPost("{postId}/comment")]
        public ActionResult<CommunityComment> AddComment(string postId, [FromBody] CommentRequest req)
        {
            var post = CommunityStore.FindPost(postId);
            if (post == null) return NotFound("Nincs ilyen poszt.");
            if (string.IsNullOrWhiteSpace(req.UserName) || string.IsNullOrWhiteSpace(req.Text))
                return BadRequest("UserName es Text kotelezo.");

            var comment = new CommunityComment
            {
                Id = $"comment_{Guid.NewGuid().ToString("N")[..8]}",
                UserName = req.UserName,
                Text = req.Text,
                CreatedAt = DateTime.Now
            };
            post.Comments.Add(comment);
            return Ok(comment);
        }

        [HttpGet("{postId}/comments")]
        public ActionResult<List<CommunityComment>> Comments(string postId)
        {
            var post = CommunityStore.FindPost(postId);
            if (post == null) return NotFound("Nincs ilyen poszt.");
            return Ok(post.Comments.OrderByDescending(c => c.CreatedAt).ToList());
        }

        [HttpPost("{postId}/save-as-plan")]
        public ActionResult<Plan> SaveAsPlan(string postId, [FromQuery] string? userName = null)
        {
            var owner = CurrentUser.UserName(User)
                ?? (string.IsNullOrWhiteSpace(userName) ? null : userName.Trim());
            if (string.IsNullOrWhiteSpace(owner))
                return Unauthorized(new { error = "Bejelentkezés szükséges." });

            var post = CommunityStore.FindPost(postId);
            if (post == null) return NotFound("Nincs ilyen poszt.");
            if (post.Workout.Exercises.Count == 0)
                return BadRequest("A poszton nincs gyakorlat, rutin nem mentheto.");

            var plan = Plan.FromCommunityPost(post, owner);
            PlanStore.SavedPlans.Add(plan);
            DataStore.SavePlans();
            return Ok(plan);
        }

        [HttpGet("users")]
        public ActionResult<object> SearchUsers([FromQuery] string? q = null) =>
            Ok(CommunityService.UserStats(q));

        [HttpGet("user/{userName}")]
        public ActionResult<List<CommunityPost>> UserPosts(string userName) =>
            Ok(CommunityStore.Posts
                .Where(p => p.UserName.Equals(userName, StringComparison.OrdinalIgnoreCase))
                .OrderByDescending(p => p.SharedAt)
                .ToList());

        [HttpPost("follow/{target}")]
        public ActionResult Follow(string target, [FromQuery] string follower)
        {
            if (string.IsNullOrWhiteSpace(follower))
                return BadRequest("follower query param kotelezo.");

            if (!CommunityStore.IsFollowing(follower, target))
            {
                CommunityStore.Follows.Add(new FollowInfo
                {
                    Follower = follower,
                    Following = target,
                    Since = DateTime.Now
                });
            }
            return Ok(new { follower, following = target, followingNow = true });
        }

        [HttpDelete("follow/{target}")]
        public ActionResult Unfollow(string target, [FromQuery] string follower)
        {
            var item = CommunityStore.Follows
                .FirstOrDefault(f => f.Follower == follower && f.Following == target);
            if (item != null) CommunityStore.Follows.Remove(item);
            return Ok(new { follower, following = target, followingNow = false });
        }

        [HttpGet("follows")]
        public ActionResult<object> Follows([FromQuery] string userName)
        {
            var following = CommunityStore.Follows
                .Where(f => f.Follower == userName)
                .Select(f => f.Following)
                .ToList();
            var followers = CommunityStore.Follows
                .Where(f => f.Following == userName)
                .Select(f => f.Follower)
                .ToList();
            return Ok(new
            {
                following,
                followers,
                followingCount = following.Count,
                followerCount = followers.Count
            });
        }
    }
}
