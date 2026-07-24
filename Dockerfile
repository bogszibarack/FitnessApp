FROM mcr.microsoft.com/dotnet/sdk:8.0 AS build
WORKDIR /src

COPY ["FitnessBackend.csproj", "."]
RUN dotnet restore "FitnessBackend.csproj"

COPY . .
RUN dotnet build "FitnessBackend.csproj" -c Release -o /app/build

FROM build AS publish
RUN dotnet publish "FitnessBackend.csproj" -c Release -o /app/publish /p:UseAppHost=false

# Runtime must match TargetFramework (net8.0) — not 9.0
FROM mcr.microsoft.com/dotnet/aspnet:8.0 AS final
WORKDIR /app
COPY --from=publish /app/publish .

ENV ASPNETCORE_URLS=http://0.0.0.0:8080
EXPOSE 8080
ENTRYPOINT ["sh", "-c", "dotnet FitnessBackend.dll --urls http://0.0.0.0:${PORT:-8080}"]
