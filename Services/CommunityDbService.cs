using System.Text.Json;
using FitnessBackend.Data;
using FitnessBackend.Models;
using Microsoft.EntityFrameworkCore;

namespace FitnessBackend.Services
{
    public class CommunityDbService
    {
        private static readonly JsonSerializerOptions JsonOpts = new()
        {
            PropertyNamingPolicy = JsonNamingPolicy.CamelCase,
            PropertyNameCaseInsensitive = true,
        };

        private readonly AppDbContext _db;

        public CommunityDbService(AppDbContext db) => _db = db;

        public async Task<AppUser?> FindUserByNameAsync(string userName) =>
            await _db.Users.FirstOrDefaultAsync(u =>
                u.Username.ToLower() == userName.Trim().ToLower());

        public async Task<AppUser?> FindUserByIdAsync(Guid id) =>
            await _db.Users.FirstOrDefaultAsync(u => u.Id == id);

        public async Task<(CommunityPost? Post, string? Error)> CreatePostAsync(
            AppUser user, ShareRequest req)
        {
            if (string.IsNullOrWhiteSpace(req.County))
                return (null, "Megye kotelezo.");

            var county = CommunityStore.FindCounty(req.County);
            if (county == null)
                return (null, "Ismeretlen megye. Hasznald: GET /api/community/counties");

            if (req.Workout == null || req.Workout.Exercises.Count == 0)
                return (null, "Az edzes adatok kotelezoek (legalabb 1 gyakorlat).");

            var entity = new DbCommunityPost
            {
                UserId = user.Id,
                UserName = user.Username,
                County = county.Name,
                Region = county.Region,
                SelfieUrl = req.SelfieUrl ?? "",
                WorkoutJson = JsonSerializer.Serialize(req.Workout, JsonOpts),
                SharedAt = DateTime.UtcNow,
            };

            _db.CommunityPosts.Add(entity);
            await _db.SaveChangesAsync();
            return (await MapPostAsync(entity.Id), null);
        }

        public async Task<List<CommunityPost>> GetFeedAsync(string? countyId = null, string? region = null)
        {
            var q = _db.CommunityPosts.AsNoTracking().AsQueryable();

            if (!string.IsNullOrWhiteSpace(countyId))
            {
                var county = CommunityStore.FindCounty(countyId);
                if (county == null) return new List<CommunityPost>();
                q = q.Where(p =>
                    p.County.ToLower() == county.Name.ToLower() ||
                    p.County.ToLower() == county.Id.ToLower());
            }

            if (!string.IsNullOrWhiteSpace(region))
                q = q.Where(p => p.Region.ToLower() == region.ToLower());

            var ids = await q.OrderByDescending(p => p.SharedAt)
                .Select(p => p.Id)
                .Take(100)
                .ToListAsync();

            var list = new List<CommunityPost>();
            foreach (var id in ids)
            {
                var mapped = await MapPostAsync(id);
                if (mapped != null) list.Add(mapped);
            }
            return list;
        }

        public async Task<CommunityPost?> GetPostByGuidAsync(Guid id) => await MapPostAsync(id);

        public static string SanitizeFileName(string name)
        {
            var chars = name.Where(c => char.IsLetterOrDigit(c) || c == '-' || c == '_').ToArray();
            var clean = new string(chars);
            return string.IsNullOrWhiteSpace(clean) ? "user" : clean.ToLowerInvariant();
        }

        public async Task<(CommunityPost? Post, string? Error)> LikeAsync(Guid postId, AppUser user)
        {
            var post = await _db.CommunityPosts.FirstOrDefaultAsync(p => p.Id == postId);
            if (post == null) return (null, "Nincs ilyen poszt.");

            var exists = await _db.PostLikes.AnyAsync(l => l.PostId == postId && l.UserId == user.Id);
            if (!exists)
            {
                _db.PostLikes.Add(new DbPostLike
                {
                    PostId = postId,
                    UserId = user.Id,
                    UserName = user.Username,
                });
                await _db.SaveChangesAsync();
            }

            return (await MapPostAsync(postId), null);
        }

        public async Task<(CommunityPost? Post, string? Error)> UnlikeAsync(Guid postId, AppUser user)
        {
            var like = await _db.PostLikes.FirstOrDefaultAsync(l =>
                l.PostId == postId && l.UserId == user.Id);
            if (like != null)
            {
                _db.PostLikes.Remove(like);
                await _db.SaveChangesAsync();
            }

            var post = await MapPostAsync(postId);
            return post == null ? (null, "Nincs ilyen poszt.") : (post, null);
        }

        public async Task<(CommunityComment? Comment, string? Error)> AddCommentAsync(
            Guid postId, AppUser user, string text)
        {
            if (string.IsNullOrWhiteSpace(text))
                return (null, "Text kotelezo.");

            var post = await _db.CommunityPosts.FirstOrDefaultAsync(p => p.Id == postId);
            if (post == null) return (null, "Nincs ilyen poszt.");

            var entity = new DbPostComment
            {
                PostId = postId,
                UserId = user.Id,
                UserName = user.Username,
                Text = text.Trim(),
                CreatedAt = DateTime.UtcNow,
            };
            _db.PostComments.Add(entity);
            await _db.SaveChangesAsync();

            return (new CommunityComment
            {
                Id = entity.Id.ToString("N"),
                UserName = entity.UserName,
                Text = entity.Text,
                CreatedAt = entity.CreatedAt,
            }, null);
        }

        public async Task<List<CommunityComment>?> GetCommentsAsync(Guid postId)
        {
            if (!await _db.CommunityPosts.AnyAsync(p => p.Id == postId))
                return null;

            return await _db.PostComments.AsNoTracking()
                .Where(c => c.PostId == postId)
                .OrderByDescending(c => c.CreatedAt)
                .Select(c => new CommunityComment
                {
                    Id = c.Id.ToString("N"),
                    UserName = c.UserName,
                    Text = c.Text,
                    CreatedAt = c.CreatedAt,
                })
                .ToListAsync();
        }

        public async Task<List<PeopleListItem>> ListPeopleAsync(AppUser me, string? q)
        {
            var users = await _db.Users.AsNoTracking()
                .Where(u => u.Id != me.Id)
                .OrderByDescending(u => u.CreatedAt)
                .ToListAsync();

            if (!string.IsNullOrWhiteSpace(q))
            {
                var needle = q.Trim().ToLowerInvariant();
                users = users.Where(u =>
                    u.Username.ToLower().Contains(needle) ||
                    u.Email.ToLower().Contains(needle) ||
                    u.County.ToLower().Contains(needle)).ToList();
            }

            // Rank: same county first
            users = users
                .OrderByDescending(u =>
                    !string.IsNullOrWhiteSpace(me.County) &&
                    u.County.Equals(me.County, StringComparison.OrdinalIgnoreCase))
                .ThenByDescending(u => u.CreatedAt)
                .Take(50)
                .ToList();

            var result = new List<PeopleListItem>();
            foreach (var u in users)
            {
                var status = await GetFriendStatusAsync(me.Id, u.Id);
                var settings = UserSettingsStore.GetOrCreate(u.Username);
                var postCount = await _db.CommunityPosts.CountAsync(p => p.UserId == u.Id);
                result.Add(new PeopleListItem
                {
                    UserId = u.Id,
                    UserName = u.Username,
                    County = u.County,
                    ProfileImageUrl = settings.Profile.ImageUrl ?? "",
                    DisplayName = string.IsNullOrWhiteSpace(settings.Profile.Name)
                        ? u.Username
                        : settings.Profile.Name,
                    Bio = settings.Profile.Bio ?? "",
                    PostCount = postCount,
                    FriendStatus = status,
                    SameCounty = !string.IsNullOrWhiteSpace(me.County) &&
                                 u.County.Equals(me.County, StringComparison.OrdinalIgnoreCase),
                });
            }

            return result;
        }

        public async Task<string> GetFriendStatusAsync(Guid meId, Guid otherId)
        {
            var fr = await _db.FriendRequests.AsNoTracking().FirstOrDefaultAsync(f =>
                (f.FromUserId == meId && f.ToUserId == otherId) ||
                (f.FromUserId == otherId && f.ToUserId == meId));

            if (fr == null) return "none";
            if (fr.Status == FriendRequestStatus.Accepted) return "friends";
            if (fr.Status == FriendRequestStatus.Pending)
                return fr.FromUserId == meId ? "outgoing" : "incoming";
            return "none";
        }

        public async Task<(object? Result, string? Error, int Status)> SendFriendRequestAsync(
            AppUser from, string toUserName)
        {
            var to = await FindUserByNameAsync(toUserName);
            if (to == null) return (null, "Nincs ilyen felhasználó.", 404);
            if (to.Id == from.Id) return (null, "Saját magadnak nem küldhetsz kérést.", 400);

            var existing = await _db.FriendRequests.FirstOrDefaultAsync(f =>
                (f.FromUserId == from.Id && f.ToUserId == to.Id) ||
                (f.FromUserId == to.Id && f.ToUserId == from.Id));

            if (existing != null)
            {
                if (existing.Status == FriendRequestStatus.Accepted)
                    return (null, "Már barátok vagytok.", 409);
                if (existing.Status == FriendRequestStatus.Pending)
                    return (null, "Már van függőben lévő kérés.", 409);

                // Re-open rejected: if I was the original from, reset; if they rejected me, create new direction
                existing.FromUserId = from.Id;
                existing.ToUserId = to.Id;
                existing.Status = FriendRequestStatus.Pending;
                existing.CreatedAt = DateTime.UtcNow;
                existing.RespondedAt = null;
                await _db.SaveChangesAsync();
                return (new { requestId = existing.Id, status = "pending" }, null, 200);
            }

            var req = new FriendRequest
            {
                FromUserId = from.Id,
                ToUserId = to.Id,
                Status = FriendRequestStatus.Pending,
            };
            _db.FriendRequests.Add(req);
            await _db.SaveChangesAsync();
            return (new { requestId = req.Id, status = "pending" }, null, 200);
        }

        public async Task<(object? Result, string? Error, int Status)> RespondFriendRequestAsync(
            AppUser me, Guid requestId, bool accept)
        {
            var req = await _db.FriendRequests.FirstOrDefaultAsync(f => f.Id == requestId);
            if (req == null) return (null, "Nincs ilyen kérés.", 404);
            if (req.ToUserId != me.Id) return (null, "Ez a kérés nem neked szól.", 403);
            if (req.Status != FriendRequestStatus.Pending)
                return (null, "A kérés már el lett bírálva.", 409);

            req.Status = accept ? FriendRequestStatus.Accepted : FriendRequestStatus.Rejected;
            req.RespondedAt = DateTime.UtcNow;
            await _db.SaveChangesAsync();
            return (new
            {
                requestId = req.Id,
                status = accept ? "friends" : "rejected",
            }, null, 200);
        }

        public async Task<(bool Ok, string? Error, int Status)> UnfriendAsync(AppUser me, string otherUserName)
        {
            var other = await FindUserByNameAsync(otherUserName);
            if (other == null) return (false, "Nincs ilyen felhasználó.", 404);

            var fr = await _db.FriendRequests.FirstOrDefaultAsync(f =>
                ((f.FromUserId == me.Id && f.ToUserId == other.Id) ||
                 (f.FromUserId == other.Id && f.ToUserId == me.Id)) &&
                f.Status == FriendRequestStatus.Accepted);

            if (fr == null) return (false, "Nem vagytok barátok.", 404);

            _db.FriendRequests.Remove(fr);
            await _db.SaveChangesAsync();
            return (true, null, 200);
        }

        public async Task<List<PeopleListItem>> ListFriendsAsync(AppUser me)
        {
            var rows = await _db.FriendRequests.AsNoTracking()
                .Where(f => f.Status == FriendRequestStatus.Accepted &&
                            (f.FromUserId == me.Id || f.ToUserId == me.Id))
                .ToListAsync();

            var result = new List<PeopleListItem>();
            foreach (var fr in rows)
            {
                var otherId = fr.FromUserId == me.Id ? fr.ToUserId : fr.FromUserId;
                var other = await FindUserByIdAsync(otherId);
                if (other == null) continue;
                var settings = UserSettingsStore.GetOrCreate(other.Username);
                result.Add(new PeopleListItem
                {
                    UserId = other.Id,
                    UserName = other.Username,
                    County = other.County,
                    ProfileImageUrl = settings.Profile.ImageUrl ?? "",
                    DisplayName = string.IsNullOrWhiteSpace(settings.Profile.Name)
                        ? other.Username
                        : settings.Profile.Name,
                    FriendStatus = "friends",
                });
            }

            return result;
        }

        public async Task<List<object>> ListPendingIncomingAsync(AppUser me)
        {
            var rows = await _db.FriendRequests.AsNoTracking()
                .Where(f => f.ToUserId == me.Id && f.Status == FriendRequestStatus.Pending)
                .OrderByDescending(f => f.CreatedAt)
                .ToListAsync();

            var result = new List<object>();
            foreach (var fr in rows)
            {
                var from = await FindUserByIdAsync(fr.FromUserId);
                if (from == null) continue;
                var settings = UserSettingsStore.GetOrCreate(from.Username);
                result.Add(new
                {
                    requestId = fr.Id,
                    userId = from.Id,
                    userName = from.Username,
                    county = from.County,
                    profileImageUrl = settings.Profile.ImageUrl ?? "",
                    displayName = string.IsNullOrWhiteSpace(settings.Profile.Name)
                        ? from.Username
                        : settings.Profile.Name,
                    createdAt = fr.CreatedAt,
                    friendStatus = "incoming",
                });
            }

            return result;
        }

        public async Task<object?> GetProfileAsync(AppUser? viewer, string userName)
        {
            var user = await FindUserByNameAsync(userName);
            if (user == null) return null;

            var settings = UserSettingsStore.GetOrCreate(user.Username);
            var status = viewer == null
                ? "none"
                : await GetFriendStatusAsync(viewer.Id, user.Id);

            Guid? incomingRequestId = null;
            if (viewer != null && status == "incoming")
            {
                incomingRequestId = await _db.FriendRequests.AsNoTracking()
                    .Where(f => f.FromUserId == user.Id && f.ToUserId == viewer.Id &&
                                f.Status == FriendRequestStatus.Pending)
                    .Select(f => (Guid?)f.Id)
                    .FirstOrDefaultAsync();
            }

            var postIds = await _db.CommunityPosts.AsNoTracking()
                .Where(p => p.UserId == user.Id)
                .OrderByDescending(p => p.SharedAt)
                .Select(p => p.Id)
                .ToListAsync();

            var posts = new List<CommunityPost>();
            foreach (var id in postIds)
            {
                var mapped = await MapPostAsync(id);
                if (mapped != null) posts.Add(mapped);
            }

            var friendsCount = await _db.FriendRequests.CountAsync(f =>
                f.Status == FriendRequestStatus.Accepted &&
                (f.FromUserId == user.Id || f.ToUserId == user.Id));

            var history = Controllers.WorkoutController.HistoryForUserPublic(user.Username);

            return new
            {
                userId = user.Id,
                userName = user.Username,
                email = user.Email,
                county = user.County,
                displayName = string.IsNullOrWhiteSpace(settings.Profile.Name)
                    ? user.Username
                    : settings.Profile.Name,
                bio = settings.Profile.Bio ?? "",
                profileImageUrl = settings.Profile.ImageUrl ?? "",
                friendStatus = status,
                incomingRequestId,
                friendsCount,
                postCount = posts.Count,
                posts,
                workoutHistory = history,
            };
        }

        private async Task<CommunityPost?> MapPostAsync(Guid id)
        {
            var p = await _db.CommunityPosts.AsNoTracking()
                .FirstOrDefaultAsync(x => x.Id == id);
            if (p == null) return null;

            var likes = await _db.PostLikes.AsNoTracking()
                .Where(l => l.PostId == id)
                .Select(l => l.UserName)
                .ToListAsync();

            var comments = await _db.PostComments.AsNoTracking()
                .Where(c => c.PostId == id)
                .OrderByDescending(c => c.CreatedAt)
                .Select(c => new CommunityComment
                {
                    Id = c.Id.ToString("N"),
                    UserName = c.UserName,
                    Text = c.Text,
                    CreatedAt = c.CreatedAt,
                })
                .ToListAsync();

            WorkoutSession workout;
            try
            {
                workout = JsonSerializer.Deserialize<WorkoutSession>(p.WorkoutJson, JsonOpts)
                          ?? new WorkoutSession();
            }
            catch
            {
                workout = new WorkoutSession();
            }

            return new CommunityPost
            {
                Id = p.Id.ToString("N"),
                UserName = p.UserName,
                County = p.County,
                Region = p.Region,
                SelfieUrl = p.SelfieUrl,
                SharedAt = p.SharedAt,
                Workout = workout,
                LikeCount = likes.Count,
                LikedBy = likes,
                Comments = comments,
            };
        }

        public static bool TryParsePostId(string postId, out Guid id)
        {
            id = Guid.Empty;
            if (string.IsNullOrWhiteSpace(postId)) return false;
            var raw = postId.StartsWith("post_", StringComparison.OrdinalIgnoreCase)
                ? postId["post_".Length..]
                : postId;
            // N format is 32 hex chars without dashes
            if (Guid.TryParse(raw, out id)) return true;
            if (raw.Length == 32 && Guid.TryParseExact(raw, "N", out id)) return true;
            return false;
        }
    }

    public class PeopleListItem
    {
        public Guid UserId { get; set; }
        public string UserName { get; set; } = "";
        public string County { get; set; } = "";
        public string ProfileImageUrl { get; set; } = "";
        public string DisplayName { get; set; } = "";
        public string Bio { get; set; } = "";
        public int PostCount { get; set; }
        public string FriendStatus { get; set; } = "none";
        public bool SameCounty { get; set; }
    }
}
