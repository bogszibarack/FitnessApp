using FitnessBackend.Data;
using Microsoft.EntityFrameworkCore;
using Npgsql;

namespace FitnessBackend.Services
{
    /// <summary>
    /// Copies users from mangled DB names (double-pasted DATABASE_URL) into flexio_db.
    /// </summary>
    public static class PostgresUserRepairMigrator
    {
        public static async Task MigrateAsync(
            AppDbContext db,
            string npgsqlConnectionString,
            ILogger logger)
        {
            NpgsqlConnectionStringBuilder builder;
            try
            {
                builder = new NpgsqlConnectionStringBuilder(npgsqlConnectionString);
            }
            catch (Exception ex)
            {
                logger.LogWarning(ex, "[UserRepair] Invalid connection string — skip.");
                return;
            }

            var primaryDb = builder.Database ?? "flexio_db";
            var candidates = new List<string>();

            try
            {
                await using var admin = new NpgsqlConnection(builder.ConnectionString);
                await admin.OpenAsync();
                await using var cmd = new NpgsqlCommand(
                    """
                    SELECT datname FROM pg_database
                    WHERE datistemplate = false
                      AND datname <> @primary
                      AND (
                        datname LIKE 'flexio_dbpostgresql%'
                        OR datname LIKE 'flexio_dbpostgres%'
                        OR datname = 'flexio_db_user'
                      )
                    """,
                    admin);
                cmd.Parameters.AddWithValue("primary", primaryDb);
                await using var reader = await cmd.ExecuteReaderAsync();
                while (await reader.ReadAsync())
                    candidates.Add(reader.GetString(0));
            }
            catch (Exception ex)
            {
                logger.LogWarning(ex, "[UserRepair] Could not list databases — skip.");
                return;
            }

            if (candidates.Count == 0)
            {
                logger.LogInformation("[UserRepair] No mangled source databases found.");
                return;
            }

            foreach (var candidate in candidates)
            {
                try
                {
                    var imported = await ImportFromDatabaseAsync(db, builder, candidate, logger);
                    if (imported > 0)
                        logger.LogInformation(
                            "[UserRepair] Imported {Count} users from database '{Db}'.",
                            imported, candidate);
                }
                catch (Exception ex)
                {
                    logger.LogWarning(ex, "[UserRepair] Skip source database '{Db}'.", candidate);
                }
            }
        }

        private static async Task<int> ImportFromDatabaseAsync(
            AppDbContext db,
            NpgsqlConnectionStringBuilder template,
            string sourceDatabase,
            ILogger logger)
        {
            var srcBuilder = new NpgsqlConnectionStringBuilder(template.ConnectionString)
            {
                Database = sourceDatabase
            };

            await using var src = new NpgsqlConnection(srcBuilder.ConnectionString);
            await src.OpenAsync();

            await using (var existsCmd = new NpgsqlCommand(
                             """
                             SELECT EXISTS (
                               SELECT 1 FROM information_schema.tables
                               WHERE table_schema = 'public' AND table_name = 'Users'
                             )
                             """,
                             src))
            {
                if (!Convert.ToBoolean(await existsCmd.ExecuteScalarAsync()))
                {
                    logger.LogInformation("[UserRepair] No Users table in '{Db}'.", sourceDatabase);
                    return 0;
                }
            }

            await using var sel = new NpgsqlCommand(
                """
                SELECT "Id", "Email", "Username", "PasswordHash", "PasswordIsLegacyBase64",
                       "WeightUnit", "DistanceUnit", "MeasurementUnit", "Weight",
                       "County", "Source", "CreatedAt"
                FROM "Users"
                """,
                src);

            await using var r = await sel.ExecuteReaderAsync();
            var imported = 0;

            while (await r.ReadAsync())
            {
                var id = r.GetGuid(0);
                var email = r.GetString(1).Trim().ToLowerInvariant();
                var username = r.GetString(2).Trim();

                if (await db.Users.AnyAsync(u =>
                        u.Id == id ||
                        u.Email == email ||
                        u.Username.ToLower() == username.ToLower()))
                    continue;

                db.Users.Add(new AppUser
                {
                    Id = id,
                    Email = email,
                    Username = username,
                    PasswordHash = r.IsDBNull(3) ? "" : r.GetString(3),
                    PasswordIsLegacyBase64 = !r.IsDBNull(4) && r.GetBoolean(4),
                    WeightUnit = r.IsDBNull(5) ? "kg" : r.GetString(5),
                    DistanceUnit = r.IsDBNull(6) ? "km" : r.GetString(6),
                    MeasurementUnit = r.IsDBNull(7) ? "cm" : r.GetString(7),
                    Weight = r.IsDBNull(8) ? 0 : r.GetDouble(8),
                    County = r.IsDBNull(9) ? "" : r.GetString(9),
                    Source = r.IsDBNull(10) ? "" : r.GetString(10),
                    CreatedAt = r.IsDBNull(11)
                        ? DateTime.UtcNow
                        : DateTime.SpecifyKind(r.GetDateTime(11), DateTimeKind.Utc),
                });
                imported++;
            }

            if (imported > 0)
                await db.SaveChangesAsync();

            return imported;
        }
    }
}
