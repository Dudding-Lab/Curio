# Curio – Neustart

Sauberes Projektfundament für die Curio-App (Flutter + Supabase).

**Repository:** https://github.com/Dudding-Lab/Curio

## Kernkonzept
- **Haushalte (Households)**: Gemeinsame Arbeitsräume für Sammlungen
- **Sammlungen (Collections)**: Gruppen von Items (z. B. Bücher, Spiele, Figuren)
- **Items**: Einzelne Objekte in einer Sammlung
- **Medien (Media Assets)**: Bilder/Dateien zu Items
- **AI Jobs**: Asynchrone KI-Aufgaben (Erkennung, Beschreibung, Katalogisierung)
- **Locations**: Standorte für die „Wo ist“-Funktion (Liste + Grundriss)
- **Lending**: Vorbereitete Ausleihe (Patrons, Loans)

## Stack
- **Frontend**: Flutter (Windows, Android, iOS, optional Web)
- **Backend**: Supabase (Postgres, Auth, Storage, Edge Functions, RLS)
- **State Management**: Riverpod
- **Navigation**: go_router
- **Dokumentation**: Markdown in `/docs`

## Projektstruktur
```
/
├── docs/                  # Anforderungen, Architektur, Schema-Readiness
├── supabase/
│   └── migrations/        # Alle SQL-Migrationen (initial + lending)
├── flutter_app/           # Flutter-Grundgerüst
│   ├── lib/
│   │   ├── main.dart
│   │   ├── core/          # Theme, Router
│   │   └── screens/       # Auth, Households, …
│   └── pubspec.yaml
└── README.md
```

## Schnellstart

### 1. Repository klonen
```bash
git clone https://github.com/Dudding-Lab/Curio.git
cd Curio
```

### 2. Supabase lokal starten
```bash
supabase init   # falls noch nicht geschehen
supabase start
supabase db reset
```

### 3. Flutter-App
```bash
cd flutter_app
flutter pub get
flutter run --dart-define=SUPABASE_URL=your_url --dart-define=SUPABASE_ANON_KEY=your_anon_key
```

## Wichtige Sicherheitsregeln
- Service-Role-Key niemals im Flutter-Client
- Keine Secrets in Git
- Alle Tabellen mit RLS abgesichert
- Schema-Änderungen nur über Migrationen

Siehe `docs/` für Details.
