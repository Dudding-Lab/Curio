# Curio – Anforderungen und Zielvorgaben

Stand: 2026-10-23 (aktualisiert)

## 1. Primäre Zielsetzung

- Fokus auf private Mediensammlungen, insbesondere Bücher und Medien.
- Ausgelegt für Haushalte und Familien mit mehreren Nutzern.
- Spätere Erweiterbarkeit für kommerzielle Nutzung (Organisationen, Bibliotheken, Inventarverwaltung).
- Unterstützung eines Self-Hosting-Modells, insbesondere für die kommerzielle Nutzung.

## 2. Kernfunktionen

### Haushalte und Zusammenarbeit
- Erstellung und Verwaltung von Haushalten als gemeinsame Arbeitsräume.
- Rollenbasierte Zugriffssteuerung:
  - **Besitzer (Owner)**
  - **Administrator (Admin)**
  - **Nutzer (Member / User)**
  - Optional: Viewer (nur Lesezugriff)
- Weitere Rollen sollen in der kommerziellen Version möglich sein.
- Einladungsmechanismus für weitere Nutzer.

### Sammlungen und Items
- Sammlungen innerhalb eines Haushalts (z. B. Bücher, Filme, Spiele).
- Zuordnung von Items zu Sammlungen mit Unterstützung von Reihen/Serien (z. B. Lexikon-Reihe mit Bandnummer).
- Items mit Titel, Beschreibung und vordefinierten Metadaten für Bücher und Medien.
- Flexible Metadaten (JSONB) für zusätzliche Felder.
- Möglichkeit zur freien Definition individueller Metadaten-Felder (erweiterbar).

### „Wo ist“-Funktion und Identifikation
- Jedes Item kann mit einem NFC-/RFID-Sticker versehen werden.
- Speicherung der Tag-ID (NFC/RFID) am Item.
- Grafische Anzeige des Item-Standorts, wählbar zwischen:
  - Einfacher Raum-/Regal-Liste
  - Interaktivem Grundriss / Raumplan mit Positionen
- Nutzung der Tags für Informationen, Ausleihe und Standortabfrage.

### Medien
- Zuordnung von Medien (Bilder, Dokumente, Cover etc.) zu Items über Supabase Storage.

### AI-gestützte Funktionen
- AI-Funktionen sollen von Anfang an integriert werden.
- Prioritäten:
  - Automatische Metadaten-Vorschläge
  - Zustandsbewertung und Wertschätzung
  - Standortvorschläge bzw. Einordnung in die bestehende Sortierlogik
- Nutzung des bestehenden AI-Jobs-Mechanismus.

### Weitere Funktionen
- Grundlegende Suche und Filterung.
- Ausleihe-Funktion: Nicht erforderlich in der ersten Grundversion, aber die Architektur muss eine spätere Implementierung eines Ausleihsystems (ähnlich öffentlichen Büchereien) ermöglichen und erweiterbar sein.

## 3. Medientypen und Metadaten

### Fokus
- Primär: Bücher und Medien (Filme, Musik, Spiele etc.).

### Vordefinierte Metadaten (Bücher / Medien)
- ISBN / EAN
- Autor / Künstler / Regisseur
- Erscheinungsjahr
- Genre
- Verlag / Label
- Format / Medium
- Zustand
- Sprache

Zusätzliche und individuelle Felder bleiben im flexiblen `metadata`-JSONB-Feld bzw. über frei definierbare Metadaten-Felder.

## 4. Technische Anforderungen

- **Frontend**: Flutter (Android, iOS, Windows, optional Web/macOS).
- **Backend**: Supabase (Postgres, Auth, Storage, Edge Functions, RLS).
- **Self-Hosting**: Architektur so gestalten, dass Self-Hosting (Supabase self-hosted) möglich ist.
- **Sicherheit**: Vollständige RLS-Absicherung; Service-Role-Key nur serverseitig.
- **Offline**: Ideal, aber nicht zwingend für die erste Version (wird noch konkretisiert).

## 5. Nächste Schritte (ursprünglich)

1. Schema-Erweiterung für vordefinierte Metadaten, Standort (inkl. Unterstützung für Liste und Grundriss), NFC/RFID-Tag-ID und erweiterbare Metadaten.
2. Flutter-Grundgerüst mit Auth und Haushaltsverwaltung.
3. AI-Jobs anbinden (Metadaten-Vorschläge, Zustandsbewertung, Standortvorschläge).

## Offene Punkte (teilweise durch Abschnitt 6 adressiert)

- Konkrete Umsetzung der interaktiven Grundriss-Darstellung (Datenmodell für Räume/Positionen).
- Umfang und Datenmodell für spätere Ausleihe-Funktion.
- Offline-Anforderungen.
- Konkrete Priorisierung und Implementierungsreihenfolge der AI-Funktionen.

## 6. Schließung der Wettbewerbslücken (Stand 2026-10-23)

Basierend auf der Analyse vergleichbarer Apps (Libib, CLZ, LibraryThing, Velato/ShelvesAI/Better Bookshelf, Sortly, HomeBox, Intellist) werden folgende Lücken prioritär geschlossen:

### 6.1 Robuster Metadaten-Lookup
- ISBN/EAN-Lookup über Open Library API und/oder Google Books (Edge Function).
- Fallback: AI-Vision auf Cover-/Spine-Foto (AI-Job Typ `metadata_from_image`).
- Ergebnis wird in vordefinierte Felder + `metadata` JSONB geschrieben; Nutzer bestätigt.

### 6.2 Shelf-/Spine-Scanning (Onboarding-Hebel)
- AI-Job Typ `shelf_scan`: Eingabe ist ein oder mehrere `media_assets` eines Regalfotos.
- Ausgabe: Liste erkannter Titel mit Confidence, vorgeschlagene Positionen (relativ zum Foto) und automatische Metadaten-Anreicherung.
- UX: Foto aufnehmen → Job starten → Ergebnisse als Batch zur Bestätigung anzeigen.

### 6.3 Lending-Architektur (vorbereitet, UI später)
- Tabellen `patrons` und `loans` (siehe Migration).
- Status: `available`, `checked_out`, `reserved`, `overdue`.
