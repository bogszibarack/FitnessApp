using System.Text;
using FitnessBackend.Data;
using FitnessBackend.Services;
using Microsoft.AspNetCore.Authentication.JwtBearer;
using Microsoft.AspNetCore.Builder;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Hosting;
using Microsoft.Extensions.Logging;
using Microsoft.IdentityModel.Tokens;

var builder = WebApplication.CreateEmptyBuilder(new WebApplicationOptions
{
    Args = args,
    ContentRootPath = AppContext.BaseDirectory,
});

builder.Configuration
    .AddJsonFile("appsettings.json", optional: true, reloadOnChange: false)
    .AddJsonFile(
        $"appsettings.{builder.Environment.EnvironmentName}.json",
        optional: true,
        reloadOnChange: false)
    .AddEnvironmentVariables();

if (args is { Length: > 0 })
    builder.Configuration.AddCommandLine(args);

builder.Logging.AddConfiguration(builder.Configuration.GetSection("Logging"));
builder.Logging.AddConsole();

builder.WebHost.UseKestrel();
builder.WebHost.UseContentRoot(AppContext.BaseDirectory);
builder.WebHost.UseWebRoot(Path.Combine(AppContext.BaseDirectory, "wwwroot"));

// --- Database (Render DATABASE_URL → Postgres; local → SQLite) ---
var rawDb =
    builder.Configuration["DATABASE_URL"]
    ?? Environment.GetEnvironmentVariable("DATABASE_URL")
    ?? builder.Configuration.GetConnectionString("Default");

var (provider, connectionString) = ResolveDatabase(rawDb);
builder.Services.AddDbContext<AppDbContext>(opt =>
{
    if (provider == "postgres")
        opt.UseNpgsql(connectionString);
    else
        opt.UseSqlite(connectionString);
});

// --- JWT ---
var jwtSection = builder.Configuration.GetSection(JwtOptions.SectionName);
var jwt = jwtSection.Get<JwtOptions>() ?? new JwtOptions();
if (string.IsNullOrWhiteSpace(jwt.Key) || jwt.Key.Length < 32)
    jwt.Key = "FlexioDevOnlyChangeMe_UseLongSecretInProduction_32+chars!";
builder.Services.Configure<JwtOptions>(opts =>
{
    opts.Key = jwt.Key;
    opts.Issuer = jwt.Issuer;
    opts.Audience = jwt.Audience;
    opts.AccessTokenMinutes = jwt.AccessTokenMinutes;
    opts.RefreshTokenDays = jwt.RefreshTokenDays;
});
builder.Services.AddSingleton<JwtTokenService>();
builder.Services.AddScoped<AuthService>();

builder.Services
    .AddAuthentication(JwtBearerDefaults.AuthenticationScheme)
    .AddJwtBearer(options =>
    {
        options.TokenValidationParameters = new TokenValidationParameters
        {
            ValidateIssuer = true,
            ValidateAudience = true,
            ValidateLifetime = true,
            ValidateIssuerSigningKey = true,
            ValidIssuer = jwt.Issuer,
            ValidAudience = jwt.Audience,
            IssuerSigningKey = new SymmetricSecurityKey(Encoding.UTF8.GetBytes(jwt.Key)),
            ClockSkew = TimeSpan.FromMinutes(1),
        };
    });
builder.Services.AddAuthorization();

builder.Services.AddRouting();
builder.Services.AddControllers()
    .AddJsonOptions(o =>
    {
        o.JsonSerializerOptions.PropertyNameCaseInsensitive = true;
    });
builder.Services.AddCors(options =>
{
    options.AddDefaultPolicy(policy =>
    {
        policy.AllowAnyOrigin().AllowAnyMethod().AllowAnyHeader();
    });
});

builder.Services.AddEndpointsApiExplorer();
builder.Services.AddSwaggerGen();

var app = builder.Build();
app.UseCors();

FitnessBackend.Services.FatSecretConfig.ClientId =
    builder.Configuration["FatSecret:ClientId"]
    ?? Environment.GetEnvironmentVariable("FATSECRET_CLIENT_ID")
    ?? "";

FitnessBackend.Services.FatSecretConfig.ClientSecret =
    builder.Configuration["FatSecret:ClientSecret"]
    ?? Environment.GetEnvironmentVariable("FATSECRET_CLIENT_SECRET")
    ?? "";

FitnessBackend.Services.SpoonacularConfig.ApiKey =
    builder.Configuration["Spoonacular:ApiKey"]
    ?? Environment.GetEnvironmentVariable("SPOONACULAR_API_KEY")
    ?? "";

// Load JSON stores (workouts etc.) then ensure DB schema + migrate accounts
FitnessBackend.Controllers.WorkoutController.LoadOnStartup();

using (var scope = app.Services.CreateScope())
{
    var db = scope.ServiceProvider.GetRequiredService<AppDbContext>();
    var logger = scope.ServiceProvider.GetRequiredService<ILoggerFactory>().CreateLogger("Startup");
    try
    {
        await db.Database.EnsureCreatedAsync();
        logger.LogInformation("[DB] Provider={Provider}", provider);
        await JsonAccountMigrator.MigrateAsync(db, logger);

        // Legacy JSON data → only an explicit owner (never "first registered user").
        var legacyOwner =
            Environment.GetEnvironmentVariable("LEGACY_DATA_OWNER")
            ?? await db.Users
                .Where(u => u.Username.ToLower() == "bogszibarack_dev")
                .Select(u => u.Username)
                .FirstOrDefaultAsync();

        if (!string.IsNullOrWhiteSpace(legacyOwner))
        {
            FitnessBackend.Controllers.WorkoutController.AssignLegacyOwner(legacyOwner);
            // One-time fix: earlier fallback may have attached shared data to the wrong account.
            FitnessBackend.Controllers.WorkoutController.ConsolidateAllToOwnerOnce(legacyOwner);
            logger.LogInformation("[Workout] Legacy data owner: {User}", legacyOwner);
        }
        else
        {
            logger.LogWarning("[Workout] No LEGACY_DATA_OWNER / bogszibarack_dev — unowned JSON left unassigned.");
        }
    }
    catch (Exception ex)
    {
        logger.LogError(ex, "[DB] Startup migration failed");
        throw;
    }
}

string baseRoot = app.Environment.WebRootPath ?? AppContext.BaseDirectory;
Directory.CreateDirectory(Path.Combine(baseRoot, "uploads", "selfies"));
Directory.CreateDirectory(Path.Combine(baseRoot, "uploads", "profiles"));

if (app.Environment.IsDevelopment())
{
    app.UseSwagger();
    app.UseSwaggerUI();
}

app.UseCors();
app.UseAuthentication();
app.UseAuthorization();
app.UseStaticFiles();
app.MapControllers();

app.Run();

static (string Provider, string ConnectionString) ResolveDatabase(string? raw)
{
    if (string.IsNullOrWhiteSpace(raw))
    {
        var dir = Environment.GetEnvironmentVariable("DATA_DIR");
        if (string.IsNullOrWhiteSpace(dir))
            dir = Path.Combine(Directory.GetCurrentDirectory(), "data");
        Directory.CreateDirectory(dir);
        var sqlitePath = Path.Combine(dir, "flexio.db");
        return ("sqlite", $"Data Source={sqlitePath}");
    }

    if (raw.StartsWith("postgres://", StringComparison.OrdinalIgnoreCase) ||
        raw.StartsWith("postgresql://", StringComparison.OrdinalIgnoreCase))
    {
        // .NET Uri can mis-parse postgres:// — normalize via http:// first.
        var normalized = "http://" + raw[(raw.IndexOf("://", StringComparison.Ordinal) + 3)..];
        var uri = new Uri(normalized);
        var userInfo = uri.UserInfo.Split(':', 2);
        var user = Uri.UnescapeDataString(userInfo[0]);
        var pass = userInfo.Length > 1 ? Uri.UnescapeDataString(userInfo[1]) : "";
        var dbName = uri.AbsolutePath.Trim('/');
        if (string.IsNullOrWhiteSpace(dbName))
            dbName = "flexio_db";
        var port = uri.Port > 0 && uri.Port != 80 ? uri.Port : 5432;
        var cs =
            $"Host={uri.Host};Port={port};" +
            $"Database={dbName};Username={user};Password={pass};" +
            "SSL Mode=Require;Trust Server Certificate=true";
        Console.WriteLine($"[DB] Postgres Host={uri.Host} Database={dbName}");
        return ("postgres", cs);
    }

    // Already a key=value connection string
    if (raw.Contains("Host=", StringComparison.OrdinalIgnoreCase) ||
        raw.Contains("Server=", StringComparison.OrdinalIgnoreCase))
        return ("postgres", raw);

    return ("sqlite", raw);
}
