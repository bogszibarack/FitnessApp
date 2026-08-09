using System.Security.Claims;
using Microsoft.AspNetCore.Mvc;

namespace FitnessBackend.Services
{
    public static class CurrentUser
    {
        public static string? UserName(ClaimsPrincipal? user)
        {
            if (user?.Identity?.IsAuthenticated != true)
                return null;

            var name =
                user.FindFirst("username")?.Value
                ?? user.FindFirst(ClaimTypes.Name)?.Value
                ?? user.FindFirst(ClaimTypes.NameIdentifier)?.Value
                ?? user.Identity?.Name;

            return string.IsNullOrWhiteSpace(name) ? null : name.Trim();
        }

        public static string? UserId(ClaimsPrincipal? user) =>
            user?.FindFirst("uid")?.Value
            ?? user?.FindFirst(ClaimTypes.NameIdentifier)?.Value;

        /// <summary>Returns 401 result when missing; otherwise sets userName.</summary>
        public static ActionResult? RequireUser(ControllerBase ctrl, out string userName)
        {
            userName = UserName(ctrl.User) ?? "";
            if (string.IsNullOrEmpty(userName))
                return ctrl.Unauthorized(new { error = "Bejelentkezés szükséges." });
            return null;
        }

        public static ActionResult? RequireUserId(ControllerBase ctrl, out Guid userId)
        {
            userId = Guid.Empty;
            var raw = UserId(ctrl.User);
            if (string.IsNullOrWhiteSpace(raw) || !Guid.TryParse(raw, out userId))
                return ctrl.Unauthorized(new { error = "Bejelentkezés szükséges." });
            return null;
        }
    }
}
