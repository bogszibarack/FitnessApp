using Microsoft.EntityFrameworkCore;

namespace FitnessBackend.Data
{
    public class AppDbContext : DbContext
    {
        public AppDbContext(DbContextOptions<AppDbContext> options) : base(options) { }

        public DbSet<AppUser> Users => Set<AppUser>();
        public DbSet<RefreshToken> RefreshTokens => Set<RefreshToken>();
        public DbSet<FriendRequest> FriendRequests => Set<FriendRequest>();
        public DbSet<DbCommunityPost> CommunityPosts => Set<DbCommunityPost>();
        public DbSet<DbPostLike> PostLikes => Set<DbPostLike>();
        public DbSet<DbPostComment> PostComments => Set<DbPostComment>();

        protected override void OnModelCreating(ModelBuilder modelBuilder)
        {
            modelBuilder.Entity<AppUser>(e =>
            {
                e.HasIndex(x => x.Email).IsUnique();
                e.HasIndex(x => x.Username).IsUnique();
            });

            modelBuilder.Entity<RefreshToken>(e =>
            {
                e.HasIndex(x => x.TokenHash).IsUnique();
                e.HasOne(x => x.User)
                    .WithMany(u => u.RefreshTokens)
                    .HasForeignKey(x => x.UserId)
                    .OnDelete(DeleteBehavior.Cascade);
            });

            modelBuilder.Entity<FriendRequest>(e =>
            {
                e.HasIndex(x => new { x.FromUserId, x.ToUserId }).IsUnique();
                e.HasOne(x => x.FromUser)
                    .WithMany()
                    .HasForeignKey(x => x.FromUserId)
                    .OnDelete(DeleteBehavior.Cascade);
                e.HasOne(x => x.ToUser)
                    .WithMany()
                    .HasForeignKey(x => x.ToUserId)
                    .OnDelete(DeleteBehavior.Cascade);
            });

            modelBuilder.Entity<DbCommunityPost>(e =>
            {
                e.HasIndex(x => x.SharedAt);
                e.HasIndex(x => x.UserName);
                e.HasOne(x => x.User)
                    .WithMany()
                    .HasForeignKey(x => x.UserId)
                    .OnDelete(DeleteBehavior.Cascade);
            });

            modelBuilder.Entity<DbPostLike>(e =>
            {
                e.HasIndex(x => new { x.PostId, x.UserId }).IsUnique();
                e.HasOne(x => x.Post)
                    .WithMany(p => p.Likes)
                    .HasForeignKey(x => x.PostId)
                    .OnDelete(DeleteBehavior.Cascade);
                e.HasOne(x => x.User)
                    .WithMany()
                    .HasForeignKey(x => x.UserId)
                    .OnDelete(DeleteBehavior.Cascade);
            });

            modelBuilder.Entity<DbPostComment>(e =>
            {
                e.HasIndex(x => x.PostId);
                e.HasOne(x => x.Post)
                    .WithMany(p => p.Comments)
                    .HasForeignKey(x => x.PostId)
                    .OnDelete(DeleteBehavior.Cascade);
                e.HasOne(x => x.User)
                    .WithMany()
                    .HasForeignKey(x => x.UserId)
                    .OnDelete(DeleteBehavior.Cascade);
            });
        }
    }
}
