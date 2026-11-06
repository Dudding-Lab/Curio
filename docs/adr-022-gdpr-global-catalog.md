# ADR 022 – Datenschutzorientierter globaler Metadatenkatalog für Kovunela
Datum: 2026-11-06 · Status: **Architektur beschlossen; Implementierung und Rechtsprüfung vor Aktivierung ausstehend**

## Produktziel

Offline-First-Collection-App mit wiederverwendbarem, lizenzkonformem Metadatenkatalog. Erfasste ISBN/EAN/GTIN oder andere möglichst eindeutige Identifikatoren sollen zuerst lokal und dann in der gemeinsamen **unabhängigen** Katalogebene gesucht werden; externe Anbieter/AI nur bei benötigten Daten. Keine Fremdbenutzer-Inventare durchsuchen und kein Kopieren privater Datensätze.

## Sicherheitsgrenze: zwei Datenräume

1. **Private Nutzungsdaten:** Arbeitsbereiche, Haushalte, Items, Besitz, Zustand, Standort, Kaufpreis, eigene Fotos, Notizen, Bewertung, Sammlungsstatus, Tagging, Leihhistorie. Autorisierung ausschließlich über den tatsächlich berechtigten Nutzer und den jeweiligen Workspace. RLS und die offline verschlüsselte Benutzer-Datenbank schützen diese Ebene.
2. **Gemeinsame kanonische Objektdaten:** Nur gezielt erlaubte allgemeine Fakten ohne Benutzer-/Haushalts-/Besitzbezug. Beispielsweise normierte ISBN-13, Ausgaben-ID, Titel, Autor-/Verlagsbezeichnungen, Publikationsjahr, Sprache, Standard-Merkmale. Keine Rückverweise auf ursprüngliche User-Items. Niemals `user_id`, `workspace_id`, `item_id`, Besitzhäufigkeiten, Erwerbsdaten oder nutzererstellte Freitexte/Fotos in öffentliche Rückgaben übernehmen.

Ein gemeinsamer Katalog kann auch ohne IDs in Einzelfällen sensible Rückschlüsse ermöglichen (seltene Sammlungen, eigene Freitext-Attribute); Eingabefelder müssen serverseitig allowlisted und zweckgebunden sein. Ohne geprüfte Rechtsgrundlage und rechtmäßige Datenherkunft **kein** automatisches Einspeisen bisheriger oder künftiger Nutzerinhalte.

## Datenmodell (Plan, noch keine DB-Migration)

- `catalog_entities`: kanonische Identität, Objekttyp (book, electronics, ...), review_status, created_at/updated_at; keine Nutzerreferenz.
- `catalog_identifiers`: Typ (isbn13/isbn10/ean/gtin/...), normalisierter Wert, `edition_scope` oder `variant_scope`, unique constraint pro Identifikator/Kontext. Eine ISBN identifiziert regelmäßig eine konkrete Buchausgabe, nicht jeden Zustand oder ein individuelles Exemplar.
- `catalog_field_facts`: erlaubter Feldschlüssel, typisierter Wert, locale/source_language, Qualitätsstatus, `source_id`, Nutzungs-/Anzeigerechte und Gültigkeit. Widersprüchliche Quellen nicht überschreiben, sondern prüfen.
- `catalog_sources`: Quelle, Lizenz, Attributionspflicht, Cache-/Löschregel, Nutzungsbeschränkung, letzter Lizenzreview.
- `catalog_moderation`: nachvollziehbare Admin-/Policy-Freigabe, Korrektur und Entzug; keine Veröffentlichung durch allgemeine User-RPCs.
- `personal_items.catalog_entity_id` (oder äquivalente optionale private Referenz) **nur als Link**, persönliche Attribute bleiben pro Konto/Workspace getrennt; beim Kopieren entsteht ein eigener privater Datensatz.
- Lokale `catalog_cache` nach erlaubten Quellenrechten, Ablauffristen und Revocation-Regeln; **nicht** aus Google Books pauschal dauerhaft persistieren.

## Anfragefluss

1. Auf dem Gerät: exakten Identifier validieren, lokalen erlaubten Katalogcache durchsuchen.
2. Online: kanonische serverseitige Katalog-RPC mit engen Rate-Limits, neutraler Trefferantwort, ohne Hinweise auf Nutzerbestände.
3. Bei Treffer: allgemeine, zugelassene Fakten inklusive Quellenstatus anzeigen; Nutzer prüft, korrigiert und übernimmt in seinen eigenen Datensatz. Keine Änderung am fremden Datensatz.
4. Bei Cache-Miss: Quellenadapter nach Priorität und rechtlicher Freigabe (z. B. geeignete offene Metadatenanbieter, vertraglich lizenzierte Quellen). Google Books darf **nicht** ungeprüft als dauerhafter gemeinsamer Kataloglieferant verwendet werden. Danach optional KI, mit aktiver Einwilligung für Bildweitergabe, Server-Kostenlimit und überprüfbarer Ausgabe.
5. Ein Drittanbieter-Ergebnis wird nur gemäß Quellenrecht zwischengespeichert und in den gemeinsamen Katalog übernommen, wenn Provenienz, Rechte und Moderation das ausdrücklich erlauben.
6. Quellen-/Rechteentzug muss abhängige zwischengespeicherte Fakten invalidieren und gegebenenfalls entfernen können.

## DSGVO-Anforderungen für Deutschland/EU

- Art. 5 DSGVO (Rechtmäßigkeit, Zweckbindung, Datenminimierung, Richtigkeit, Speicherbegrenzung, Vertraulichkeit), Art. 6 (geeignete Rechtsgrundlagen je Vorgang), Art. 25 (Datenschutz durch Technikgestaltung und datenschutzfreundliche Voreinstellungen), Art. 28/32 (Auftragsverarbeitung/Sicherheit) und ggf. Art. 35 (DSFA-Risikoprüfung).
- Standardmäßig keine Veröffentlichung, Beitragsfreigabe oder Besitzerstatistik. Pseudonymisierung ist **nicht** gleich Anonymisierung.
- Vor Vermarktung: Datenschutzerklärung, Datenexport, Auskunft, Löschung und Korrektur, Lösch-/Backupfristen, AVVs/Drittlandtransfers, Berechtigungsmatrix, Nachweisbar dokumentierte Risiko- und Lizenzprüfung.
- Eine spätere optionale Community-Beitragsfunktion braucht getrennte transparente Gestaltung und geprüfte Rechtsgrundlage. Kein stilles Zweitverwerten älterer Userdaten.
- Keine Zusicherung einer pauschal „DSGVO-zertifizierten“ App durch Code allein; juristische Freigabe von Datenschutz- und Lizenzfragen vor Vertrieb.

## Lizenzwarnung: Google Books

Google Books Additional API Terms: https://developers.google.com/books/terms – Bedingungen für Gebühren bei Anwendungen und Content Removal/Privacy beachten.

Google APIs Terms: https://developers.google.com/terms – insbesondere Abschnitt 5(e): kein unlizenzierter Aufbau permanenter Kopien/Datenbanken, respektive Cache-Header, Quellkennzeichnung, Nutzungsrechte.

Die bestehende `kovunela-books-lookup`-Edge Function wird nicht verändert. Sie darf nicht automatisch als Grundlage einer dauerhaften gemeinsamen Google-Metadatenkopie verwendet werden. Kommerzieller Einsatz muss separat lizenzrechtlich geprüft werden.

## Umsetzungs-Gates

**Noch kein** öffentlicher Katalog-RPC, kein Cross-User-SELECT, keine Migration oder rückwirkende Übernahme privater Daten freigeschaltet. Vor aktiver Implementierung sind zu definieren: zugelassene Quellen und Lizenzen, Kontributions-/Moderationsprozess, Feld-Whitelist, Lösch-/Berichtigungsregeln und Auth-Tests mit zwei Nutzern. Danach neue getrennte Schemas und private, von Moderatorprozessen befüllte katalogisierte Fakten mit Tests.

## Referenzen
- DSGVO Art. 5/6/25: https://eur-lex.europa.eu/eli/reg/2016/679/oj
- Europäischer Datenschutzausschuss: https://www.edpb.europa.eu/topics/ai-and-technology/anonymisation-pseudonymisation_en
- Google Books API Terms: https://developers.google.com/books/terms
- Google APIs Terms: https://developers.google.com/terms
