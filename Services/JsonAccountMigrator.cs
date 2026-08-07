using FitnessBackend.Data;
using FitnessBackend.Models;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Logging;

namespace FitnessBackend.Services
{
    /// <summary>
    /// One-time import: felhasznalok.json → Postgres users (legacy Base64 passwords).
    /// </summary>
    public static class JsonAccountMigrator
    {
        public static async Task MigrateAsync(AppDbContext db, ILogger logger)
        {
            if (await db.Users.AnyAsync())
            {
                logger.LogInformation("[AuthMigrate] Users table already has data — skip JSON import.");
                return;
            }

            // Ensure JSON accounts are loaded into AccountStore
            if (AccountStore.Users.Count == 0)
            {
                logger.LogInformation("[AuthMigrate] No JSON accounts found — nothing to import.");
                return;
            }

            var imported = 0;
            foreach (var old in AccountStore.Users)
            {
                var email = (old.Email ?? "").Trim().ToLowerInvariant();
                var username = (old.Username ?? "").Trim();
                if (string.IsNullOrWhiteSpace(email) || string.IsNullOrWhiteSpace(username))
                    continue;

                if (await db.Users.AnyAsync(u => u.Email == email || u.Username.ToLower() == username.ToLower()))
                    continue;

                db.Users.Add(new AppUser
                {
                    Email = email,
                    Username = username,
                    PasswordHash = old.PasswordHash ?? "",
                    PasswordIsLegacyBase64 = true,
                    WeightUnit = old.WeightUnit,
                    DistanceUnit = old.DistanceUnit,
                    MeasurementUnit = old.MeasurementUnit,
                    Weight = old.Weight,
                    County = old.County,
                    Source = old.Source,
                    CreatedAt = old.RegisteredAt.Kind == DateTimeKind.Unspecified
                        ? DateTime.SpecifyKind(old.RegisteredAt, DateTimeKind.Utc)
                        : old.RegisteredAt.ToUniversalTime(),
                });
                imported++;
            }

            if (imported > 0)
            {
                await db.SaveChangesAsync();
                logger.LogInformation("[AuthMigrate] Imported {Count} users from felhasznalok.json (legacy passwords).", imported);
            }
            else
            {
                logger.LogInformation("[AuthMigrate] No new users to import.");
            }
        }
    }
}
