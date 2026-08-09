using MailKit.Net.Smtp;
using MailKit.Security;
using MimeKit;

namespace FitnessBackend.Services
{
    public class EmailOptions
    {
        public const string SectionName = "Email";

        public string Host { get; set; } = "";
        public int Port { get; set; } = 587;
        public string User { get; set; } = "";
        public string Password { get; set; } = "";
        public string From { get; set; } = "";
        public string FromName { get; set; } = "Flexio";
        public bool UseSsl { get; set; } = true;
    }

    public interface IEmailSender
    {
        bool IsConfigured { get; }
        Task SendAsync(string toEmail, string subject, string textBody, string? htmlBody = null);
    }

    public class SmtpEmailSender : IEmailSender
    {
        private readonly EmailOptions _opts;
        private readonly ILogger<SmtpEmailSender> _logger;

        public SmtpEmailSender(Microsoft.Extensions.Options.IOptions<EmailOptions> opts, ILogger<SmtpEmailSender> logger)
        {
            _opts = opts.Value;
            _logger = logger;
        }

        public bool IsConfigured =>
            !string.IsNullOrWhiteSpace(_opts.Host) &&
            !string.IsNullOrWhiteSpace(_opts.From);

        public async Task SendAsync(string toEmail, string subject, string textBody, string? htmlBody = null)
        {
            if (!IsConfigured)
                throw new InvalidOperationException(
                    "Email küldés nincs beállítva. Add meg az Email:Host / Email:From (vagy SMTP_HOST / SMTP_FROM) értékeket.");

            var message = new MimeMessage();
            message.From.Add(new MailboxAddress(
                string.IsNullOrWhiteSpace(_opts.FromName) ? "Flexio" : _opts.FromName,
                _opts.From));
            message.To.Add(MailboxAddress.Parse(toEmail));
            message.Subject = subject;

            var builder = new BodyBuilder
            {
                TextBody = textBody,
                HtmlBody = htmlBody ?? $"<pre style=\"font-family:sans-serif\">{System.Net.WebUtility.HtmlEncode(textBody)}</pre>",
            };
            message.Body = builder.ToMessageBody();

            using var client = new SmtpClient();
            var secure = _opts.UseSsl
                ? (_opts.Port == 465 ? SecureSocketOptions.SslOnConnect : SecureSocketOptions.StartTls)
                : SecureSocketOptions.None;

            await client.ConnectAsync(_opts.Host, _opts.Port, secure);

            if (!string.IsNullOrWhiteSpace(_opts.User))
                await client.AuthenticateAsync(_opts.User, _opts.Password ?? "");

            await client.SendAsync(message);
            await client.DisconnectAsync(true);

            _logger.LogInformation("[Email] Sent '{Subject}' to {To}", subject, toEmail);
        }
    }

    public static class AuthEmailTemplates
    {
        public static (string Subject, string Text, string Html) Welcome(string userName)
        {
            var subject = "Sikeres regisztráció – Flexio";
            var text =
                $"Szia {userName}!\n\n" +
                "Sikeresen regisztráltál a Flexio alkalmazásba.\n" +
                "Mostantól naplózhatod az edzéseidet, követheted a táplálkozásod, és csatlakozhatsz a közösséghez.\n\n" +
                "Jó edzést!\n" +
                "A Flexio csapat";

            var html =
                $"<div style=\"font-family:Arial,sans-serif;line-height:1.5;color:#222\">" +
                $"<h2 style=\"color:#1E88E5\">Sikeres regisztráció</h2>" +
                $"<p>Szia <strong>{System.Net.WebUtility.HtmlEncode(userName)}</strong>!</p>" +
                "<p>Sikeresen regisztráltál a <strong>Flexio</strong> alkalmazásba.</p>" +
                "<p>Mostantól naplózhatod az edzéseidet, követheted a táplálkozásod, és csatlakozhatsz a közösséghez.</p>" +
                "<p>Jó edzést!<br/>A Flexio csapat</p>" +
                "</div>";

            return (subject, text, html);
        }

        public static (string Subject, string Text, string Html) TemporaryPassword(
            string userName, string tempPassword)
        {
            var subject = "Új ideiglenes jelszó – Flexio";
            var text =
                $"Szia {userName}!\n\n" +
                "Jelszó-emlékeztetőt kértél a Flexio fiókodhoz.\n" +
                "A biztonság miatt a régi jelszó nem állítható vissza (titkosítva tároljuk),\n" +
                "ezért új ideiglenes jelszót generáltunk:\n\n" +
                $"  {tempPassword}\n\n" +
                "Jelentkezz be ezzel, majd a Beállításokban azonnal cseréld le saját jelszóra.\n" +
                "Ha nem te kérted, jelentkezz be és változtasd meg a jelszót.\n\n" +
                "A Flexio csapat";

            var html =
                $"<div style=\"font-family:Arial,sans-serif;line-height:1.5;color:#222\">" +
                $"<h2 style=\"color:#1E88E5\">Új ideiglenes jelszó</h2>" +
                $"<p>Szia <strong>{System.Net.WebUtility.HtmlEncode(userName)}</strong>!</p>" +
                "<p>Jelszó-emlékeztetőt kértél. A biztonság miatt a régi jelszó nem küldhető el " +
                "(titkosítva tároljuk), ezért új ideiglenes jelszót generáltunk:</p>" +
                $"<p style=\"font-size:20px;font-weight:700;letter-spacing:1px;" +
                $"background:#F5F7FA;padding:12px 16px;border-radius:8px;display:inline-block\">" +
                $"{System.Net.WebUtility.HtmlEncode(tempPassword)}</p>" +
                "<p>Jelentkezz be ezzel, majd a Beállításokban cseréld le saját jelszóra.</p>" +
                "<p>A Flexio csapat</p>" +
                "</div>";

            return (subject, text, html);
        }
    }
}
