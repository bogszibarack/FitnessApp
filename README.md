# 🏋️‍♂️ FitnessApp - Hevy & Yazio Kombinálása

Egy könnyen indítható, modern és intelligens webalkalmazás/API háttér, ami egyetlen közös rendszerbe fésüli össze az edzésnaplózást (Hevy logika) és a kalóriaszámlálást (Yazio logika). 

A fejlesztés során a legnagyobb kihívást az interneten található, sokszor hiányos vagy eltérő struktúrájú külső API-k (GitHub edzésadatbázisok, jóga források, Open Food Facts) egységesítése és lekezelése jelentette.

---

## 🛠 Tech Stack

* **Backend:** .NET 8 Web API (Kontroller-alapú architektúra)
* **Frontend:** Cross-platform mobilalkalmazás (Flutter / Dart architektúra)
* **Adatbázis:** In-Memory / Centralized State tárolás a maximális sebességért és az azonnali, konfigurációmentes indításért (később szerver)
* **API Dokumentáció:** Swagger / OpenAPI UI
* **Külső Integrációk:** Open Food Facts API (3M+ élelmiszer), TheMealDB API, GitHub Free Exercise DB, AlexCumplido Yoga API

---

## 🚀 Telepítési és Indítási Útmutató

### Előfeltételek
* [.NET 8 SDK](https://dotnet.microsoft.com/en-us/download/dotnet/8.0)
* [Flutter SDK](https://docs.flutter.dev/get-started/install) (a mobilalkalmazás futtatásához)

### 1. A Backend futtatása (.NET API)
Nyiss egy terminált a projekt gyökérmappájában, majd indítsd el a szervert:
```bash , dotnet run

### 2. A Frontend futtatása (Flutter)

Nyiss egy **második terminál fület** (vagy ablakot) és lépj be a frontend könyvtárba:
```bash
cd frontend
flutter pub get
flutter run
