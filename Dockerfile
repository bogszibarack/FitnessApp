FROM mcr.microsoft.com/dotnet/sdk:9.0 AS build
WORKDIR /src

# Másoljuk a csproj-t és visszaállítjuk a csomagokat
COPY ["FitnessBackend.csproj", "."]
RUN dotnet restore "FitnessBackend.csproj"

# Másoljuk az összes többi fájlt és buildeljük a projektet
COPY . .
RUN dotnet build "FitnessBackend.csproj" -c Release -o /app/build

FROM build AS publish
RUN dotnet publish "FitnessBackend.csproj" -c Release -o /app/publish /p:UseAppHost=false

# Végső futtató környezet kialakítása
FROM mcr.microsoft.com/dotnet/aspnet:9.0 AS final
WORKDIR /app
COPY --from=publish /app/publish .
ENTRYPOINT ["dotnet", "FitnessBackend.dll"]