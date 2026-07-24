using Microsoft.AspNetCore.Mvc;
using FitnessBackend.Models;
using FitnessBackend.Services;

namespace FitnessBackend.Controllers
{
    [ApiController]
    [Route("api/settings")]
    public class SettingsController : ControllerBase
    {
        private readonly IWebHostEnvironment _env;

        public SettingsController(IWebHostEnvironment env) => _env = env;

        [HttpPost("register")]
        public ActionResult<UserSettings> Register([FromBody] SettingsRegisterRequest request)
        {
            var (user, err) = SettingsService.Register(request);
            if (err != null) return BadRequest(err);
            return Ok(user);
        }

        [HttpGet("menu/{userName}")]
        public ActionResult<List<SettingsMenuSection>> Menu(string userName)
        {
            if (string.IsNullOrWhiteSpace(userName))
                return BadRequest("userName kotelezo.");
            return Ok(SettingsService.Menu(userName));
        }

        [HttpGet("{userName}")]
        public ActionResult<UserSettings> GetAll(string userName) =>
            Ok(SettingsService.GetAll(userName));

        [HttpPut("{userName}")]
        public ActionResult<UserSettings> SaveAll(string userName, [FromBody] UserSettings settings) =>
            Ok(SettingsService.SaveAll(userName, settings));

        [HttpGet("{userName}/profile")]
        public ActionResult<ProfileSettings> GetProfile(string userName) =>
            Ok(SettingsService.GetProfile(userName));

        [HttpPut("{userName}/profile")]
        public ActionResult<ProfileSettings> SaveProfile(string userName, [FromBody] ProfileSettings profile) =>
            Ok(SettingsService.SaveProfile(userName, profile));

        [HttpPost("{userName}/profile/photo")]
        [RequestSizeLimit(5 * 1024 * 1024)]
        public async Task<ActionResult<object>> UploadProfilePhoto(
            string userName, IFormFile? file, IFormFile? kep)
        {
            var (result, err) = await SettingsService.UploadProfilePhotoAsync(
                userName, file ?? kep, _env.WebRootPath ?? "", _env.ContentRootPath);
            if (err != null) return BadRequest(err);
            return Ok(result);
        }

        [HttpGet("{userName}/account")]
        public ActionResult<object> GetAccount(string userName) =>
            Ok(SettingsService.GetAccount(userName));

        [HttpPut("{userName}/account/username")]
        public ActionResult<object> ChangeUsername(string userName, [FromBody] ChangeUsernameRequest request)
        {
            var (result, err) = SettingsService.ChangeUsername(userName, request);
            if (err != null) return BadRequest(err);
            return Ok(result);
        }

        [HttpPut("{userName}/account/email")]
        public ActionResult<object> ChangeEmail(string userName, [FromBody] ChangeEmailRequest request)
        {
            var (result, err) = SettingsService.ChangeEmail(userName, request);
            if (err != null) return BadRequest(err);
            return Ok(result);
        }

        [HttpPut("{userName}/account/password")]
        public ActionResult<object> ChangePassword(string userName, [FromBody] ChangePasswordRequest request)
        {
            var (result, err) = SettingsService.ChangePassword(userName, request);
            if (err != null) return BadRequest(err);
            return Ok(result);
        }

        [HttpGet("{userName}/membership")]
        public ActionResult<MembershipSettings> GetMembership(string userName) =>
            Ok(SettingsService.GetMembership(userName));

        [HttpPut("{userName}/membership")]
        public ActionResult<MembershipSettings> SaveMembership(string userName, [FromBody] MembershipSettings membership) =>
            Ok(SettingsService.SaveMembership(userName, membership));

        [HttpGet("{userName}/notifications")]
        public ActionResult<NotificationSettings> GetNotifications(string userName) =>
            Ok(SettingsService.GetNotifications(userName));

        [HttpPut("{userName}/notifications")]
        public ActionResult<NotificationSettings> SaveNotifications(
            string userName, [FromBody] NotificationSettings notifications) =>
            Ok(SettingsService.SaveNotifications(userName, notifications));

        [HttpGet("{userName}/workout")]
        public ActionResult<WorkoutSettings> GetWorkout(string userName) =>
            Ok(SettingsService.GetWorkout(userName).Settings);

        [HttpPut("{userName}/workout")]
        public ActionResult<WorkoutSettings> SaveWorkout(string userName, [FromBody] WorkoutSettings workout)
        {
            var (settings, err) = SettingsService.SaveWorkout(userName, workout);
            if (err != null) return BadRequest(err);
            return Ok(settings);
        }

        [HttpGet("{userName}/privacy")]
        public ActionResult<PrivacySettings> GetPrivacy(string userName) =>
            Ok(SettingsService.GetPrivacy(userName).Settings);

        [HttpPut("{userName}/privacy")]
        public ActionResult<PrivacySettings> SavePrivacy(
            string userName, [FromBody] PrivacySettings privacy)
        {
            var (settings, err) = SettingsService.SavePrivacy(userName, privacy);
            if (err != null) return BadRequest(err);
            return Ok(settings);
        }

        [HttpGet("{userName}/units")]
        public ActionResult<UnitSettings> GetUnits(string userName) =>
            Ok(SettingsService.GetUnits(userName).Settings);

        [HttpPut("{userName}/units")]
        public ActionResult<UnitSettings> SaveUnits(string userName, [FromBody] UnitSettings units)
        {
            var (settings, err) = SettingsService.SaveUnits(userName, units);
            if (err != null) return BadRequest(err);
            return Ok(settings);
        }

        [HttpGet("{userName}/language")]
        public ActionResult<object> GetLanguage(string userName) =>
            Ok(SettingsService.GetLanguage(userName));

        [HttpPut("{userName}/language")]
        public ActionResult<object> SaveLanguage(string userName, [FromBody] Dictionary<string, string> body)
        {
            var (result, err) = SettingsService.SaveLanguage(userName, body);
            if (err != null) return BadRequest(err);
            return Ok(result);
        }

        [HttpGet("{userName}/theme")]
        public ActionResult<ThemeSettings> GetTheme(string userName) =>
            Ok(SettingsService.GetTheme(userName).Settings);

        [HttpPut("{userName}/theme")]
        public ActionResult<ThemeSettings> SaveTheme(string userName, [FromBody] ThemeSettings theme)
        {
            var (settings, err) = SettingsService.SaveTheme(userName, theme);
            if (err != null) return BadRequest(err);
            return Ok(settings);
        }

        [HttpGet("{userName}/integrations")]
        public ActionResult<IntegrationSettings> GetIntegrations(string userName) =>
            Ok(SettingsService.GetIntegrations(userName));

        [HttpPut("{userName}/integrations")]
        public ActionResult<IntegrationSettings> SaveIntegrations(
            string userName, [FromBody] IntegrationSettings integrations) =>
            Ok(SettingsService.SaveIntegrations(userName, integrations));

        [HttpGet("{userName}/export")]
        public ActionResult<UserExportPackage> Export(string userName) =>
            Ok(SettingsService.Export(userName));

        [HttpPost("{userName}/import")]
        public ActionResult<object> Import(string userName, [FromBody] UserExportPackage package)
        {
            var (result, err) = SettingsService.Import(userName, package);
            if (err != null) return BadRequest(err);
            return Ok(result);
        }

        [HttpGet("options/languages")]
        public List<ChoiceOption> Languages() => SettingsService.Languages();

        [HttpGet("options/units")]
        public object UnitsOptions() => SettingsService.UnitsOptions();

        [HttpGet("options/themes")]
        public List<ChoiceOption> Themes() => SettingsService.Themes();

        [HttpGet("options/week-start")]
        public List<ChoiceOption> WeekStarts() => SettingsService.WeekStarts();

        [HttpGet("options/visibility")]
        public List<ChoiceOption> VisibilityOptions() => SettingsService.VisibilityOptions();

        [HttpGet("guides/getting-started")]
        public object GettingStartedGuide() => SettingsService.GettingStartedGuide();

        [HttpGet("guides/routine")]
        public object RoutineGuide() => SettingsService.RoutineGuide();

        [HttpGet("faq")]
        public object Faq() => SettingsService.Faq();

        [HttpPost("contact")]
        public ActionResult<object> Contact([FromBody] ContactRequest request)
        {
            var (result, err) = SettingsService.Contact(request);
            if (err != null) return BadRequest(err);
            return Ok(result);
        }

        [HttpGet("about")]
        public object About() => SettingsService.About();

        // --- Legacy aliases ---

        [HttpPost("regisztracio")]
        public ActionResult<UserSettings> RegisterLegacy([FromBody] SettingsRegisterRequest keres) =>
            Register(keres);

        [HttpGet("{userName}/profil")]
        public ActionResult<ProfileSettings> GetProfileLegacy(string userName) => GetProfile(userName);

        [HttpPut("{userName}/profil")]
        public ActionResult<ProfileSettings> SaveProfileLegacy(string userName, [FromBody] ProfileSettings profil) =>
            SaveProfile(userName, profil);

        [HttpPost("{userName}/profil/kep-feltoltes")]
        [RequestSizeLimit(5 * 1024 * 1024)]
        public Task<ActionResult<object>> UploadProfilePhotoLegacy(string userName, IFormFile? kep) =>
            UploadProfilePhoto(userName, null, kep);

        [HttpGet("{userName}/fiok")]
        public ActionResult<object> GetAccountLegacy(string userName) => GetAccount(userName);

        [HttpPut("{userName}/fiok/felhasznalonev")]
        public ActionResult<object> ChangeUsernameLegacy(string userName, [FromBody] ChangeUsernameRequest keres) =>
            ChangeUsername(userName, keres);

        [HttpPut("{userName}/fiok/email")]
        public ActionResult<object> ChangeEmailLegacy(string userName, [FromBody] ChangeEmailRequest keres) =>
            ChangeEmail(userName, keres);

        [HttpPut("{userName}/fiok/jelszo")]
        public ActionResult<object> ChangePasswordLegacy(string userName, [FromBody] ChangePasswordRequest keres) =>
            ChangePassword(userName, keres);

        [HttpGet("{userName}/tagsag")]
        public ActionResult<MembershipSettings> GetMembershipLegacy(string userName) => GetMembership(userName);

        [HttpPut("{userName}/tagsag")]
        public ActionResult<MembershipSettings> SaveMembershipLegacy(string userName, [FromBody] MembershipSettings tagsag) =>
            SaveMembership(userName, tagsag);

        [HttpGet("{userName}/ertesitesek")]
        public ActionResult<NotificationSettings> GetNotificationsLegacy(string userName) => GetNotifications(userName);

        [HttpPut("{userName}/ertesitesek")]
        public ActionResult<NotificationSettings> SaveNotificationsLegacy(
            string userName, [FromBody] NotificationSettings ertesitesek) =>
            SaveNotifications(userName, ertesitesek);

        [HttpGet("{userName}/edzes")]
        public ActionResult<WorkoutSettings> GetWorkoutLegacy(string userName) => GetWorkout(userName);

        [HttpPut("{userName}/edzes")]
        public ActionResult<WorkoutSettings> SaveWorkoutLegacy(string userName, [FromBody] WorkoutSettings edzes) =>
            SaveWorkout(userName, edzes);

        [HttpGet("{userName}/privat-szocial")]
        public ActionResult<PrivacySettings> GetPrivacyLegacy(string userName) => GetPrivacy(userName);

        [HttpPut("{userName}/privat-szocial")]
        public ActionResult<PrivacySettings> SavePrivacyLegacy(
            string userName, [FromBody] PrivacySettings beallitas) =>
            SavePrivacy(userName, beallitas);

        [HttpGet("{userName}/egyseg")]
        public ActionResult<UnitSettings> GetUnitsLegacy(string userName) => GetUnits(userName);

        [HttpPut("{userName}/egyseg")]
        public ActionResult<UnitSettings> SaveUnitsLegacy(string userName, [FromBody] UnitSettings egyseg) =>
            SaveUnits(userName, egyseg);

        [HttpGet("{userName}/nyelv")]
        public ActionResult<object> GetLanguageLegacy(string userName) => GetLanguage(userName);

        [HttpPut("{userName}/nyelv")]
        public ActionResult<object> SaveLanguageLegacy(string userName, [FromBody] Dictionary<string, string> keres) =>
            SaveLanguage(userName, keres);

        [HttpGet("{userName}/tema")]
        public ActionResult<ThemeSettings> GetThemeLegacy(string userName) => GetTheme(userName);

        [HttpPut("{userName}/tema")]
        public ActionResult<ThemeSettings> SaveThemeLegacy(string userName, [FromBody] ThemeSettings tema) =>
            SaveTheme(userName, tema);

        [HttpGet("{userName}/integraciok")]
        public ActionResult<IntegrationSettings> GetIntegrationsLegacy(string userName) => GetIntegrations(userName);

        [HttpPut("{userName}/integraciok")]
        public ActionResult<IntegrationSettings> SaveIntegrationsLegacy(
            string userName, [FromBody] IntegrationSettings integraciok) =>
            SaveIntegrations(userName, integraciok);

        [HttpGet("seged/nyelvek")]
        public List<ChoiceOption> LanguagesLegacy() => Languages();

        [HttpGet("seged/egysegek")]
        public object UnitsOptionsLegacy() => UnitsOptions();

        [HttpGet("seged/temak")]
        public List<ChoiceOption> ThemesLegacy() => Themes();

        [HttpGet("seged/het-napjai")]
        public List<ChoiceOption> WeekStartsLegacy() => WeekStarts();

        [HttpGet("seged/lathatosag")]
        public List<ChoiceOption> VisibilityOptionsLegacy() => VisibilityOptions();

        [HttpGet("utmutatok/kezdes")]
        public object GettingStartedGuideLegacy() => GettingStartedGuide();

        [HttpGet("utmutatok/rutin")]
        public object RoutineGuideLegacy() => RoutineGuide();

        [HttpGet("gyik")]
        public object FaqLegacy() => Faq();

        [HttpPost("kapcsolat")]
        public ActionResult<object> ContactLegacy([FromBody] ContactRequest keres) => Contact(keres);

        [HttpGet("rolunk")]
        public object AboutLegacy() => About();
    }
}
