using FitnessBackend.Models;

namespace FitnessBackend.Services
{
    public static class SettingsService
    {
        public static (UserSettings? User, string? Error) Register(SettingsRegisterRequest request) =>
            UserSettingsStore.Register(request);

        public static List<SettingsMenuSection> Menu(string userName) =>
            UserSettingsStore.Menu(userName);

        public static UserSettings GetAll(string userName) =>
            UserSettingsStore.GetOrCreate(userName);

        public static UserSettings SaveAll(string userName, UserSettings settings)
        {
            var user = GetAll(userName);
            settings.UserName = user.UserName;
            settings.Account = user.Account;
            settings.Membership = user.Membership;
            settings.CreatedAt = user.CreatedAt;
            UserSettingsStore.Save(settings);
            return settings;
        }

        public static ProfileSettings GetProfile(string userName) => GetAll(userName).Profile;

        public static ProfileSettings SaveProfile(string userName, ProfileSettings profile)
        {
            var user = GetAll(userName);
            user.Profile = profile;
            UserSettingsStore.Save(user);
            return user.Profile;
        }

        public static async Task<(object? Result, string? Error)> UploadProfilePhotoAsync(
            string userName, IFormFile? file, string webRoot, string contentRoot)
        {
            if (file == null || file.Length == 0)
                return (null, "Kep fajl kotelezo.");

            var allowed = new HashSet<string>(StringComparer.OrdinalIgnoreCase)
            {
                ".jpg", ".jpeg", ".png", ".webp"
            };

            var ext = Path.GetExtension(file.FileName);
            if (!allowed.Contains(ext))
                return (null, "Csak jpg, jpeg, png vagy webp formatum engedelyezett.");

            var folder = Path.Combine(string.IsNullOrWhiteSpace(webRoot) ? contentRoot : webRoot, "uploads", "profiles");
            Directory.CreateDirectory(folder);

            var safeName = $"{SanitizeFileName(userName)}_{Guid.NewGuid():N}{ext.ToLowerInvariant()}";
            var fullPath = Path.Combine(folder, safeName);

            await using (var stream = new FileStream(fullPath, FileMode.Create))
            {
                await file.CopyToAsync(stream);
            }

            var user = GetAll(userName);
            user.Profile.ImageUrl = $"/uploads/profiles/{safeName}";
            UserSettingsStore.Save(user);

            return (new
            {
                imageUrl = user.Profile.ImageUrl,
                kepUrl = user.Profile.ImageUrl,
                profile = user.Profile,
                profil = user.Profile
            }, null);
        }

        public static object GetAccount(string userName)
        {
            var user = GetAll(userName);
            var registered = !string.IsNullOrEmpty(user.Account.PasswordHash);
            return new
            {
                userName = user.UserName,
                email = user.Account.Email,
                registered,
                regisztralt = registered
            };
        }

        public static (object? Result, string? Error) ChangeUsername(string userName, ChangeUsernameRequest request)
        {
            if (string.IsNullOrWhiteSpace(request.NewUserName))
                return (null, "UjUserName kotelezo.");

            if (UserSettingsStore.Exists(request.NewUserName))
                return (null, "Ez a felhasznalonev mar foglalt.");

            var (ok, err) = UserSettingsStore.Rename(userName, request.NewUserName);
            if (!ok)
                return (null, err);

            return (new
            {
                message = "Felhasznalonev modositva.",
                uzenet = "Felhasznalonev modositva.",
                oldUserName = userName,
                newUserName = request.NewUserName.Trim(),
                regiUserName = userName,
                ujUserName = request.NewUserName.Trim()
            }, null);
        }

        public static (object? Result, string? Error) ChangeEmail(string userName, ChangeEmailRequest request)
        {
            if (string.IsNullOrWhiteSpace(request.NewEmail))
                return (null, "UjEmail kotelezo.");

            var (ok, err) = UserSettingsStore.VerifyPassword(userName, request.Password);
            if (!ok)
                return (null, err);

            var user = GetAll(userName);
            user.Account.Email = request.NewEmail.Trim();
            UserSettingsStore.Save(user);

            return (new { message = "Email modositva.", uzenet = "Email modositva.", email = user.Account.Email }, null);
        }

        public static (object? Result, string? Error) ChangePassword(string userName, ChangePasswordRequest request)
        {
            if (string.IsNullOrWhiteSpace(request.NewPassword) || request.NewPassword.Length < 6)
                return (null, "Uj jelszo minimum 6 karakter.");

            var (ok, err) = UserSettingsStore.VerifyPassword(userName, request.CurrentPassword);
            if (!ok)
                return (null, err);

            var user = GetAll(userName);
            user.Account.PasswordHash = UserSettingsStore.HashPassword(request.NewPassword);
            UserSettingsStore.Save(user);

            return (new { message = "Jelszo modositva.", uzenet = "Jelszo modositva." }, null);
        }

        public static MembershipSettings GetMembership(string userName) => GetAll(userName).Membership;

        public static MembershipSettings SaveMembership(string userName, MembershipSettings membership)
        {
            var user = GetAll(userName);
            user.Membership = membership;
            UserSettingsStore.Save(user);
            return user.Membership;
        }

        public static NotificationSettings GetNotifications(string userName) => GetAll(userName).Notifications;

        public static NotificationSettings SaveNotifications(string userName, NotificationSettings notifications)
        {
            var user = GetAll(userName);
            user.Notifications = notifications;
            UserSettingsStore.Save(user);
            return user.Notifications;
        }

        public static (WorkoutSettings? Settings, string? Error) GetWorkout(string userName) =>
            (GetAll(userName).Workout, null);

        public static (WorkoutSettings? Settings, string? Error) SaveWorkout(string userName, WorkoutSettings workout)
        {
            if (workout.RestTimerSeconds < 10 || workout.RestTimerSeconds > 600)
                return (null, "Piheno idozito 10-600 masodperc kozott lehet.");

            if (!IsValidWeekStart(workout.WeekStartsOn))
                return (null, "HetElsoNapja: hetfo vagy vasarnap.");

            var user = GetAll(userName);
            user.Workout = workout;
            UserSettingsStore.Save(user);
            return (user.Workout, null);
        }

        public static (PrivacySettings? Settings, string? Error) GetPrivacy(string userName) =>
            (GetAll(userName).Privacy, null);

        public static (PrivacySettings? Settings, string? Error) SavePrivacy(string userName, PrivacySettings privacy)
        {
            if (!IsValidVisibility(privacy.ProfileVisibility))
                return (null, "ProfilLathatosag: mindenki, kovetok, kozosseg, privat.");

            var user = GetAll(userName);
            user.Privacy = privacy;
            UserSettingsStore.Save(user);
            return (user.Privacy, null);
        }

        public static (UnitSettings? Settings, string? Error) GetUnits(string userName) =>
            (GetAll(userName).Units, null);

        public static (UnitSettings? Settings, string? Error) SaveUnits(string userName, UnitSettings units)
        {
            if (!IsValidWeight(units.Weight) || !IsValidDistance(units.Distance) || !IsValidLength(units.Length))
                return (null, "Ervenytelen mertekegyseg. Hasznald: GET /api/settings/options/units");

            var user = GetAll(userName);
            user.Units = units;
            UserSettingsStore.Save(user);
            return (user.Units, null);
        }

        public static object GetLanguage(string userName)
        {
            var lang = GetAll(userName).Language;
            return new { language = lang, nyelv = lang };
        }

        public static (object? Result, string? Error) SaveLanguage(string userName, Dictionary<string, string> body)
        {
            string? lang = null;
            if (body.TryGetValue("language", out var en) && !string.IsNullOrWhiteSpace(en))
                lang = en;
            else if (body.TryGetValue("nyelv", out var hu) && !string.IsNullOrWhiteSpace(hu))
                lang = hu;

            if (lang == null)
                return (null, "nyelv mezo kotelezo.");

            if (!IsValidLanguage(lang))
                return (null, "Ervenytelen nyelv. Hasznald: GET /api/settings/options/languages");

            var user = GetAll(userName);
            user.Language = lang.ToLowerInvariant();
            UserSettingsStore.Save(user);
            return (new { language = user.Language, nyelv = user.Language }, null);
        }

        public static (ThemeSettings? Settings, string? Error) GetTheme(string userName) =>
            (GetAll(userName).Theme, null);

        public static (ThemeSettings? Settings, string? Error) SaveTheme(string userName, ThemeSettings theme)
        {
            if (!IsValidTheme(theme.Mode))
                return (null, "Tema mod: vilagos, sotet, rendszer.");

            var user = GetAll(userName);
            user.Theme = theme;
            UserSettingsStore.Save(user);
            return (user.Theme, null);
        }

        public static IntegrationSettings GetIntegrations(string userName) => GetAll(userName).Integrations;

        public static IntegrationSettings SaveIntegrations(string userName, IntegrationSettings integrations)
        {
            var user = GetAll(userName);
            user.Integrations = integrations;
            UserSettingsStore.Save(user);
            return user.Integrations;
        }

        public static UserExportPackage Export(string userName) =>
            UserSettingsStore.Export(userName);

        public static (object? Result, string? Error) Import(string userName, UserExportPackage package)
        {
            package.UserName = userName;
            var (ok, err) = UserSettingsStore.Import(package);
            if (!ok)
                return (null, err);

            return (new { message = "Import sikeres.", uzenet = "Import sikeres.", userName }, null);
        }

        public static List<ChoiceOption> Languages() =>
        [
            new() { Id = "hu", Label = "Magyar" },
            new() { Id = "en", Label = "English" },
            new() { Id = "de", Label = "Deutsch" }
        ];

        public static object UnitsOptions() => new
        {
            weight = new[]
            {
                new ChoiceOption { Id = "kg", Label = "Kilogramm (kg)" },
                new ChoiceOption { Id = "lbs", Label = "Font (lbs)" }
            },
            distance = new[]
            {
                new ChoiceOption { Id = "km", Label = "Kilometer (km)" },
                new ChoiceOption { Id = "mile", Label = "Mérföld (mile)" }
            },
            length = new[]
            {
                new ChoiceOption { Id = "cm", Label = "Centimeter (cm)" },
                new ChoiceOption { Id = "inch", Label = "Hüvelyk (inch)" }
            },
            // Legacy keys
            suly = new[]
            {
                new ChoiceOption { Id = "kg", Label = "Kilogramm (kg)" },
                new ChoiceOption { Id = "lbs", Label = "Font (lbs)" }
            },
            tavolsag = new[]
            {
                new ChoiceOption { Id = "km", Label = "Kilometer (km)" },
                new ChoiceOption { Id = "mile", Label = "Mérföld (mile)" }
            },
            hossz = new[]
            {
                new ChoiceOption { Id = "cm", Label = "Centimeter (cm)" },
                new ChoiceOption { Id = "inch", Label = "Hüvelyk (inch)" }
            }
        };

        public static List<ChoiceOption> Themes() =>
        [
            new() { Id = "vilagos", Label = "Vilagos" },
            new() { Id = "sotet", Label = "Sotet" },
            new() { Id = "rendszer", Label = "Rendszer alapjan" }
        ];

        public static List<ChoiceOption> WeekStarts() =>
        [
            new() { Id = "hetfo", Label = "Hetfo" },
            new() { Id = "vasarnap", Label = "Vasarnap" }
        ];

        public static List<ChoiceOption> VisibilityOptions() =>
        [
            new() { Id = "mindenki", Label = "Mindenki" },
            new() { Id = "kovetok", Label = "Csak kovetok" },
            new() { Id = "kozosseg", Label = "Kozosseg (megye alapu)" },
            new() { Id = "privat", Label = "Privat" }
        ];

        public static object GettingStartedGuide() => new
        {
            cim = "Kezdo utmutato",
            lepesek = new[]
            {
                "1. Indits ures edzest vagy valassz rutint.",
                "2. Add hozza a gyakorlatokat es pipald ki a sorozatokat.",
                "3. Befejezes utan oszd meg a kozossegben szelfivel es megyevel.",
                "4. Fedezd fel a helyi edzéseket a Community feedben.",
                "5. Mentsd el a tetszo edzéseket rutinkent."
            }
        };

        public static object RoutineGuide() => new
        {
            cim = "Rutin segitseg",
            lepesek = new[]
            {
                "AI generalas: valassz nehezseget, izomcsoportot es sportagat.",
                "Mentes: POST /api/plan/save ha megtetszik egy terv.",
                "Inditas: POST /api/workout/inditas-rutinbol/{plan_id}.",
                "Kozossegbol: mentsd el mas edzeset, majd inditsd rutinkent.",
                "Kovetkezo het: hasznald a progresszio csuszkat a suly noveleshez."
            }
        };

        public static object Faq() => new
        {
            kerdesek = new[]
            {
                new { kerdes = "Hogyan oszthatom meg az edzesemet?", valasz = "Befejezes utan: POST /api/workout/aktiv/befejezes-es-megosztas szelfi URL-lel es megyevel." },
                new { kerdes = "Hogyan menthetek el mas edzeset?", valasz = "A Community poszton: POST /api/community/{postId}/save-as-plan" },
                new { kerdes = "Hol valthatok kg es lbs kozott?", valasz = "Beallitasok > Mertekegysegek: PUT /api/settings/{userName}/units" },
                new { kerdes = "Mi a Pro tagsag?", valasz = "Pro funkcio: AI rutin generalas, reszletes statisztikak (hamarosan)." }
            }
        };

        public static (object? Result, string? Error) Contact(ContactRequest request)
        {
            if (string.IsNullOrWhiteSpace(request.Email) || string.IsNullOrWhiteSpace(request.Message))
                return (null, "Email es Uzenet kotelezo.");

            UserSettingsStore.SaveContact(request);
            return (new { message = "Uzenet elkuldve. Hamarosan valaszolunk!", uzenet = "Uzenet elkuldve. Hamarosan valaszolunk!" }, null);
        }

        public static object About() => new
        {
            appNev = "Fitness App",
            verzio = "1.0.0",
            leiras = "Hevy + Yazio ihlette fitness alkalmazas magyar kozosseggel.",
            funkcio = new[] { "Edzes naplo", "Rutin generalas", "Etkezes naplo", "Receptek", "Helyi Community feed", "Beallitasok" }
        };

        private static string SanitizeFileName(string name)
        {
            var chars = name.Where(c => char.IsLetterOrDigit(c) || c == '-' || c == '_').ToArray();
            var cleaned = new string(chars);
            return string.IsNullOrWhiteSpace(cleaned) ? "user" : cleaned.ToLowerInvariant();
        }

        private static bool IsValidWeekStart(string day) =>
            day.Equals("hetfo", StringComparison.OrdinalIgnoreCase) ||
            day.Equals("vasarnap", StringComparison.OrdinalIgnoreCase);

        private static bool IsValidVisibility(string visibility) =>
            new[] { "mindenki", "kovetok", "kozosseg", "privat" }
                .Any(v => v.Equals(visibility, StringComparison.OrdinalIgnoreCase));

        private static bool IsValidWeight(string unit) =>
            unit.Equals("kg", StringComparison.OrdinalIgnoreCase) ||
            unit.Equals("lbs", StringComparison.OrdinalIgnoreCase);

        private static bool IsValidDistance(string unit) =>
            unit.Equals("km", StringComparison.OrdinalIgnoreCase) ||
            unit.Equals("mile", StringComparison.OrdinalIgnoreCase);

        private static bool IsValidLength(string unit) =>
            unit.Equals("cm", StringComparison.OrdinalIgnoreCase) ||
            unit.Equals("inch", StringComparison.OrdinalIgnoreCase);

        private static bool IsValidLanguage(string language) =>
            new[] { "hu", "en", "de" }.Any(n => n.Equals(language, StringComparison.OrdinalIgnoreCase));

        private static bool IsValidTheme(string mode) =>
            new[] { "vilagos", "sotet", "rendszer" }.Any(t => t.Equals(mode, StringComparison.OrdinalIgnoreCase));
    }
}
