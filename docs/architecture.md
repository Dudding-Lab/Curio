# Curio – Architektur

## Überblick

Curio ist eine Multi-User-Sammlung-App. Nutzer arbeiten in **Haushalten** zusammen. Jeder Haushalt besitzt **Sammlungen**, die wiederum **Items** enthalten. Items können **Medien** haben. **AI Jobs** verarbeiten Daten asynchron.

## Datenmodell (Kern)

### households
Gemeinsamer Arbeitsraum.
- `id` (uuid)
- `name` (text)
- `created_by` (uuid → auth.users)
- `created_at`, `updated_at`

### household_members
Mitgliedschaft mit Rolle.
- `household_id` → households
- `user_id` → auth.users
- `role` (`owner` | `admin` | `member` | `viewer`)
- `joined_at`

### household_invites
Einladungen per Token.
- `household_id`
- `email` (optional)
- `token_hash` (gehasht gespeichert)
- `expires_at`
- `created_by`
- `accepted_at` (nullable)

### collections
Sammlung innerhalb eines Haushalts.
- `id`
- `household_id`
- `name`
- `description`
- `created_by`
- `created_at`, `updated_at`

### locations
Standorte für die „Wo ist“-Funktion (unterstützt einfache Listen und interaktive Grundrisse).
- `id` (uuid)
- `household_id` → households
- `name` (text)
- `type` (`room` | `shelf` | `position` | `other`)
- `parent_id` → locations (Hierarchie)
- `floor_plan_data` (jsonb – z. B. Koordinaten, Bildpfad)
- `sort_order`
- `created_at`, `updated_at`

### items (erweitert)
Einzelnes Objekt mit vordefinierten Metadaten.
- `id`
- `collection_id` → collections
- `title`, `description`
- Vordefinierte Felder: `isbn`, `authors`, `publication_year`, `genre`, `publisher`, `format`, `condition`, `language`
- Reihen: `series_name`, `volume_number`
- Identifikation/Standort: `nfc_tag_id` (unique), `location_id` → locations
- `metadata` (jsonb – flexible/individuelle Felder)
- `created_by`, `created_at`, `updated_at`

### media_assets
Dateien/Bilder zu einem Item.
- `id`
- `item_id`
- `storage_path`
- `mime_type`
- `size_bytes`
- `created_at`

### ai_jobs
Asynchrone KI-Aufgaben.
- `id`
- `household_id` / `item_id` (optional)
- `type` (text)
- `status` (`pending` | `processing` | `completed` | `failed`)
- `input` / `output` (jsonb)
- `created_by`
- `created_at`, `completed_at`

## Sicherheit (RLS-Prinzipien)

- Nur authentifizierte Nutzer können Daten sehen/ändern.
- Zugriff auf Haushalte nur über `household_members`.
- Owner/Admin dürfen Haushalte verwalten und löschen (mit Schutzregeln).
- Items und Medien nur für Mitglieder des zugehörigen Haushalts.
- Service-Role nur in Edge Functions, niemals im Client.

## Empfehlungen

- **Dokumentation** im Repo halten (`/docs`), damit Coding-Agents zuverlässig arbeiten können.
- **Staging-Umgebung** mit identischem Schema.
- **Schema-Readiness-Check** vor QA (SQL-Skript, das Kern-Tabellen prüft).
- **Soft-Delete** oder Archivierung für kritische Entitäten erwägen.

## AI-Job-Typen (für Wettbewerbsaufholung)

Definierte Typen in `ai_jobs.type`:

- `metadata_from_isbn` – Lookup über externe API (Open Library / Google Books).
- `metadata_from_image` – Vision auf Cover oder Spine.
- `shelf_scan` – Mehrere Items aus einem Regalfoto erkennen + Positionen + Metadaten.
- `condition_value_estimate` – Zustand und geschätzter Wert aus Foto + Beschreibung.
- `location_suggestion` – Vorschlag für Location basierend auf bestehenden Items oder Foto.

## Lending-Architektur (vorbereitet)

Siehe Migration `20261023120000_lending.sql`.

- `patrons`: Personen innerhalb eines Haushalts, die ausleihen können (Name, Kontakt, Barcode optional).
- `loans`: Ausleihe eines Items an einen Patron (Status, due_date, checked_out_at, checked_in_at).
- Item-Status kann über View oder Trigger aus aktiven Loans abgeleitet werden.

## Offline und Labels

- Offline: Riverpod + persistenter Cache (z. B. Hive oder Drift); Sync über Supabase Realtime oder manuelles Pull.
- Labels: NFC-Schreiben clientseitig; QR-Generierung über `qr_flutter` oder ähnlich, Speicherung optional als media_asset.

## Grundriss-Datenmodell

`locations.floor_plan_data` (jsonb) Beispiel:

```json
{
  "image_path": "storage/floorplans/room1.jpg",
  "positions": [
    { "item_id": "uuid", "x": 0.25, "y": 0.4 },
    { "item_id": "uuid", "x": 0.55, "y": 0.7 }
  ]
}
```

Koordinaten relativ (0–1) zum Bild. UI rendert Pins als Overlay.
