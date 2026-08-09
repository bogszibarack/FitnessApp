using FitnessBackend.Data;
using Microsoft.EntityFrameworkCore;

namespace FitnessBackend.Services
{
    /// <summary>
    /// EnsureCreated does not add new tables to an existing DB — create community tables if missing.
    /// </summary>
    public static class CommunitySchemaBootstrap
    {
        public static async Task EnsureAsync(AppDbContext db, ILogger logger)
        {
            var provider = db.Database.ProviderName ?? "";
            try
            {
                if (provider.Contains("Npgsql", StringComparison.OrdinalIgnoreCase))
                    await EnsurePostgresAsync(db);
                else
                    await EnsureSqliteAsync(db);

                logger.LogInformation("[Community] Schema bootstrap OK ({Provider})", provider);
            }
            catch (Exception ex)
            {
                logger.LogError(ex, "[Community] Schema bootstrap failed");
                throw;
            }
        }

        private static async Task EnsurePostgresAsync(AppDbContext db)
        {
            await db.Database.ExecuteSqlRawAsync(
                """
                CREATE TABLE IF NOT EXISTS "FriendRequests" (
                    "Id" uuid NOT NULL PRIMARY KEY,
                    "FromUserId" uuid NOT NULL REFERENCES "Users" ("Id") ON DELETE CASCADE,
                    "ToUserId" uuid NOT NULL REFERENCES "Users" ("Id") ON DELETE CASCADE,
                    "Status" integer NOT NULL,
                    "CreatedAt" timestamp with time zone NOT NULL,
                    "RespondedAt" timestamp with time zone NULL
                );
                CREATE UNIQUE INDEX IF NOT EXISTS "IX_FriendRequests_FromUserId_ToUserId"
                    ON "FriendRequests" ("FromUserId", "ToUserId");

                CREATE TABLE IF NOT EXISTS "CommunityPosts" (
                    "Id" uuid NOT NULL PRIMARY KEY,
                    "UserId" uuid NOT NULL REFERENCES "Users" ("Id") ON DELETE CASCADE,
                    "UserName" character varying(64) NOT NULL,
                    "County" character varying(128) NOT NULL,
                    "Region" character varying(128) NOT NULL,
                    "SelfieUrl" character varying(512) NOT NULL,
                    "WorkoutJson" text NOT NULL,
                    "SharedAt" timestamp with time zone NOT NULL
                );
                CREATE INDEX IF NOT EXISTS "IX_CommunityPosts_SharedAt" ON "CommunityPosts" ("SharedAt");
                CREATE INDEX IF NOT EXISTS "IX_CommunityPosts_UserName" ON "CommunityPosts" ("UserName");

                CREATE TABLE IF NOT EXISTS "PostLikes" (
                    "Id" uuid NOT NULL PRIMARY KEY,
                    "PostId" uuid NOT NULL REFERENCES "CommunityPosts" ("Id") ON DELETE CASCADE,
                    "UserId" uuid NOT NULL REFERENCES "Users" ("Id") ON DELETE CASCADE,
                    "UserName" character varying(64) NOT NULL,
                    "CreatedAt" timestamp with time zone NOT NULL
                );
                CREATE UNIQUE INDEX IF NOT EXISTS "IX_PostLikes_PostId_UserId"
                    ON "PostLikes" ("PostId", "UserId");

                CREATE TABLE IF NOT EXISTS "PostComments" (
                    "Id" uuid NOT NULL PRIMARY KEY,
                    "PostId" uuid NOT NULL REFERENCES "CommunityPosts" ("Id") ON DELETE CASCADE,
                    "UserId" uuid NOT NULL REFERENCES "Users" ("Id") ON DELETE CASCADE,
                    "UserName" character varying(64) NOT NULL,
                    "Text" character varying(2000) NOT NULL,
                    "CreatedAt" timestamp with time zone NOT NULL
                );
                CREATE INDEX IF NOT EXISTS "IX_PostComments_PostId" ON "PostComments" ("PostId");
                """);
        }

        private static async Task EnsureSqliteAsync(AppDbContext db)
        {
            await db.Database.ExecuteSqlRawAsync(
                """
                CREATE TABLE IF NOT EXISTS "FriendRequests" (
                    "Id" TEXT NOT NULL PRIMARY KEY,
                    "FromUserId" TEXT NOT NULL,
                    "ToUserId" TEXT NOT NULL,
                    "Status" INTEGER NOT NULL,
                    "CreatedAt" TEXT NOT NULL,
                    "RespondedAt" TEXT NULL,
                    FOREIGN KEY ("FromUserId") REFERENCES "Users" ("Id") ON DELETE CASCADE,
                    FOREIGN KEY ("ToUserId") REFERENCES "Users" ("Id") ON DELETE CASCADE
                );
                CREATE UNIQUE INDEX IF NOT EXISTS "IX_FriendRequests_FromUserId_ToUserId"
                    ON "FriendRequests" ("FromUserId", "ToUserId");

                CREATE TABLE IF NOT EXISTS "CommunityPosts" (
                    "Id" TEXT NOT NULL PRIMARY KEY,
                    "UserId" TEXT NOT NULL,
                    "UserName" TEXT NOT NULL,
                    "County" TEXT NOT NULL,
                    "Region" TEXT NOT NULL,
                    "SelfieUrl" TEXT NOT NULL,
                    "WorkoutJson" TEXT NOT NULL,
                    "SharedAt" TEXT NOT NULL,
                    FOREIGN KEY ("UserId") REFERENCES "Users" ("Id") ON DELETE CASCADE
                );
                CREATE INDEX IF NOT EXISTS "IX_CommunityPosts_SharedAt" ON "CommunityPosts" ("SharedAt");
                CREATE INDEX IF NOT EXISTS "IX_CommunityPosts_UserName" ON "CommunityPosts" ("UserName");

                CREATE TABLE IF NOT EXISTS "PostLikes" (
                    "Id" TEXT NOT NULL PRIMARY KEY,
                    "PostId" TEXT NOT NULL,
                    "UserId" TEXT NOT NULL,
                    "UserName" TEXT NOT NULL,
                    "CreatedAt" TEXT NOT NULL,
                    FOREIGN KEY ("PostId") REFERENCES "CommunityPosts" ("Id") ON DELETE CASCADE,
                    FOREIGN KEY ("UserId") REFERENCES "Users" ("Id") ON DELETE CASCADE
                );
                CREATE UNIQUE INDEX IF NOT EXISTS "IX_PostLikes_PostId_UserId"
                    ON "PostLikes" ("PostId", "UserId");

                CREATE TABLE IF NOT EXISTS "PostComments" (
                    "Id" TEXT NOT NULL PRIMARY KEY,
                    "PostId" TEXT NOT NULL,
                    "UserId" TEXT NOT NULL,
                    "UserName" TEXT NOT NULL,
                    "Text" TEXT NOT NULL,
                    "CreatedAt" TEXT NOT NULL,
                    FOREIGN KEY ("PostId") REFERENCES "CommunityPosts" ("Id") ON DELETE CASCADE,
                    FOREIGN KEY ("UserId") REFERENCES "Users" ("Id") ON DELETE CASCADE
                );
                CREATE INDEX IF NOT EXISTS "IX_PostComments_PostId" ON "PostComments" ("PostId");
                """);
        }
    }
}
