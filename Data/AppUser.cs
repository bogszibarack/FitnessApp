using System.ComponentModel.DataAnnotations;

namespace FitnessBackend.Data
{
    public class AppUser
    {
        public Guid Id { get; set; } = Guid.NewGuid();

        [MaxLength(256)]
        public string Email { get; set; } = "";

        [MaxLength(64)]
        public string Username { get; set; } = "";

        [MaxLength(200)]
        public string PasswordHash { get; set; } = "";

        /// <summary>True if PasswordHash is still legacy Base64 (pre-JWT migration).</summary>
        public bool PasswordIsLegacyBase64 { get; set; }

        [MaxLength(16)]
        public string WeightUnit { get; set; } = "kg";

        [MaxLength(16)]
        public string DistanceUnit { get; set; } = "km";

        [MaxLength(16)]
        public string MeasurementUnit { get; set; } = "cm";

        public double Weight { get; set; }

        [MaxLength(128)]
        public string County { get; set; } = "";

        [MaxLength(64)]
        public string Source { get; set; } = "";

        public DateTime CreatedAt { get; set; } = DateTime.UtcNow;

        public List<RefreshToken> RefreshTokens { get; set; } = new();
    }

    public class RefreshToken
    {
        public Guid Id { get; set; } = Guid.NewGuid();
        public Guid UserId { get; set; }
        public AppUser User { get; set; } = null!;

        /// <summary>SHA256 hash of the raw refresh token (never store raw).</summary>
        [MaxLength(128)]
        public string TokenHash { get; set; } = "";

        [MaxLength(128)]
        public string DeviceLabel { get; set; } = "";

        public DateTime CreatedAt { get; set; } = DateTime.UtcNow;
        public DateTime ExpiresAt { get; set; }
        public DateTime? RevokedAt { get; set; }

        public bool IsActive => RevokedAt == null && ExpiresAt > DateTime.UtcNow;
    }
}
