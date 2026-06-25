using Microsoft.AspNetCore.Mvc;
using FitnessBackend.Models;

namespace FitnessBackend.Controllers
{
    [ApiController]
    [Route("api/[controller]")]
    public class AuthController : ControllerBase
    {
        /// <summary>
        /// Onboarding regisztráció — validálás + in-memory mentés.
        /// POST /api/auth/register-onboarding
        /// </summary>
        [HttpPost("register-onboarding")]
        public ActionResult<object> RegisterAndOnboard([FromBody] OnboardingRegistrationDto dto)
        {
            var hiba = AuthValidator.ValidateRegistration(dto);
            if (hiba != null)
                return BadRequest(new { error = hiba });

            if (FelhasznaloFiok.LetezikeEmail(dto.Email))
                return Conflict(new { error = "Ez az e-mail cím már foglalt." });

            if (FelhasznaloFiok.LetezikeUsername(dto.Username))
                return Conflict(new { error = "Ez a felhasználónév már foglalt." });

            var ujFelhasznalo = new RegisteredUser
            {
                Email = dto.Email.ToLowerInvariant().Trim(),
                Username = dto.Username.Trim(),
                WeightUnit = dto.WeightUnit,
                DistanceUnit = dto.DistanceUnit,
                MeasurementUnit = dto.MeasurementUnit,
                Weight = dto.Weight,
                County = dto.County,
                Source = dto.Source,
            };

            FelhasznaloFiok.Felhasznalok.Add(ujFelhasznalo);

            // Alap beállítások létrehozása az újonnan regisztrált felhasználóhoz
            // Alap felhasználói profil létrehozása (ha még nem létezik)
            if (!FelhasznaloTarolo.FelhasznaloLetezik(ujFelhasznalo.Username))
            {
                var ujProfil = FelhasznaloTarolo.FelhasznaloLekerdezeseVagyLetrehozasa(ujFelhasznalo.Username);
                ujProfil.Profil.Nev = ujFelhasznalo.Username;
                FelhasznaloTarolo.FelhasznaloMentese(ujProfil);
            }

            return Ok(new
            {
                success = true,
                message = $"Üdvözlünk a Flexio-ban, {ujFelhasznalo.Username}!",
                userName = ujFelhasznalo.Username,
                email = ujFelhasznalo.Email,
                county = ujFelhasznalo.County,
                weightUnit = ujFelhasznalo.WeightUnit,
            });
        }

        /// <summary>
        /// Bejelentkezés e-mail cím vagy felhasználónév alapján.
        /// POST /api/auth/login
        /// </summary>
        [HttpPost("login")]
        public ActionResult<object> Login([FromBody] LoginDto dto)
        {
            if (string.IsNullOrWhiteSpace(dto.Username))
                return BadRequest(new { error = "E-mail vagy felhasználónév megadása kötelező." });

            var input = dto.Username.Trim();

            // Keresés email alapján
            var emailEgyezes = FelhasznaloFiok.Felhasznalok
                .FirstOrDefault(f => f.Email.Equals(input, StringComparison.OrdinalIgnoreCase));

            if (emailEgyezes != null)
            {
                return Ok(new
                {
                    success = true,
                    userName = emailEgyezes.Username,
                    message = "Sikeres bejelentkezés.",
                });
            }

            // Keresés felhasználónév alapján
            var nevEgyezes = FelhasznaloFiok.Felhasznalok
                .FirstOrDefault(f => f.Username.Equals(input, StringComparison.OrdinalIgnoreCase));

            if (nevEgyezes != null)
            {
                return Ok(new
                {
                    success = true,
                    userName = nevEgyezes.Username,
                    message = "Sikeres bejelentkezés.",
                });
            }

            // Meglévő demo felhasználó ellenőrzése (ha volt korábban regisztrálva)
            if (FelhasznaloTarolo.FelhasznaloLetezik(input))
            {
                return Ok(new
                {
                    success = true,
                    userName = input,
                    message = "Sikeres bejelentkezés.",
                });
            }

            return NotFound(new
            {
                error = "Nem találtunk fiókot ezzel az e-mail/felhasználónévvel. Regisztrálj!"
            });
        }

        /// <summary>
        /// E-mail cím foglaltságának ellenőrzése.
        /// GET /api/auth/check-email?email=...
        /// </summary>
        [HttpGet("check-email")]
        public ActionResult<object> CheckEmail([FromQuery] string email)
        {
            if (string.IsNullOrWhiteSpace(email))
                return BadRequest(new { error = "E-mail megadása kötelező." });

            var foglalt = FelhasznaloFiok.LetezikeEmail(email.Trim());
            return Ok(new { occupied = foglalt });
        }

        /// <summary>
        /// Felhasználónév foglaltságának ellenőrzése.
        /// GET /api/auth/check-username?username=...
        /// </summary>
        [HttpGet("check-username")]
        public ActionResult<object> CheckUsername([FromQuery] string username)
        {
            if (string.IsNullOrWhiteSpace(username))
                return BadRequest(new { error = "Felhasználónév megadása kötelező." });

            var foglalt = FelhasznaloFiok.LetezikeUsername(username.Trim())
                       || FelhasznaloTarolo.FelhasznaloLetezik(username.Trim());
            return Ok(new { occupied = foglalt });
        }
    }

    public class LoginDto
    {
        public string Username { get; set; } = "";
        public string Password { get; set; } = "";
    }
}
