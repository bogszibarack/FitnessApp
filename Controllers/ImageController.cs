using Microsoft.AspNetCore.Mvc;

namespace FitnessBackend.Controllers
{
    [ApiController]
    [Route("api/image")]
    public class ImageController : ControllerBase
    {
        private static readonly HttpClient Client = new();

        private static readonly string[] AllowedHosts =
        {
            "images.openfoodfacts.org",
            "world.openfoodfacts.org",
            "static.openfoodfacts.org",
            "image-api.nosalty.hu",
            "www.nosalty.hu",
            "nosalty.hu",
        };

        [HttpGet]
        public async Task<IActionResult> Proxy([FromQuery] string url)
        {
            if (string.IsNullOrWhiteSpace(url) || !Uri.TryCreate(url, UriKind.Absolute, out var uri))
                return BadRequest("Ervenytelen kep url.");

            if (uri.Scheme != Uri.UriSchemeHttps && uri.Scheme != Uri.UriSchemeHttp)
                return BadRequest("Csak http/https kep tolthet le.");

            var allowed = AllowedHosts.Any(h =>
                uri.Host.Equals(h, StringComparison.OrdinalIgnoreCase) ||
                uri.Host.EndsWith("." + h, StringComparison.OrdinalIgnoreCase));

            if (!allowed)
                return BadRequest("Ez a kep-forras nincs engedelyezve.");

            try
            {
                using var response = await Client.GetAsync(uri);
                if (!response.IsSuccessStatusCode)
                    return StatusCode((int)response.StatusCode, "Nem sikerult letolteni a kepet.");

                var bytes = await response.Content.ReadAsByteArrayAsync();
                var type = response.Content.Headers.ContentType?.MediaType ?? "image/jpeg";

                Response.Headers.CacheControl = "public, max-age=86400";
                return File(bytes, type);
            }
            catch
            {
                return StatusCode(502, "Kep letoltesi hiba.");
            }
        }
    }
}
