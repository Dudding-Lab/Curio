# Kovunela – Geschützte OpenAI-Vision-Anbindung (Entwicklungspaket 16)

Stand: 06.11.2026. Branch `feature/kovunela-ui-foundation`, Supabase-Testprojekt `tgawxheqrcqhcvxaexvd`. Kein Merge nach `main`, keine produktive Aktivierung.

## Implementiert

- Edge Function `kovunela-vision-analyze` (Deployment v2), `verify_jwt=true`.
- Noch **deaktiviert durch zwei Bedingungen**: `KOVUNELA_VISION_ENABLED=true` und ein serverseitiges `OPENAI_API_KEY`-Secret sind beide erforderlich; andernfalls antwortet die Funktion mit HTTP 503 ohne OpenAI-Anfrage.
- Autorisierung: JWT zusätzlich über `/auth/v1/user` validieren, bevor die kostenträchtige Funktion möglich wird.
- Server akzeptiert ausschließlich selbst gelieferte JPEG- oder PNG-Daten-URLs; externe Bild-URLs und damit SSRF sind ausgeschlossen. JPEG/PNG-Signatur, Base64-Form, Größenlimit und **tatsächliche Streaming-Anfragegröße** werden überprüft. Client prüft dieselben Bedingungen bis 700.000 Bildbytes.
- PostgreSQL-Tabelle `kovunela.vision_daily_usage`: RLS eingeschaltet, keine direkten Client-Rechte; atomare Reservierungs-RPC `kv_reserve_vision_quota()` maximal fünf Anfragen pro Auth-Benutzer und UTC-Tag. Zugriffe außerhalb dieses RPC sind blockiert. Der Zähler erfasst auch misslungene Provider-Aufrufe (bewusstes Kosten-Sicherheitsprinzip).
- Der OpenAI-Request verwendet `/v1/responses`, `store:false`, ein Bild in `detail:low`, `max_output_tokens:450` und strukturierte JSON-Ausgabe.
- Modellvorgabe `gpt-4o-mini` (serverseitig über `KOVUNELA_VISION_MODEL` konfigurierbar). Modellfreigabe, Verfügbarkeit und API-Quoten müssen am tatsächlichen OpenAI-Projekt verifiziert werden.
- Output wird nach der Modellantwort **nochmals serverseitig gegen die im Request angebotenen Vorlagen und Feldtypen** gefiltert; es werden keine Datenbank-Änderungen durchgeführt.
- `VisionSuggestionRepository` für Flutter bildet die serverseitige API auf `CaptureSuggestion` ab. Bild-Signaturen und Größenlimit lassen sich ohne Netzwerk in Tests prüfen.

## Einbindung in den App-Flow

Die API ist bewusst **noch nicht mit der Kamera-/Fotobibliothek-Umschaltfläche verbunden**. Der bereits implementierte `CaptureReview` übernimmt künftig die Benutzerbestätigung der KI-Ausgabe. Die vorläufige, sichtbare KI-Demo benutzt weiterhin simulierte Informationen; sie ist klar als solche gekennzeichnet. Ein Nutzer-Upload soll erst über eine ausdrückliche, später zu implementierende Bildauswahl erfolgen.

## Aktivierungssperren

1. OpenAI-Key ausschließlich über Supabase Project Dashboard > Edge Functions > Secrets eintragen. **Niemals** im Chat, in GitHub oder per Flutter-Dart-Define veröffentlichen.
2. Vor Aktivierung den echten Auth-/RLS-Test mit zwei normalen Supabase-Konten durchführen.
3. Das Modell, die image input Kosten, API-Quoten, Provider-Fehler und die zulässigen Datenverarbeitungsregionen bestätigen.
4. Explizite Fotoauswahl und Aufklärung über die Bildweitergabe an den Provider entwickeln. Noch keine Nutzerfotos dauerhaft speichern.
5. Mit realen Testkonten HTTP 401 für anonyme Aufrufe, 413/400 für invalides Bild, 429 beim Quotenlimit sowie den 503-Kill-Switch live testen.
6. Erst mit ausdrücklicher Entwicklerfreigabe `KOVUNELA_VISION_ENABLED=true` im Secret Store aktivieren. Eine Edge Function mit Status `ACTIVE` ist **nicht** gleichzusetzen mit eingeschalteter Bezahl-API.
7. In Zukunft: serverseitige Vorlagenauswahl aus vertrauenswürdigen RPCs statt nur vom Client angebotener Feld-Schemata, stärkere Anti-Spam-Limits, Quoten-Telemetrie und Fehlerentlastung.

## Aktuelle Grenzen

Kein produktiver Vision-Request wurde durchgeführt. Die Edge Function wurde bereitgestellt und die existierende Auth-/Quotenberechtigung technisch geprüft, aber noch nicht mit einem echten User-JWT, einer OpenAI-Antwort oder einem Bild auf einem Endgerät end-to-end verifiziert. Flutter bietet noch **keine tatsächliche Fotoauswahl** für diesen Endpoint. `KOVUNELA_ENABLE_PERSONAL_ITEM_SAVE` bleibt weiterhin standardmäßig ausgeschaltet.

Die Datenschutz-/Kostenentscheidung sollte vor dem Einschalten der Bildweitergabe und der API explizit bestätigt werden.
