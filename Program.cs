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

// Spoonacular API kulcs (receptekhez)
FitnessBackend.Models.SpoonacularConfig.ApiKey =
    builder.Configuration["Spoonacular:ApiKey"]
    ?? Environment.GetEnvironmentVariable("SPOONACULAR_API_KEY")
    ?? "";

// USDA FoodData Central API kulcs (étel kereséshez — ingyenes, korlátlan)
FitnessBackend.Models.UsdaConfig.ApiKey =
    builder.Configuration["Usda:ApiKey"]
    ?? Environment.GetEnvironmentVariable("USDA_API_KEY")
    ?? "";

var szelfi_mappa = Path.Combine(app.Environment.WebRootPath, "uploads", "selfies");
Directory.CreateDirectory(szelfi_mappa);
Directory.CreateDirectory(Path.Combine(app.Environment.WebRootPath, "uploads", "profiles"));

if (app.Environment.IsDevelopment())
{
    app.UseSwagger();
    app.UseSwaggerUI();
}

app.UseCors();
app.UseStaticFiles();

app.MapControllers();

app.Run();