using System.Text.RegularExpressions;
using FitnessBackend.Data;
using FitnessBackend.Models;
using Microsoft.EntityFrameworkCore;

namespace FitnessBackend.Services
{
    public class AuthService
    {
        private static readonly Regex EmailRegex =
            new(@"^[^@\s]+@[^@\s]+\.[^@\s]+$", RegexOptions.Compiled);

        private readonly AppDbContext _db;
        private readonly JwtTokenService _jwt;

        public AuthService(AppDbContext db, JwtTokenService jwt)
        {
            _db = db;
            _jwt = jwt;
        }

        public string? ValidateRegister(RegisterRequest req)
        {
            if (string.IsNullOrWhiteSpace(req.Email) || !EmailRegex.IsMatch(req.Email))
                return "Érvénytelen e-mail formátum.";

            if (string.IsNullOrWhiteSpace(req.Password) || req.Password.Length < 6)
                return "A jelszó legalább 6 karakter legyen.";

            if (string.IsNullOrWhiteSpace(req.Username) || req.Username.Length < 3)
                return "A felhasználónév legalább 3 karakter legyen.";

            return null;
        }

        public async Task<(AuthTokenResponse? Result, string? Error, int Status)> RegisterAsync(
            RegisterRequest req, string? deviceLabel = null)
        {
            var err = ValidateRegister(req);
            if (err != null) return (null, err, 400);

            var email = req.Email.ToLowerInvariant().Trim();
            var username = req.Username.Trim();

            if (await _db.Users.AnyAsync(u => u.Email == email))
                return (null, "Ez az e-mail cím már foglalt.", 409);

            if (await _db.Users.AnyAsync(u => u.Username.ToLower() == username.ToLower()))
                return (null, "Ez a felhasználónév már foglalt.", 409);

            var user = new AppUser
            {
                Email = email,
                Username = username,
                PasswordHash = BCrypt.Net.BCrypt.HashPassword(req.Password),
                PasswordIsLegacyBase64 = false,
                WeightUnit = req.WeightUnit,
                DistanceUnit = req.DistanceUnit,
                MeasurementUnit = req.MeasurementUnit,
                Weight = req.Weight,
                County = req.County,
                Source = req.Source,
            };

            _db.Users.Add(user);
            await _db.SaveChangesAsync();

            SeedSettingsProfile(user);

            var tokens = await IssueTokensAsync(user, deviceLabel);
            return (tokens, null, 200);
        }

        public async Task<(AuthTokenResponse? Result, string? Error, int Status)> LoginAsync(
            LoginRequest req, string? deviceLabel = null)
        {
            if (string.IsNullOrWhiteSpace(req.Username))
                return (null, "E-mail vagy felhasználónév megadása kötelező.", 400);

            if (string.IsNullOrWhiteSpace(req.Password) || req.Password.Length < 6)
                return (null, "A jelszó legalább 6 karakter legyen.", 400);

            var input = req.Username.Trim();
            var user = await _db.Users.FirstOrDefaultAsync(u =>
                u.Email == input.ToLowerInvariant() ||
                u.Username.ToLower() == input.ToLower());

            if (user == null)
                return (null, "Nem találtunk fiókot ezzel az e-mail/felhasználónévvel. Regisztrálj!", 404);

            if (!VerifyPassword(user, req.Password))
                return (null, "Hibás jelszó.", 401);

            // Upgrade legacy Base64 password to bcrypt on successful login
            if (user.PasswordIsLegacyBase64)
            {
                user.PasswordHash = BCrypt.Net.BCrypt.HashPassword(req.Password);
                user.PasswordIsLegacyBase64 = false;
                await _db.SaveChangesAsync();
            }

            SeedSettingsProfile(user);
            var tokens = await IssueTokensAsync(user, deviceLabel);
            return (tokens, null, 200);
        }

        public async Task<(AuthTokenResponse? Result, string? Error, int Status)> RefreshAsync(
            string refreshTokenRaw, string? deviceLabel = null)
        {
            if (string.IsNullOrWhiteSpace(refreshTokenRaw))
                return (null, "Refresh token hiányzik.", 400);

            var hash = JwtTokenService.HashRefreshToken(refreshTokenRaw);
            var stored = await _db.RefreshTokens
                .Include(t => t.User)
                .FirstOrDefaultAsync(t => t.TokenHash == hash);

            if (stored == null || !stored.IsActive)
                return (null, "Érvénytelen vagy lejárt refresh token. Jelentkezz be újra.", 401);

            stored.RevokedAt = DateTime.UtcNow;
            var tokens = await IssueTokensAsync(stored.User, deviceLabel ?? stored.DeviceLabel);
            return (tokens, null, 200);
        }

        public async Task LogoutAsync(string? refreshTokenRaw)
        {
            if (string.IsNullOrWhiteSpace(refreshTokenRaw)) return;

            var hash = JwtTokenService.HashRefreshToken(refreshTokenRaw);
            var stored = await _db.RefreshTokens.FirstOrDefaultAsync(t => t.TokenHash == hash);
            if (stored != null && stored.RevokedAt == null)
            {
                stored.RevokedAt = DateTime.UtcNow;
                await _db.SaveChangesAsync();
            }
        }

        public async Task<bool> EmailTakenAsync(string email) =>
            await _db.Users.AnyAsync(u => u.Email == email.ToLowerInvariant().Trim());

        public async Task<bool> UsernameTakenAsync(string username) =>
            await _db.Users.AnyAsync(u => u.Username.ToLower() == username.Trim().ToLower());

        private async Task<AuthTokenResponse> IssueTokensAsync(AppUser user, string? deviceLabel)
        {
            var access = _jwt.CreateAccessToken(user);
            var refreshRaw = _jwt.CreateRefreshTokenRaw();

            _db.RefreshTokens.Add(new RefreshToken
            {
                UserId = user.Id,
                TokenHash = JwtTokenService.HashRefreshToken(refreshRaw),
                DeviceLabel = deviceLabel ?? "",
                ExpiresAt = _jwt.RefreshExpiresAt(),
            });
            await _db.SaveChangesAsync();

            return new AuthTokenResponse
            {
                AccessToken = access,
                RefreshToken = refreshRaw,
                ExpiresIn = _jwt.AccessTokenSeconds,
                UserName = user.Username,
                Email = user.Email,
                County = user.County,
                WeightUnit = user.WeightUnit,
                UserId = user.Id.ToString(),
            };
        }

        private static bool VerifyPassword(AppUser user, string password)
        {
            if (string.IsNullOrEmpty(user.PasswordHash))
                return false;

            if (user.PasswordIsLegacyBase64)
            {
                var legacy = Convert.ToBase64String(System.Text.Encoding.UTF8.GetBytes(password));
                return user.PasswordHash == legacy;
            }

            try
            {
                return BCrypt.Net.BCrypt.Verify(password, user.PasswordHash);
            }
            catch
            {
                return false;
            }
        }

        private static void SeedSettingsProfile(AppUser user)
        {
            var profile = UserSettingsStore.GetOrCreate(user.Username);
            profile.Profile.Name = user.Username;
            profile.Account.Email = user.Email;
            UserSettingsStore.Save(profile);
        }
    }

    public class AuthTokenResponse
    {
        public string AccessToken { get; set; } = "";
        public string RefreshToken { get; set; } = "";
        public int ExpiresIn { get; set; }
        public string UserId { get; set; } = "";
        public string UserName { get; set; } = "";
        public string Email { get; set; } = "";
        public string County { get; set; } = "";
        public string WeightUnit { get; set; } = "";
    }

    public class RefreshRequest
    {
        public string RefreshToken { get; set; } = "";
        public string? DeviceLabel { get; set; }
    }

    public class LogoutRequest
    {
        public string? RefreshToken { get; set; }
    }
}
