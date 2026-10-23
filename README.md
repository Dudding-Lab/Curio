# Curio – Neustart

Sauberes Projektfundament für die Curio-App (Flutter + Supabase).

**Repository:** https://github.com/Dudding-Lab/Curio  
**Supabase-Projekt:** https://tgawxheqrcqhcvxaexvd.supabase.co

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

### 2. Supabase-Migrationen anwenden
Im Supabase-Dashboard (SQL Editor) die Dateien aus `supabase/migrations/` ausführen  
oder lokal mit der Supabase CLI:
```bash
supabase link --project-ref tgawxheqrcqhcvxaexvd
supabase db push
```

### 3. Flutter-App starten
```bash
cd flutter_app
flutter pub get
flutter run \
  --dart-define=SUPABASE_URL=https://tgawxheqrcqhcvxaexvd.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=IHR_ANON_KEY
```

> **Sicherheit:** Den Anon-Key niemals in Git committen. Verwenden Sie `--dart-define` oder eine lokale `.env`-Datei (bereits in `.gitignore`).

## Wichtige Sicherheitsregeln
- Service-Role-Key niemals im Flutter-Client
- Keine Secrets in Git
- Alle Tabellen mit RLS abgesichert
- Schema-Änderungen nur über Migrationen

Siehe `docs/` für Details.
