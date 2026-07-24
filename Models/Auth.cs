using System.Text.RegularExpressions;
using FitnessBackend.Services;

namespace FitnessBackend.Models
{
    public class RegisterRequest
    {
        public string Email { get; set; } = "";
        public string Password { get; set; } = "";
        public string Username { get; set; } = "";
        public string WeightUnit { get; set; } = "kg";
        public string DistanceUnit { get; set; } = "km";
        public string MeasurementUnit { get; set; } = "cm";
        public double Weight { get; set; }
        public string County { get; set; } = "";
        public string Source { get; set; } = "";
    }

    public class LoginRequest
    {
        public string Username { get; set; } = "";
        public string Password { get; set; } = "";
    }

    public class RegisteredUser
    {
        public string Id { get; set; } = Guid.NewGuid().ToString("N")[..8];
        public string Email { get; set; } = "";
        public string Username { get; set; } = "";
        public string PasswordHash { get; set; } = "";
        public string WeightUnit { get; set; } = "kg";
        public string DistanceUnit { get; set; } = "km";
        public string MeasurementUnit { get; set; } = "cm";
        public double Weight { get; set; }
        public string County { get; set; } = "";
        public string Source { get; set; } = "";
        public DateTime RegisteredAt { get; set; } = DateTime.Now;
    }

    public class AccountExport
    {
        public List<RegisteredUser> Users { get; set; } = new();
    }

    public static class AccountStore
    {
        public static List<RegisteredUser> Users { get; } = new();

        public static string HashPassword(string password) =>
            Convert.ToBase64String(System.Text.Encoding.UTF8.GetBytes(password));

        public static bool EmailTaken(string email) =>
            Users.Any(u => u.Email.Equals(email, StringComparison.OrdinalIgnoreCase));

        public static bool UsernameTaken(string username) =>
            Users.Any(u => u.Username.Equals(username, StringComparison.OrdinalIgnoreCase));

        public static RegisteredUser? FindByEmailOrUsername(string input)
        {
            if (string.IsNullOrWhiteSpace(input)) return null;
            return Users.FirstOrDefault(u => u.Email.Equals(input, StringComparison.OrdinalIgnoreCase))
                ?? Users.FirstOrDefault(u => u.Username.Equals(input, StringComparison.OrdinalIgnoreCase));
        }

        public static void Add(RegisteredUser user)
        {
            Users.RemoveAll(u =>
                u.Email.Equals(user.Email, StringComparison.OrdinalIgnoreCase) ||
                u.Username.Equals(user.Username, StringComparison.OrdinalIgnoreCase));
            Users.Add(user);
            DataStore.SaveAccounts();
        }
    }
}
