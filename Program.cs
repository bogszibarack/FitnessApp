var builder = WebApplication.CreateBuilder(args);

builder.Services.AddControllers();
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

// FatSecret Platform API keys (food search + barcode)
FitnessBackend.Services.FatSecretConfig.ClientId =
    builder.Configuration["FatSecret:ClientId"]
    ?? Environment.GetEnvironmentVariable("FATSECRET_CLIENT_ID")
    ?? "";

FitnessBackend.Services.FatSecretConfig.ClientSecret =
    builder.Configuration["FatSecret:ClientSecret"]
    ?? Environment.GetEnvironmentVariable("FATSECRET_CLIENT_SECRET")
    ?? "";

// Spoonacular API key (recipes — secondary)
FitnessBackend.Services.SpoonacularConfig.ApiKey =
    builder.Configuration["Spoonacular:ApiKey"]
    ?? Environment.GetEnvironmentVariable("SPOONACULAR_API_KEY")
    ?? "";

// Perzisztált adatok betöltése induláskor
FitnessBackend.Controllers.WorkoutController.LoadOnStartup();

string baseRoot = app.Environment.WebRootPath ?? AppContext.BaseDirectory;
var szelfi_mappa = Path.Combine(baseRoot, "uploads", "selfies");
Directory.CreateDirectory(szelfi_mappa);
Directory.CreateDirectory(Path.Combine(baseRoot, "uploads", "profiles"));

if (app.Environment.IsDevelopment())
{
    app.UseSwagger();
    app.UseSwaggerUI();
}

app.UseCors();
app.UseStaticFiles();

app.MapControllers();

app.Run();