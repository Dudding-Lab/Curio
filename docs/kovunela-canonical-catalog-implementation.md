# Kovunela Paket 22 – Eigenständiger, DSGVO-orientierter Objektkatalog

Stand: 06.11.2026 · nur Supabase-Entwicklungsprojekt `tgawxheqrcqhcvxaexvd` und GitHub-Branch `feature/kovunela-ui-foundation`. Kein Merge, keine Produktionsfreigabe.

## Umgesetzt: eigene, private Katalogstruktur

Das Schema `kovunela_catalog` ist **getrennt** von `kovunela` (private Sammlungen). Tabellen:

- `entities`: kanonische Objekte und Status (`draft`, `approved`, `withdrawn`), ohne User-/Workspace-/Item-IDs.
- `identifiers`: normalisierte und eindeutige `isbn10`, `isbn13`, `ean13`, `gtin14` mit Entity-Verweis.
- `sources`: Quellkennung, Lizenzbezeichnung, Nutzungserlaubnis, Attributionspflicht, Zeitpunkt der rechtlichen Prüfung. **Standard: `reuse_allowed=false`, `attribution_required=true`.**
- `facts`: einzelne typisierte, quellgebundene und freigegebene Objektfakten, mit kleinem Whitelist-Feldsatz und Status. Keine privaten Erwerbs-/Besitzdaten.

Alle Tabellen haben RLS **ohne** Zugriffsrichtlinien und keinerlei Daten-API-Tabellengrants an `anon` oder `authenticated`. Bearbeitung durch öffentliche App-Konten ist ausgeschlossen. Daten dürfen nur durch einen kontrollierten Admin-/Curation-Prozess befüllt werden, der noch nicht implementiert ist.

Die einzige für `authenticated` freigegebene RPC heißt `public.kv_catalog_lookup(p_identifier_type text,p_identifier text)`. `anon` besitzt **keine** Execute-Berechtigung. Die Funktion validiert die echte Benutzeridentität über `auth.uid()`, normalisiert den Code und prüft Prüfziffern. Sie liefert nur freigegebene Entitäten mit **approved** Fakten aus explizit rechtlich geprüften, zur Wiederverwendung zugelassenen Quellen. Quellen, die Attribution erfordern, sind **vorerst von Ergebnissen ausgeschlossen**, bis eine konforme Attributionsdarstellung existiert; ebenso langformatige `description`-Felder. Die Antwort enthält keine User-, Haushalts-, Besitz-, Katalogherkunfts-User-ID oder Notizen.

Die Migrationen wurden im **Supabase-Entwicklungsprojekt** angewendet:
- `kovunela_private_global_curated_catalog_v1`
- `kovunela_catalog_default_block_unattributed_reuse`

Die Schemaänderungen wurden noch nicht aus Supabase als versionierte SQL-Migrationsdateien in den GitHub-Branch zurückgespiegelt; vor CI-gestützter Neuerstellung einer Datenbank muss dies erfolgen.

**Wichtig: Der gemeinsame Katalog enthält derzeit 0 Datensätze, 0 Quellen und 0 Fakten.** Es wurden **keine privaten Datensätze** importiert und keinerlei Google-Books-Responses permanent gespeichert.

## Umsetzung in Flutter

- `CanonicalCatalogRepository` und `SupabaseCanonicalCatalogRepository` rufen die erlaubte öffentliche Lesefunktion per Supabase Auth auf.
- `CatalogIdentifier` validiert ISBN-10/-13, EAN-13 und GTIN-14 lokal, einschließlich Prüfziffer; fehlerhafte Eingaben erzeugen **keine** Netzwerkabfrage.
- `CatalogFirstBookLookupRepository` setzt die Recherche-Reihenfolge für die bestehende ISBN-Bucherfassung um: zugelassener Kovunela-Katalog → auf echten Katalog-Miss Google Books. Bei DB-/Auth-/Netzwerkfehlern gibt es **keinen automatischen Drittanbieter-Fallback**.
- Ein Katalogtreffer erzeugt nur eine **review-only** Vorlage, niemals einen Gegenstand im Konto eines anderen Benutzers. Die Quellenanzeige unterscheidet Kovunela von Google Books.
- Tests decken Treffer ohne externen API-Aufruf, Miss mit API-Abfrage, Fehler ohne unautorisierte Drittanbieter-Abfrage, Prüfziffern, Besitzerfelder-Whitelist und korrekten Vorlagenbezug ab.

**Noch nicht umgesetzt:** persistenter verschlüsselter lokaler Metadaten-Cache; damit ist der erste Schritt der geplanten Reihenfolge derzeit die Online-RPC, nicht der Offline-Cache. Dies folgt in der nächsten Paketphase unter Berücksichtigung der Quellenlizenzen und Fristen.

## Sicherheit, Recht & Vermarktung

- Ein privat inventarisiertes Buch darf **nicht** automatisch in einen globalen Eintrag überführt werden. Die Idee der Wiederverwendung betrifft ausschließlich **rechtmäßig nutzbare, kuratierte allgemeine Fakten**, nicht Daten fremder Nutzer. Pseudonymisierung allein genügt nicht für Anonymität.
- Google-Books-Metadaten sind weiterhin nur eine bisherige externe Suchquelle. **Keine** automatische permanente Übernahme in den Katalog. Vor kommerziellem Betrieb muss das Google-Books-Lizenz-/Nutzungsverhältnis eindeutig geklärt oder eine ausreichend lizenzierte Alternative verwendet werden.
- Der Quellen-Adminprozess wird erst eingeführt, wenn Lizenzbeleg, Urheber-/Nutzungsrechte, Lösch-/Berichtigungsabläufe, Attribution, Datenqualität und Moderation dokumentiert sind.
- DSGVO-Check: Privacy by Default, Zweckbindung, Datenminimierung, Art. 5/6/25/28/32, Risikoprüfung nach Art. 35 sofern erforderlich. Rechtliche Freigabe vor öffentlichem Angebot.
- Der Supabase-Sicherheitsadvisor meldet weiterhin INFO-Hinweise über beabsichtigt RLS-geschützte Tabellen ohne Policies (inkl. der neuen privaten Katalogtabellen) und **einen bereits vorbestehenden Fehler an `public.item_loan_status`** (Security-Definer-View), der gesondert geprüft und vor Veröffentlichung behoben werden muss.

## Quellen
- Supabase Functions: https://supabase.com/docs/guides/database/functions
- DSGVO: https://eur-lex.europa.eu/eli/reg/2016/679/oj
- Google API Terms: https://developers.google.com/terms
- Google Books Additional Terms: https://developers.google.com/books/terms
- Vorheriger Architekturentscheid: `docs/adr-022-gdpr-global-catalog.md`
