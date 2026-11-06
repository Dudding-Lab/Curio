# Kovunela – Google Books: sichere ISBN-Metadatenabfrage

Stand: 6. November 2026 · GitHub-Entwicklungsbranch `feature/kovunela-ui-foundation`.

## Implementiert und bereitgestellt
- Supabase Edge Function `kovunela-books-lookup` im Kovunela-/Curio-Testprojekt `tgawxheqrcqhcvxaexvd`, mit `verify_jwt=true`.
- `POST` mit `{"isbn":"9783522202602"}`; erforderlich ist ein angemeldeter Supabase-Benutzer.
- ISBN-10/13 wird normalisiert, das Prüfzifferverfahren serverseitig validiert.
- Die Function fragt die **offizielle Google Books Volumes API** nach `q=isbn:<ISBN>` (höchstens 5 Treffer, printType books) und übernimmt nur Bände, deren `industryIdentifiers` die angefragte ISBN genau enthalten.
- Als Antwort kommen ausschließlich vereinheitlichte Felder `title, author, isbn, publisher, publication_year, language` sowie `source, source_id, evidence`; externe HTML-Beschreibungen werden absichtlich **nicht** übernommen.
- 401 bei nicht gültigem Auth-Token; kein Schreiben in Tabellen. Upstream-Fehler werden ohne Preisgabe von API-Schlüsseln gemeldet.
- Flutter: `SupabaseBookLookupRepository`, `IsbnLookupScreen` unter `/capture/isbn`, Einstieg über „ISBN-Suche (Google Books)“.
- Suchergebnisse können als lokale Vorschau ausgewählt werden; `CaptureReview` prüft die Angaben anhand der tatsächlich im Backend hinterlegten Standardvorlage `book`. **Kein Speichern**.

## Konfiguration und technische Grenzen
- Die Function liest die durch Supabase bereitgestellten `SUPABASE_URL` und `SUPABASE_ANON_KEY` und prüft das User-JWT nochmals über `/auth/v1/user`.
- Optional kann **serverseitig** `GOOGLE_BOOKS_API_KEY` als Supabase-Function-Secret hinterlegt werden. Kein Google- oder OpenAI-Key im Flutter-Quellcode oder in der öffentlichen App. Öffentliche Google-Books-Banddaten sind grundsätzlich auch ohne API-Key abrufbar; Quoten-/Schlüsselregeln des Projekts gelten weiterhin.
- Eine erfolgreiche Function-Deploymentmeldung ist **noch kein realer Live-Test** mit zwei authentifizierten Konten. Es wurden keine echten Account-Tokens für die Function verwendet.
- Für eine vollständige produktive Nutzung fehlen unter anderem Account-basierte Rate Limits, Missbrauchsschutz, Telemetrie ohne Nutzerdaten, API-Quotenprüfung, Copyright-/Caching-Regeln sowie die Verifikation am echten Gerät.
- Google Books ist eine externe Katalogquelle, **keine KI-Bildanalyse**. Ein Treffer ist nie gleichbedeutend mit dem Nachweis, dass die fotografierte Ausgabe tatsächlich identisch ist.

## Nächster Schritt: OpenAI Vision
1. Erst einen sicheren, serverseitigen Edge-Function-Endpunkt mit restriktivem Auth- und Größenlimit sowie strukturiertem Schema schaffen.
2. Originalfotos zunächst nicht dauerhaft speichern und erst nach aktiver Nutzeraktion/Einwilligung übertragen.
3. OpenAI-API-Key nur im Supabase Secret Store halten; Aufwand, Modell, Kosten und Fehlerbehandlung begrenzen.
4. Ergebnisse mit dem vorhandenen `CaptureSuggestion`-Validator abgleichen und externen Kontext als untrusted behandeln.
5. Ergebnisse immer vor einer Speicherung zeigen. Die aktuelle personenbezogene Gegenstandsspeicherung bleibt hinter `KOVUNELA_ENABLE_PERSONAL_ITEM_SAVE` und der Zwei-Benutzer-Freigabesperre.

Die CI-Tests prüfen Flutter-Modelle/UI mit injizierten Fake-Repositories, **nicht** den echten Google-Books-Dienst.
