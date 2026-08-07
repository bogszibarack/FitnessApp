namespace FitnessBackend.Services
{
    public class JwtOptions
    {
        public const string SectionName = "Jwt";

        public string Key { get; set; } = "FlexioDevOnlyChangeMe_UseLongSecretInProduction_32+chars!";
        public string Issuer { get; set; } = "Flexio";
        public string Audience { get; set; } = "FlexioApp";
        public int AccessTokenMinutes { get; set; } = 60;
        public int RefreshTokenDays { get; set; } = 90;
    }
}
