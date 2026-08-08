using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using FitnessBackend.Models;
using FitnessBackend.Services;

namespace FitnessBackend.Controllers
{
    [ApiController]
    [Route("api/auth")]
    public class AuthController : ControllerBase
    {
        private readonly AuthService _auth;

        public AuthController(AuthService auth) => _auth = auth;

        [HttpPost("register-onboarding")]
        [AllowAnonymous]
        public async Task<ActionResult<object>> Register([FromBody] RegisterRequest req)
        {
            var device = Request.Headers.UserAgent.ToString();
            if (device.Length > 120) device = device[..120];

            var (result, err, status) = await _auth.RegisterAsync(req, device);
            if (err != null)
            {
                return status switch
                {
                    409 => Conflict(new { error = err }),
                    _ => BadRequest(new { error = err }),
                };
            }

            return Ok(ToResponse(result!, $"Üdvözlünk a Flexio-ban, {result!.UserName}!"));
        }

        [HttpPost("login")]
        [AllowAnonymous]
        public async Task<ActionResult<object>> Login([FromBody] LoginRequest req)
        {
            var device = Request.Headers.UserAgent.ToString();
            if (device.Length > 120) device = device[..120];

            var (result, err, status) = await _auth.LoginAsync(req, device);
            if (err != null)
            {
                return status switch
                {
                    401 => Unauthorized(new { error = err }),
                    404 => NotFound(new { error = err }),
                    _ => BadRequest(new { error = err }),
                };
            }

            return Ok(ToResponse(result!, "Sikeres bejelentkezés."));
        }

        [HttpPost("refresh")]
        [AllowAnonymous]
        public async Task<ActionResult<object>> Refresh([FromBody] RefreshRequest req)
        {
            var (result, err, status) = await _auth.RefreshAsync(req.RefreshToken, req.DeviceLabel);
            if (err != null)
                return status == 401 ? Unauthorized(new { error = err }) : BadRequest(new { error = err });

            return Ok(ToResponse(result!, "Token frissítve."));
        }

        [HttpPost("logout")]
        [AllowAnonymous]
        public async Task<ActionResult<object>> Logout([FromBody] LogoutRequest? req)
        {
            await _auth.LogoutAsync(req?.RefreshToken);
            return Ok(new { success = true });
        }

        /// <summary>
        /// Closed-beta recovery: reset password when email + username both match.
        /// </summary>
        [HttpPost("reset-password")]
        [AllowAnonymous]
        public async Task<ActionResult<object>> ResetPassword([FromBody] ResetPasswordRequest req)
        {
            var (ok, err, status) = await _auth.ResetPasswordAsync(req);
            if (!ok)
                return status == 404 ? NotFound(new { error = err }) : BadRequest(new { error = err });
            return Ok(new { success = true, message = "Jelszó frissítve. Jelentkezz be az új jelszóval." });
        }

        [HttpGet("check-email")]
        [AllowAnonymous]
        public async Task<ActionResult<object>> CheckEmail([FromQuery] string email)
        {
            if (string.IsNullOrWhiteSpace(email))
                return BadRequest(new { error = "E-mail megadása kötelező." });

            return Ok(new { occupied = await _auth.EmailTakenAsync(email) });
        }

        [HttpGet("check-username")]
        [AllowAnonymous]
        public async Task<ActionResult<object>> CheckUsername([FromQuery] string username)
        {
            if (string.IsNullOrWhiteSpace(username))
                return BadRequest(new { error = "Felhasználónév megadása kötelező." });

            return Ok(new { occupied = await _auth.UsernameTakenAsync(username) });
        }

        [HttpGet("me")]
        [Authorize]
        public ActionResult<object> Me()
        {
            return Ok(new
            {
                userId = User.FindFirst("uid")?.Value,
                userName = User.FindFirst("username")?.Value ?? User.Identity?.Name,
                email = User.FindFirst(System.Security.Claims.ClaimTypes.Email)?.Value
                    ?? User.FindFirst("email")?.Value,
            });
        }

        /// <summary>Closed-beta: list registered accounts (no passwords).</summary>
        [HttpGet("users")]
        [AllowAnonymous]
        public async Task<ActionResult<object>> ListUsers()
        {
            var users = await _auth.ListUsersAsync();
            return Ok(new { count = users.Count, users });
        }

        private static object ToResponse(AuthTokenResponse r, string message) => new
        {
            success = true,
            message,
            accessToken = r.AccessToken,
            refreshToken = r.RefreshToken,
            expiresIn = r.ExpiresIn,
            userId = r.UserId,
            userName = r.UserName,
            email = r.Email,
            county = r.County,
            weightUnit = r.WeightUnit,
        };
    }
}
