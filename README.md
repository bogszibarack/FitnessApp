# 🏋️‍♂️ FitnessApp - Hevy & Yazio Kombinálása (Folyamatos fejlesztés alatt)

Egy könnyen indítható, modern és intelligens webalkalmazás/API háttér, ami egyetlen közös rendszerbe fésüli össze az edzésnaplózást (Hevy logika) és a kalóriaszámlálást (Yazio logika). 

A fejlesztés során a legnagyobb kihívást az interneten található, sokszor hiányos vagy eltérő struktúrájú külső API-k (GitHub edzésadatbázisok, jóga források, Open Food Facts) egységesítése és lekezelése jelentette.

---

## 🛠 Tech Stack

| Réteg | Technológia / Keretrendszer | Leírás |
| :--- | :--- | :--- |
| **Backend** | ⚡ .NET 9 Web API | Kontroller-alapú, nagyteljesítményű architektúra |
| **Frontend** | 💙 Flutter / Dart | Cross-platform mobilalkalmazás (iOS & Android) |
| **Adatbázis** | 🧠 In-Memory / State tárolás | Centralizált tárolás a maximális sebességért és az azonnali, konfigurációmentes indításért |
| **Környezet** | 🐳 Docker | Konténerizált produkciós futtatás |
| **Hosting** | ☁️ Render.com | Automatikus felhő alapú hosting |

### 🌐 Külső Integrációk
* **Open Food Facts API:** 3M+ élelmiszer és tápanyagadat lekezelése.
* **TheMealDB API & AlexCumplido Yoga API:** Receptek és jóga források integrációja.
* **GitHub Free Exercise DB:** Központi edzésadatbázis alapok.

---

## 📁 Projekt Struktúra

```text
FitnessApp/
├── frontend/               # A Flutter mobilalkalmazás forráskódja
│   ├── lib/
│   │   └── config/         # api_config.dart (API végpontok)
│   └── pubspec.yaml        # Flutter csomagkezelő
├── Controllers/            # .NET API Kontrollerek (Menu, Edzés, Beállítások)
├── Data/                   # Adatbázis statikus állományok & Centralized State
├── Program.cs              # .NET Alkalmazás belépési pont és inicializáció
├── FitnessBackend.csproj   # .NET Projektfájl
└── Dockerfile              # Produkciós Docker konfiguráció Render-hez
