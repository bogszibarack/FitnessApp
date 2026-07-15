using Microsoft.AspNetCore.Mvc;
using FitnessBackend.Models;

namespace FitnessBackend.Controllers
{
    [ApiController]
    [Route("api/[controller]")]
    public class AuthController : ControllerBase
    {
        /// <summary>
        /// Onboarding regisztráció — validálás + fájlba mentés.
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

            var jelszoHash = FelhasznaloTarolo.JelszoHash(dto.Password);
            var ujFelhasznalo = new RegisteredUser
            {
                Email = dto.Email.ToLowerInvariant().Trim(),
                Username = dto.Username.Trim(),
                JelszoHash = jelszoHash,
                WeightUnit = dto.WeightUnit,
                DistanceUnit = dto.DistanceUnit,
                MeasurementUnit = dto.MeasurementUnit,
                Weight = dto.Weight,
                County = dto.County,
                Source = dto.Source,
            };

            FelhasznaloFiok.Hozzaadas(ujFelhasznalo);

            var ujProfil = FelhasznaloTarolo.FelhasznaloLekerdezeseVagyLetrehozasa(ujFelhasznalo.Username);
            ujProfil.Profil.Nev = ujFelhasznalo.Username;
            ujProfil.Fiok.Email = ujFelhasznalo.Email;
            ujProfil.Fiok.JelszoHash = jelszoHash;
            FelhasznaloTarolo.FelhasznaloMentese(ujProfil);

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
        /// Bejelentkezés e-mail cím vagy felhasználónév + jelszó alapján.
        /// POST /api/auth/login
        /// </summary>
        [HttpPost("login")]
        public ActionResult<object> Login([FromBody] LoginDto dto)
        {
            if (string.IsNullOrWhiteSpace(dto.Username))
                return BadRequest(new { error = "E-mail vagy felhasználónév megadása kötelező." });

            if (string.IsNullOrWhiteSpace(dto.Password) || dto.Password.Length < 6)
                return BadRequest(new { error = "A jelszó legalább 6 karakter legyen." });

            var input = dto.Username.Trim();
            var fiok = FelhasznaloFiok.KeresesEmailVagyNevvel(input);

            if (fiok != null)
            {
                if (!string.IsNullOrEmpty(fiok.JelszoHash) &&
                    fiok.JelszoHash != FelhasznaloTarolo.JelszoHash(dto.Password))
                {
                    return Unauthorized(new { error = "Hibás jelszó." });
                }

                return Ok(new
                {
                    success = true,
                    userName = fiok.Username,
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

            var foglalt = FelhasznaloFiok.LetezikeUsername(username.Trim());
            return Ok(new { occupied = foglalt });
        }
    }

    public class LoginDto
    {
        public string Username { get; set; } = "";
        public string Password { get; set; } = "";
    }
}
