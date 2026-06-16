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