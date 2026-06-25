using System.Text.RegularExpressions;

namespace FitnessBackend.Models
{
    public class OnboardingRegistrationDto
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

    public static class AuthValidator
    {
        private static readonly Regex EmailRegex =
            new Regex(@"^[^@\s]+@[^@\s]+\.[^@\s]+$", RegexOptions.Compiled);

        public static string? ValidateRegistration(OnboardingRegistrationDto dto)
        {
            if (string.IsNullOrWhiteSpace(dto.Email) || !EmailRegex.IsMatch(dto.Email))
                return "Érvénytelen e-mail formátum.";

            if (string.IsNullOrWhiteSpace(dto.Password) || dto.Password.Length < 6)
                return "A jelszó legalább 6 karakter legyen.";

            if (string.IsNullOrWhiteSpace(dto.Username) || dto.Username.Length < 3)
                return "A felhasználónév legalább 3 karakter legyen.";

            return null;
        }
    }

    // Egyszerű in-memory felhasználó tároló a regisztrált accountokhoz
    public static class FelhasznaloFiok
    {
        public static List<RegisteredUser> Felhasznalok { get; } = new();

        public static bool LetezikeEmail(string email) =>
            Felhasznalok.Any(f => f.Email.Equals(email, StringComparison.OrdinalIgnoreCase));

        public static bool LetezikeUsername(string username) =>
            Felhasznalok.Any(f => f.Username.Equals(username, StringComparison.OrdinalIgnoreCase));
    }

    public class RegisteredUser
    {
        public string Id { get; set; } = Guid.NewGuid().ToString("N")[..8];
        public string Email { get; set; } = "";
        public string Username { get; set; } = "";
        public string WeightUnit { get; set; } = "kg";
        public string DistanceUnit { get; set; } = "km";
        public string MeasurementUnit { get; set; } = "cm";
        public double Weight { get; set; }
        public string County { get; set; } = "";
        public string Source { get; set; } = "";
        public DateTime RegisztraltAt { get; set; } = DateTime.Now;
    }
}
