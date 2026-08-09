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
    }
}
