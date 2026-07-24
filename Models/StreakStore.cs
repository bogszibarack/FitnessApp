using FitnessBackend.Services;

namespace FitnessBackend.Models
{
    public class StreakState
    {
        public int Streak { get; set; }
        public string LastDate { get; set; } = "";
    }

    public class StreakUpdateRequest
    {
        public string? UserName { get; set; }
        public bool HasFoodToday { get; set; }
    }

    public static class StreakStore
    {
        public static Dictionary<string, StreakState> ByUser { get; } =
            new(StringComparer.OrdinalIgnoreCase);

        public static StreakState Get(string userName)
        {
            var key = string.IsNullOrWhiteSpace(userName) ? "default" : userName.Trim();
            if (!ByUser.TryGetValue(key, out var state))
            {
                state = new StreakState();
                ByUser[key] = state;
            }
            return state;
        }

        public static StreakState Update(string userName, bool hasFoodToday)
        {
            var state = Get(userName);
            var today = DateTime.Today.ToString("yyyy-MM-dd");
            var yesterday = DateTime.Today.AddDays(-1).ToString("yyyy-MM-dd");

            if (state.LastDate == today)
            {
                if (hasFoodToday && state.Streak == 0)
                {
                    state.Streak = 1;
                    DataStore.SaveStreak();
                }
                return state;
            }

            if (hasFoodToday)
            {
                state.Streak = state.LastDate == yesterday ? state.Streak + 1 : 1;
                state.LastDate = today;
                DataStore.SaveStreak();
                return state;
            }

            if (state.LastDate == yesterday)
                return state;

            if (state.Streak > 0 && !string.IsNullOrEmpty(state.LastDate))
            {
                state.Streak = 0;
                state.LastDate = "";
                DataStore.SaveStreak();
            }

            return state;
        }
    }
}
