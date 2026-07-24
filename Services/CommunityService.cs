using FitnessBackend.Models;

namespace FitnessBackend.Services
{
    public static class CommunityService
    {
        public static List<CommunityPost> SortFeed(IEnumerable<CommunityPost> posts) =>
            posts.OrderByDescending(p => p.SharedAt).ToList();

        public static List<CommunityPost> FeedByCounty(string countyId)
        {
            var county = CommunityStore.FindCounty(countyId);
            if (county == null) return new List<CommunityPost>();

            return SortFeed(CommunityStore.Posts.Where(p =>
                p.County.Equals(county.Name, StringComparison.OrdinalIgnoreCase) ||
                p.County.Equals(county.Id, StringComparison.OrdinalIgnoreCase)));
        }

        public static List<CommunityPost> FeedByRegion(string region) =>
            SortFeed(CommunityStore.Posts.Where(p =>
                p.Region.Equals(region, StringComparison.OrdinalIgnoreCase)));

        public static string SanitizeFileName(string name)
        {
            var chars = name.Where(c => char.IsLetterOrDigit(c) || c == '-' || c == '_').ToArray();
            var clean = new string(chars);
            return string.IsNullOrWhiteSpace(clean) ? "user" : clean.ToLowerInvariant();
        }

        public static object UserStats(string? search)
        {
            var all = CommunityStore.Posts
                .GroupBy(p => p.UserName)
                .Select(g => new
                {
                    userName = g.Key,
                    postCount = g.Count(),
                    totalLikes = g.Sum(p => p.LikeCount),
                    lastWorkout = g.Max(p => p.SharedAt),
                    lastWorkoutTitle = g.OrderByDescending(p => p.SharedAt).First().Workout.Title
                })
                .OrderByDescending(u => u.postCount);

            if (!string.IsNullOrWhiteSpace(search))
                return all.Where(u => u.userName.Contains(search, StringComparison.OrdinalIgnoreCase)).ToList();

            return all.ToList();
        }
    }
}
