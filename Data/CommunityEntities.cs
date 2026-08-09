using System.ComponentModel.DataAnnotations;

namespace FitnessBackend.Data
{
    public enum FriendRequestStatus
    {
        Pending = 0,
        Accepted = 1,
        Rejected = 2,
    }

    public class FriendRequest
    {
        public Guid Id { get; set; } = Guid.NewGuid();
        public Guid FromUserId { get; set; }
        public AppUser FromUser { get; set; } = null!;
        public Guid ToUserId { get; set; }
        public AppUser ToUser { get; set; } = null!;
        public FriendRequestStatus Status { get; set; } = FriendRequestStatus.Pending;
        public DateTime CreatedAt { get; set; } = DateTime.UtcNow;
        public DateTime? RespondedAt { get; set; }
    }

    public class DbCommunityPost
    {
        public Guid Id { get; set; } = Guid.NewGuid();
        public Guid UserId { get; set; }
        public AppUser User { get; set; } = null!;

        [MaxLength(64)]
        public string UserName { get; set; } = "";

        [MaxLength(128)]
        public string County { get; set; } = "";

        [MaxLength(128)]
        public string Region { get; set; } = "";

        [MaxLength(512)]
        public string SelfieUrl { get; set; } = "";

        /// <summary>Serialized WorkoutSession JSON.</summary>
        public string WorkoutJson { get; set; } = "{}";

        public DateTime SharedAt { get; set; } = DateTime.UtcNow;

        public List<DbPostLike> Likes { get; set; } = new();
        public List<DbPostComment> Comments { get; set; } = new();
    }

    public class DbPostLike
    {
        public Guid Id { get; set; } = Guid.NewGuid();
        public Guid PostId { get; set; }
        public DbCommunityPost Post { get; set; } = null!;
        public Guid UserId { get; set; }
        public AppUser User { get; set; } = null!;

        [MaxLength(64)]
        public string UserName { get; set; } = "";

        public DateTime CreatedAt { get; set; } = DateTime.UtcNow;
    }

    public class DbPostComment
    {
        public Guid Id { get; set; } = Guid.NewGuid();
        public Guid PostId { get; set; }
        public DbCommunityPost Post { get; set; } = null!;
        public Guid UserId { get; set; }
        public AppUser User { get; set; } = null!;

        [MaxLength(64)]
        public string UserName { get; set; } = "";

        [MaxLength(2000)]
        public string Text { get; set; } = "";

        public DateTime CreatedAt { get; set; } = DateTime.UtcNow;
    }
}
