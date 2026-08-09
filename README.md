# 🏋️‍♂️ FitnessApp - Hevy & Yazio Kombinálása (Folyamatos fejlesztés alatt)

Egy könnyen indítható, modern és intelligens webalkalmazás/API háttér, ami egyetlen közös rendszerbe fésüli össze az edzésnaplózást (Hevy logika) és a kalóriaszámlálást (Yazio logika). 

A fejlesztés során a legnagyobb kihívást az interneten található, sokszor hiányos vagy eltérő struktúrájú külső API-k (GitHub edzésadatbázisok, jóga források, Open Food Facts) egységesítése és lekezelése jelentette.

---

## 🛠 Tech Stack

| Réteg | Technológia / Keretrendszer | Leírás |
| :--- | :--- | :--- |
| **Backend** | ⚡ .NET 8 Web API | Kontroller-alapú, JWT auth + EF Core |
| **Frontend** | 💙 Flutter / Dart | Cross-platform mobilalkalmazás (iOS & Android) |
| **Adatbázis** | 🐘 PostgreSQL (+ JSON / SQLite fallback) | Felhasználók, refresh tokenek és közösség (barátok, posztok) Postgresben; edzések / rutinok / napló JSON fájlokban (`DATA_DIR`). Lokálisan Postgres nélkül SQLite. |
| **Auth / E-mail** | 🔐 JWT + SMTP | Bcrypt jelszóhash, access/refresh token; üdvözlő mail és elfelejtett jelszó (ideiglenes kód → új jelszó az appban) |
| **Környezet** | 🐳 Docker | Konténerizált produkciós futtatás |
| **Hosting** | ☁️ Render.com | Automatikus felhő alapú hosting (`DATABASE_URL`, disk `/var/data`) |

### 🌐 Külső Integrációk
* **FatSecret API:** Ételkeresés és vonalkódos termékadatok.
* **Open Food Facts API:** 3M+ élelmiszer és tápanyagadat lekezelése (képproxy).
* **Nosalty.hu:** Magyar receptböngészés (HTML / schema.org).
* **GitHub Free Exercise DB:** Központi edzésadatbázis alapok.

---

## 📁 Projekt Struktúra

```text
FitnessApp/
├── frontend/               # A Flutter mobilalkalmazás forráskódja
│   ├── lib/
│   │   └── config/         # api_config.dart (API végpontok)
│   └── pubspec.yaml        # Flutter csomagkezelő
├── Controllers/            # .NET API Kontrollerek (Auth, Edzés, Közösség, Beállítások…)
├── Data/                   # EF Core (AppUser, community entitások) + JSON seed fájlok
├── Services/               # Auth, Email, CommunityDb, FatSecret, Nosalty…
├── Program.cs              # .NET Alkalmazás belépési pont és inicializáció
├── FitnessBackend.csproj   # .NET Projektfájl
└── Dockerfile              # Produkciós Docker konfiguráció Render-hez
```
