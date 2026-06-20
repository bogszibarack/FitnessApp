using Microsoft.AspNetCore.Mvc;

namespace FitnessBackend.Controllers
{
    /// <summary>
    /// Kép-proxy — a külső képeket (Spoonacular, Open Food Facts) a saját szerverünkön
    /// keresztül szolgáljuk ki, hogy Flutter weben (CanvasKit) ne bukjanak el CORS miatt.
    /// </summary>
    [ApiController]
    [Route("api/[controller]")]
    public class KepController : ControllerBase
    {
        private static readonly HttpClient kliens = new HttpClient();

        private static readonly string[] engedelyezett_hostok =
        {
            "img.spoonacular.com",
            "spoonacular.com",
            "images.openfoodfacts.org",
            "world.openfoodfacts.org",
            "static.openfoodfacts.org"
        };

        [HttpGet]
        public async Task<IActionResult> Proxy([FromQuery] string url)
        {
            if (string.IsNullOrWhiteSpace(url) || !Uri.TryCreate(url, UriKind.Absolute, out var uri))
            {
                return BadRequest("Ervenytelen kep url.");
            }

            if (uri.Scheme != Uri.UriSchemeHttps && uri.Scheme != Uri.UriSchemeHttp)
            {
                return BadRequest("Csak http/https kep tolthet le.");
            }

            bool engedelyezett = engedelyezett_hostok.Any(h =>
                uri.Host.Equals(h, StringComparison.OrdinalIgnoreCase) ||
                uri.Host.EndsWith("." + h, StringComparison.OrdinalIgnoreCase));

            if (!engedelyezett)
            {
                return BadRequest("Ez a kep-forras nincs engedelyezve.");
            }

            try
            {
                using var valasz = await kliens.GetAsync(uri);
                if (!valasz.IsSuccessStatusCode)
                {
                    return StatusCode((int)valasz.StatusCode, "Nem sikerult letolteni a kepet.");
                }

                var tartalom = await valasz.Content.ReadAsByteArrayAsync();
                string tipus = valasz.Content.Headers.ContentType?.MediaType ?? "image/jpeg";

                Response.Headers.CacheControl = "public, max-age=86400";
                return File(tartalom, tipus);
            }
            catch (Exception)
            {
                return StatusCode(502, "Kep letoltesi hiba.");
            }
        }
    }
}
