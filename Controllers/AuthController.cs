using Microsoft.AspNetCore.Mvc;
using FitnessBackend.Models;
using FitnessBackend.Services;

namespace FitnessBackend.Controllers
{
    [ApiController]
    [Route("api/auth")]
    public class AuthController : ControllerBase
    {
        [HttpPost("register-onboarding")]
        public ActionResult<object> Register([FromBody] RegisterRequest req)
        {
            var (user, err) = AuthService.Register(req);
            if (err != null)
            {
                if (err.Contains("foglalt"))
                    return Conflict(new { error = err });
                return BadRequest(new { error = err });
            }

            return Ok(new
            {
                success = true,
                message = $"Üdvözlünk a Flexio-ban, {user!.Username}!",
                userName = user.Username,
                email = user.Email,
                county = user.County,
                weightUnit = user.WeightUnit,
            });
        }

        [HttpPost("login")]
        public ActionResult<object> Login([FromBody] LoginRequest req)
        {
            var (user, err, status) = AuthService.Login(req);
            if (err != null)
            {
                return status switch
                {
                    401 => Unauthorized(new { error = err }),
                    404 => NotFound(new { error = err }),
                    _ => BadRequest(new { error = err }),
                };
            }

            return Ok(new
            {
                success = true,
                userName = user!.Username,
                message = "Sikeres bejelentkezés.",
            });
        }

        [HttpGet("check-email")]
        public ActionResult<object> CheckEmail([FromQuery] string email)
        {
            if (string.IsNullOrWhiteSpace(email))
                return BadRequest(new { error = "E-mail megadása kötelező." });

            return Ok(new { occupied = AccountStore.EmailTaken(email.Trim()) });
        }

        [HttpGet("check-username")]
        public ActionResult<object> CheckUsername([FromQuery] string username)
        {
            if (string.IsNullOrWhiteSpace(username))
                return BadRequest(new { error = "Felhasználónév megadása kötelező." });

            return Ok(new { occupied = AccountStore.UsernameTaken(username.Trim()) });
        }
    }
}
