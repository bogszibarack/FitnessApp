# Flexio (FitnessApp)

Flutter mobilapp + ASP.NET Core API: edzésnapló, táplálkozás, közösség és JWT-s fiókkezelés egy rendszerben.

Éles API: `https://fitnessapp-fnfv.onrender.com`

---

## Tech stack

| Réteg | Technológia |
| :--- | :--- |
| Backend | .NET 8 Web API (`FitnessBackend`) |
| Frontend | Flutter / Dart (`frontend/`) |
| Auth | JWT (access + refresh), bcrypt jelszóhash |
| Adatbázis | **PostgreSQL** (Render Free) felhasználókhoz / közösséghez; edzések/tervek/napló továbbra is JSON fájlokban (`DATA_DIR`) |
| Lokális DB fallback | SQLite, ha nincs `DATABASE_URL` |
| Hosting | Docker → Render.com |
| E-mail | SMTP (MailKit) – üdvözlő + jelszó-emlékeztető |

### Külső integrációk

- **FatSecret** – ételkeresés / vonalkód
- **Open Food Facts** – élelmiszer adatok (képproxy)
- **Nosalty.hu** – receptböngészés (HTML / schema.org)
- **Exercise DB** – gyakorlatkatalógus

---

## Főbb funkciók (aktuális)

### Fiók & biztonság
- Regisztráció / bejelentkezés JWT-vel (access + refresh, automatikus frissítés a Flutter `ApiHttp`-ban)
- Jelszavak **bcrypt** hash-ként (a régi jelszó nem állítható vissza)
- Regisztráció után **üdvözlő e-mail** (ha SMTP be van állítva)
- **Elfelejtett jelszó:** ideiglenes jelszó e-mailben → appban új jelszó + megerősítés
  - `POST /api/auth/forgot-password`
  - `POST /api/auth/confirm-forgot-password`

### Edzés
- Aktív edzés, előzmény, rutinok, AI tervgenerálás
- Edzés befejezése után opcionális **megosztás a közösségben**

### Közösség (Postgres)
- Feed (poszt / like / komment) – **adatbázisban**, restart után is megmarad
- **Kit ismerhetek** – regisztrált felhasználók listája
- Barátkérés (pending → accept / reject), barátok, pending badge
- Profil: profilkép, barátstátusz, **teljes edzéselőzmény** (teszt mód: publikus), megosztott posztok

### Táplálkozás
- Napló, FatSecret keresés, receptek (Nosalty), streak

---

## Adatbázis & perzisztencia

### PostgreSQL (`AppUser` + community)

`DATABASE_URL` (Render Postgres) → EF Core / Npgsql.

Táblák (részlet):
- `Users`, `RefreshTokens`
- `FriendRequests`, `CommunityPosts`, `PostLikes`, `PostComments`

Startup:
1. `EnsureCreated`
2. `CommunitySchemaBootstrap` – új táblák meglévő DB-hez (`CREATE TABLE IF NOT EXISTS`)
3. `JsonAccountMigrator` – régi `felhasznalok.json` → Users
4. `PostgresUserRepairMigrator` – ha a `DATABASE_URL` véletlenül duplán volt beillesztve (rossz DB név), userek átmásolása a tiszta `flexio_db`-be

### JSON fájlok (`DATA_DIR`, Render disken pl. `/var/data`)

Edzéstörténet, aktív edzés, rutinok, nutrition, streak, settings – felhasználónév szerint szétválasztva (JWT).

Lokálisan, ha nincs Postgres: SQLite fájl a `DATA_DIR` alatt.

---

## Környezeti változók (Render)

| Változó | Cél |
| :--- | :--- |
| `DATABASE_URL` | Render Postgres connection string (**egyszer** illeszd be) |
| `DATA_DIR` | Persistens kötet, pl. `/var/data` |
| `Jwt__Key` | Legalább 32 karakteres titkos kulcs |
| `FATSECRET_CLIENT_ID` / `FATSECRET_CLIENT_SECRET` | Étel API |
| `SMTP_HOST` | pl. `smtp.gmail.com` |
| `SMTP_PORT` | pl. `587` |
| `SMTP_USER` / `SMTP_PASS` | SMTP auth (Gmail: app jelszó) |
| `SMTP_FROM` / `SMTP_FROM_NAME` | Feladó |
| `SMTP_USE_SSL` | `true` (STARTTLS 587-en) |
| `LEGACY_DATA_OWNER` | Opcionális: régi JSON edzések tulajdonosa |

SMTP nélkül: regisztráció működik (üdvözlő e-mail kimarad + log); forgot-password `503`.

---

## Projektstruktúra

```text
FitnessApp/
├── frontend/                 # Flutter app
│   └── lib/
│       ├── config/           # api_config.dart (production URL)
│       ├── services/         # ApiHttp, Auth, Community, Workout…
│       └── screens/          # home, workout, nutrition, community, settings
├── Controllers/              # Auth, Workout, Community, Nutrition…
├── Data/                     # AppDbContext, AppUser, community entitások
├── Services/                 # Auth, Email, CommunityDb, FatSecret, Nosalty…
├── Models/                   # DTO-k, JSON store-ok
├── Program.cs
├── Dockerfile
└── appsettings.json
```

---

## Lokális futtatás

### Backend

```bash
# .NET 8 SDK
dotnet restore
dotnet run --urls http://localhost:5150
```

Postgres nélkül SQLite-ot használ. SMTP-hez állítsd az `Email` szekciót az `appsettings.json`-ban vagy az `SMTP_*` env változókat.

### Flutter (Mac)

```bash
cd frontend
flutter pub get
flutter run
```

- Debug **web**: `http://localhost:5150`
- Telefon / release: `https://fitnessapp-fnfv.onrender.com` (`ApiConfig`)

Git pull előtt, ha lokális csproj/lock ütközik:

```bash
git restore FitnessBackend.csproj frontend/pubspec.lock   # ha kell
git pull
```

---

## Fontos API-k (rövid)

| Metódus | Útvonal | Megjegyzés |
| :--- | :--- | :--- |
| POST | `/api/auth/register-onboarding` | Regisztráció + token + üdvözlő mail |
| POST | `/api/auth/login` | Bejelentkezés |
| POST | `/api/auth/forgot-password` | Ideiglenes jelszó e-mailben |
| POST | `/api/auth/confirm-forgot-password` | Ideiglenes → új jelszó |
| GET | `/api/auth/users` | Closed-beta: fióklista + DB info |
| GET | `/api/community/feed` | Közösségi feed |
| GET | `/api/community/people` | Kit ismerhetek (JWT) |
| POST | `/api/community/friends/request/{username}` | Barátkérés |
| GET | `/api/community/profile/{username}` | Profil + edzéstörténet |
| POST | `/api/workout/aktiv/befejezes-es-megosztas` | Befejezés + megosztás |

---

## Deploy (Render)

1. Docker build a repo gyökeréből (`Dockerfile`, net8.0)
2. Disk mount: `/var/data` → `DATA_DIR`
3. Free Postgres → `DATABASE_URL` (egyszer!)
4. SMTP env a levelekhez
5. Deploy után ellenőrizd: `GET /api/auth/users` → `db.database` legyen a várt DB név (pl. `flexio_db`)

---

## Fejlesztési megjegyzések

- Community write-ok JWT `AppUser`-ből mennek, ne kliens `userName` query-re hagyatkozzanak
- Profil edzéselőzmény most **publikus** (teszt); privacy később
- MealDB / Spoonacular kivezetve – receptek: Nosalty
- Jelszó soha nincs plaintextben tárolva / visszaküldve
