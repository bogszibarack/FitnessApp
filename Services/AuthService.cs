using FitnessBackend.Models;

namespace FitnessBackend.Services
{
    public static class AuthService
    {
        private static readonly System.Text.RegularExpressions.Regex EmailRegex =
            new(@"^[^@\s]+@[^@\s]+\.[^@\s]+$", System.Text.RegularExpressions.RegexOptions.Compiled);

        public static string? ValidateRegister(RegisterRequest req)
        {
            if (string.IsNullOrWhiteSpace(req.Email) || !EmailRegex.IsMatch(req.Email))
                return "Érvénytelen e-mail formátum.";

            if (string.IsNullOrWhiteSpace(req.Password) || req.Password.Length < 6)
                return "A jelszó legalább 6 karakter legyen.";

            if (string.IsNullOrWhiteSpace(req.Username) || req.Username.Length < 3)
                return "A felhasználónév legalább 3 karakter legyen.";

            return null;
        }

        public static (RegisteredUser? user, string? err) Register(RegisterRequest req)
        {
            var err = ValidateRegister(req);
            if (err != null) return (null, err);

            if (AccountStore.EmailTaken(req.Email))
                return (null, "Ez az e-mail cím már foglalt.");

            if (AccountStore.UsernameTaken(req.Username))
                return (null, "Ez a felhasználónév már foglalt.");

            var hash = AccountStore.HashPassword(req.Password);
            var user = new RegisteredUser
            {
                Email = req.Email.ToLowerInvariant().Trim(),
                Username = req.Username.Trim(),
                PasswordHash = hash,
                WeightUnit = req.WeightUnit,
                DistanceUnit = req.DistanceUnit,
                MeasurementUnit = req.MeasurementUnit,
                Weight = req.Weight,
                County = req.County,
                Source = req.Source,
            };

            AccountStore.Add(user);

            var profile = UserSettingsStore.GetOrCreate(user.Username);
            profile.Profile.Name = user.Username;
            profile.Account.Email = user.Email;
            profile.Account.PasswordHash = hash;
            UserSettingsStore.Save(profile);

            return (user, null);
        }

        public static (RegisteredUser? user, string? err, int status) Login(LoginRequest req)
        {
            if (string.IsNullOrWhiteSpace(req.Username))
                return (null, "E-mail vagy felhasználónév megadása kötelező.", 400);

            if (string.IsNullOrWhiteSpace(req.Password) || req.Password.Length < 6)
                return (null, "A jelszó legalább 6 karakter legyen.", 400);

            var account = AccountStore.FindByEmailOrUsername(req.Username.Trim());
            if (account == null)
                return (null, "Nem találtunk fiókot ezzel az e-mail/felhasználónévvel. Regisztrálj!", 404);

            if (!string.IsNullOrEmpty(account.PasswordHash) &&
                account.PasswordHash != AccountStore.HashPassword(req.Password))
                return (null, "Hibás jelszó.", 401);

            return (account, null, 200);
        }
    }
}
