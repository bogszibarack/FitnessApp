using FitnessBackend.Services;

namespace FitnessBackend.Models
{
    public class UserSettings
    {
        public string UserName { get; set; } = "";
        public ProfileSettings Profile { get; set; } = new();
        public AccountSettings Account { get; set; } = new();
        public MembershipSettings Membership { get; set; } = new();
        public NotificationSettings Notifications { get; set; } = new();
        public WorkoutSettings Workout { get; set; } = new();
        public PrivacySettings Privacy { get; set; } = new();
        public UnitSettings Units { get; set; } = new();
        public string Language { get; set; } = "hu";
        public ThemeSettings Theme { get; set; } = new();
        public IntegrationSettings Integrations { get; set; } = new();
        public DateTime CreatedAt { get; set; } = DateTime.Now;
        public DateTime UpdatedAt { get; set; } = DateTime.Now;

        public ProfileSettings Profil { set => Profile = value; }
        public AccountSettings Fiok { set => Account = value; }
        public MembershipSettings Tagsag { set => Membership = value; }
        public NotificationSettings Ertesitesek { set => Notifications = value; }
        public WorkoutSettings Edzes { set => Workout = value; }
        public PrivacySettings PrivatSzocial { set => Privacy = value; }
        public UnitSettings Egyseg { set => Units = value; }
        public string Nyelv { set => Language = value; }
        public ThemeSettings Tema { set => Theme = value; }
        public IntegrationSettings Integraciok { set => Integrations = value; }
        public DateTime Letrehozva { set => CreatedAt = value; }
        public DateTime Modositva { set => UpdatedAt = value; }
    }

    public class ProfileSettings
    {
        public string ImageUrl { get; set; } = "";
        public string Name { get; set; } = "";
        public string SocialLink { get; set; } = "";
        public string Bio { get; set; } = "";
        public DateTime? Birthday { get; set; }
        public string KepUrl { set => ImageUrl = value; }
        public string Nev { set => Name = value; }
        public DateTime? Szuletesnap { set => Birthday = value; }
    }

    public class AccountSettings
    {
        public string Email { get; set; } = "";
        public string PasswordHash { get; set; } = "";
        public string JelszoHash { set => PasswordHash = value; }
    }

    public class MembershipSettings
    {
        public bool ProActive { get; set; }
        public string Plan { get; set; } = "ingyenes";
        public DateTime? ExpiresAt { get; set; }
        public bool ProAktiv { set => ProActive = value; }
        public string Csomag { set => Plan = value; }
        public DateTime? Lejarat { set => ExpiresAt = value; }
    }

    public class NotificationSettings
    {
        public bool PushEnabled { get; set; } = true;
        public bool EmailEnabled { get; set; } = true;
        public bool RestTimer { get; set; } = true;
        public bool FollowAlerts { get; set; } = true;
        public bool LikeReplies { get; set; } = true;
        public bool NewCommunityWorkouts { get; set; } = true;
        public bool OwnWorkoutLikes { get; set; } = true;
        public bool OwnWorkoutComments { get; set; } = true;
        public bool PushEngedelyezve { set => PushEnabled = value; }
        public bool EmailEngedelyezve { set => EmailEnabled = value; }
        public bool PihenoIdozito { set => RestTimer = value; }
        public bool KovetesErtesites { set => FollowAlerts = value; }
        public bool LikeValasz { set => LikeReplies = value; }
        public bool UjEdzesKozosseg { set => NewCommunityWorkouts = value; }
        public bool SajatEdzesLike { set => OwnWorkoutLikes = value; }
        public bool SajatEdzesKomment { set => OwnWorkoutComments = value; }
    }

    public class WorkoutSettings
    {
        public bool Sounds { get; set; } = true;
        public int RestTimerSeconds { get; set; } = 90;
        public bool PrSound { get; set; } = true;
        public string WeekStartsOn { get; set; } = "hetfo";
        public bool AutoFill { get; set; } = true;
        public bool KeepScreenOn { get; set; } = true;
        public bool TrackRpe { get; set; } = true;
        public bool SmartSuperset { get; set; } = true;
        public bool Hangok { set => Sounds = value; }
        public int PihenoIdozitoMasodperc { set => RestTimerSeconds = value; }
        public bool PrHang { set => PrSound = value; }
        public string HetElsoNapja { set => WeekStartsOn = value; }
        public bool AutomatikusKitoltes { set => AutoFill = value; }
        public bool KijelzoEbredve { set => KeepScreenOn = value; }
        public bool RpeKovetes { set => TrackRpe = value; }
        public bool OkosSuperset { set => SmartSuperset = value; }
    }

    public class PrivacySettings
    {
        public string ProfileVisibility { get; set; } = "kozosseg";
        public bool ShareWorkoutsByDefault { get; set; } = true;
        public bool ShowCounty { get; set; } = true;
        public bool SelfieFollowersOnly { get; set; } = false;
        public bool PlansCopyable { get; set; } = true;
        public string ProfilLathatosag { set => ProfileVisibility = value; }
        public bool EdzesMegosztasAlapertelmezett { set => ShareWorkoutsByDefault = value; }
        public bool MegyeMutatasa { set => ShowCounty = value; }
        public bool SzelfiKizarolagKovetoknek { set => SelfieFollowersOnly = value; }
        public bool RutinMasolhato { set => PlansCopyable = value; }
    }

    public class UnitSettings
    {
        public string Weight { get; set; } = "kg";
        public string Distance { get; set; } = "km";
        public string Length { get; set; } = "cm";
        public string Suly { set => Weight = value; }
        public string Tavolsag { set => Distance = value; }
        public string Hossz { set => Length = value; }
    }

    public class ThemeSettings
    {
        public string Mode { get; set; } = "rendszer";
        public string Mod { set => Mode = value; }
    }

    public class IntegrationSettings
    {
        public bool AppleHealth { get; set; }
        public bool AppleWatch { get; set; }
        public bool GoogleFit { get; set; }
        public bool Strava { get; set; }
    }

    public class SettingsRegisterRequest
    {
        public string UserName { get; set; } = "";
        public string Email { get; set; } = "";
        public string Password { get; set; } = "";
        public string Name { get; set; } = "";
        public string Jelszo { set => Password = value; }
        public string Nev { set => Name = value; }
    }

    public class ChangeUsernameRequest
    {
        public string NewUserName { get; set; } = "";
        public string UjUserName { set => NewUserName = value; }
    }

    public class ChangeEmailRequest
    {
        public string NewEmail { get; set; } = "";
        public string Password { get; set; } = "";
        public string UjEmail { set => NewEmail = value; }
        public string Jelszo { set => Password = value; }
    }

    public class ChangePasswordRequest
    {
        public string CurrentPassword { get; set; } = "";
        public string NewPassword { get; set; } = "";
        public string RegiJelszo { set => CurrentPassword = value; }
        public string UjJelszo { set => NewPassword = value; }
    }

    public class ContactRequest
    {
        public string UserName { get; set; } = "";
        public string Email { get; set; } = "";
        public string Subject { get; set; } = "";
        public string Message { get; set; } = "";
        public string Targy { set => Subject = value; }
        public string Uzenet { set => Message = value; }
    }

    public class UserExportPackage
    {
        public string UserName { get; set; } = "";
        public DateTime ExportedAt { get; set; } = DateTime.Now;
        public UserSettings Settings { get; set; } = new();
        public List<Plan> Plans { get; set; } = new();
        public List<CommunityPost> CommunityPosts { get; set; } = new();
        public ProgressSettings? Progress { get; set; }
    }

    public class SettingsMenuSection
    {
        public string Title { get; set; } = "";
        public List<SettingsMenuItem> Items { get; set; } = new();
    }

    public class SettingsMenuItem
    {
        public string Id { get; set; } = "";
        public string Label { get; set; } = "";
        public string Icon { get; set; } = "";
        public string ApiPath { get; set; } = "";
        public bool IsPro { get; set; }
    }

    public class ChoiceOption
    {
        public string Id { get; set; } = "";
        public string Label { get; set; } = "";
    }

    public static class UserSettingsStore
    {
        private static readonly Dictionary<string, UserSettings> Users =
            new(StringComparer.OrdinalIgnoreCase);

        private static readonly List<ContactRequest> ContactMessages = new();

        public static UserSettings GetOrCreate(string userName)
        {
            var key = userName.Trim();
            if (!Users.TryGetValue(key, out var settings))
            {
                settings = new UserSettings
                {
                    UserName = key,
                    Profile = new ProfileSettings { Name = key }
                };
                Users[key] = settings;
            }
            return settings;
        }

        public static void Save(UserSettings user)
        {
            user.UpdatedAt = DateTime.Now;
            Users[user.UserName] = user;
            try
            {
                DataStore.SaveUserSettings();
            }
            catch (Exception ex)
            {
                Console.WriteLine($"[UserSettingsStore] Persist failed: {ex.Message}");
            }
        }

        public static void ReplaceAll(IEnumerable<UserSettings> items)
        {
            Users.Clear();
            foreach (var u in items)
            {
                if (string.IsNullOrWhiteSpace(u.UserName)) continue;
                Users[u.UserName.Trim()] = u;
            }
        }

        public static List<UserSettings> Snapshot() => Users.Values.ToList();

        public static (bool Ok, string? Error) Rename(string oldName, string newName)
        {
            var oldKey = oldName.Trim();
            var newKey = newName.Trim();

            if (!Users.TryGetValue(oldKey, out var user))
                user = GetOrCreate(oldKey);

            if (Users.ContainsKey(newKey) && !newKey.Equals(oldKey, StringComparison.OrdinalIgnoreCase))
                return (false, "Ez a felhasznalonev mar foglalt.");

            Users.Remove(oldKey);
            user.UserName = newKey;
            Save(user);
            return (true, null);
        }

        public static bool Exists(string userName) => Users.ContainsKey(userName.Trim());

        public static (UserSettings? User, string? Error) Register(SettingsRegisterRequest request)
        {
            if (string.IsNullOrWhiteSpace(request.UserName))
                return (null, "UserName kotelezo.");

            if (string.IsNullOrWhiteSpace(request.Email))
                return (null, "Email kotelezo.");

            if (string.IsNullOrWhiteSpace(request.Password) || request.Password.Length < 6)
                return (null, "Jelszo minimum 6 karakter.");

            var key = request.UserName.Trim();
            if (Users.ContainsKey(key))
                return (null, "Ez a felhasznalonev mar foglalt.");

            if (Users.Values.Any(u => u.Account.Email.Equals(request.Email, StringComparison.OrdinalIgnoreCase)))
                return (null, "Ez az email mar regisztralva van.");

            var user = new UserSettings
            {
                UserName = key,
                Profile = new ProfileSettings
                {
                    Name = string.IsNullOrWhiteSpace(request.Name) ? key : request.Name
                },
                Account = new AccountSettings
                {
                    Email = request.Email.Trim(),
                    PasswordHash = HashPassword(request.Password)
                }
            };

            Users[key] = user;
            return (user, null);
        }

        public static (bool Ok, string? Error) VerifyPassword(string userName, string password)
        {
            var user = GetOrCreate(userName);
            if (string.IsNullOrEmpty(user.Account.PasswordHash))
                return (true, null);

            return user.Account.PasswordHash == HashPassword(password)
                ? (true, null)
                : (false, "Hibas jelszo.");
        }

        public static string HashPassword(string password) => AccountStore.HashPassword(password);

        public static void SaveContact(ContactRequest message) => ContactMessages.Add(message);

        public static UserExportPackage Export(string userName)
        {
            var user = GetOrCreate(userName);
            return new UserExportPackage
            {
                UserName = userName,
                Settings = user,
                Plans = PlanStore.SavedPlans
                    .Where(r => r.CreatorName.Equals(userName, StringComparison.OrdinalIgnoreCase))
                    .ToList(),
                // Community posts are Postgres-backed; export keeps empty list for package shape.
                CommunityPosts = [],
                Progress = PlanStore.Progress
            };
        }

        public static (bool Ok, string? Error) Import(UserExportPackage package)
        {
            if (string.IsNullOrWhiteSpace(package.UserName))
                return (false, "UserName kotelezo az importban.");

            var user = GetOrCreate(package.UserName);
            if (package.Settings != null)
            {
                user.Profile = package.Settings.Profile;
                user.Notifications = package.Settings.Notifications;
                user.Workout = package.Settings.Workout;
                user.Privacy = package.Settings.Privacy;
                user.Units = package.Settings.Units;
                user.Language = package.Settings.Language;
                user.Theme = package.Settings.Theme;
                user.Integrations = package.Settings.Integrations;
                Save(user);
            }

            foreach (var plan in package.Plans)
            {
                if (!PlanStore.SavedPlans.Any(r => r.Id == plan.Id))
                    PlanStore.SavedPlans.Add(plan);
            }

            if (package.Progress != null)
                PlanStore.Progress = package.Progress;

            return (true, null);
        }

        public static List<SettingsMenuSection> Menu(string userName)
        {
            var user = GetOrCreate(userName);
            var api = $"/api/settings/{user.UserName}";

            return
            [
                new()
                {
                    Title = "Fiókom",
                    Items =
                    [
                        new() { Id = "profil", Label = "Profil", Icon = "user", ApiPath = $"{api}/profile" },
                        new() { Id = "fiok", Label = "Fiók", Icon = "lock", ApiPath = $"{api}/account" },
                        new() { Id = "ertesitesek", Label = "Értesítések", Icon = "bell", ApiPath = $"{api}/notifications" }
                    ]
                },
                new()
                {
                    Title = "Preferenciák",
                    Items =
                    [
                        new() { Id = "edzes", Label = "Edzések", Icon = "dumbbell", ApiPath = $"{api}/workout" },
                        new() { Id = "privat-szocial", Label = "Adatvédelem & közösség", Icon = "shield", ApiPath = $"{api}/privacy" },
                        new() { Id = "egyseg", Label = "Mértékegységek", Icon = "ruler", ApiPath = $"{api}/units" },
                        new() { Id = "nyelv", Label = "Nyelv", Icon = "flag", ApiPath = $"{api}/language" }
                    ]
                },
                new()
                {
                    Title = "Eszközök és megjelenés",
                    Items =
                    [
                        new() { Id = "integraciok-watch", Label = "Apple Watch", Icon = "watch", ApiPath = $"{api}/integrations" },
                        new() { Id = "tema", Label = "Megjelenés", Icon = "moon", ApiPath = $"{api}/theme" },
                        new() { Id = "export-import", Label = "Export és import", Icon = "export", ApiPath = $"{api}/export" }
                    ]
                },
                new()
                {
                    Title = "Útmutatók",
                    Items =
                    [
                        new() { Id = "utmutato-kezdes", Label = "Kezdő útmutató", Icon = "info", ApiPath = "/api/settings/guides/getting-started" },
                        new() { Id = "utmutato-rutin", Label = "Rutin segítség", Icon = "clipboard", ApiPath = "/api/settings/guides/routine" }
                    ]
                },
                new()
                {
                    Title = "Segítség",
                    Items =
                    [
                        new() { Id = "gyik", Label = "Gyakori kérdések", Icon = "help", ApiPath = "/api/settings/faq" },
                        new() { Id = "kapcsolat", Label = "Kapcsolat", Icon = "mail", ApiPath = "/api/settings/contact" },
                        new() { Id = "rolunk", Label = "Névjegy", Icon = "logo", ApiPath = "/api/settings/about" }
                    ]
                }
            ];
        }
    }
}
