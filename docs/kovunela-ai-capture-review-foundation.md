# Kovunela – Vorlagengebundene KI-Erfassung: validierter Vorschlag und Nutzerprüfung

Stand: 06.11.2026. Branch `feature/kovunela-ui-foundation` (Pull Request #1). Supabase-Produktivdaten und `main` bleiben unverändert.

## Architektur

Die eigentliche KI-Bild- und Textanalyse ist **noch nicht angebunden**. Diese Phase implementiert den wiederverwendbaren, deterministischen Prüfablauf für spätere Vision-, Barcode-, OCR- und Katalogadapter.

1. **Vorschlag** als beschränktes Datenobjekt: `template_code`, `title`, `attributes`, optionale `confidence` und Feldbelege (`evidence`). Eingaben werden als untrusted behandelt.
2. **Vorlagenranking** nach bekannten Feldnamen aus den tatsächlich abrufbaren Kovunela-Standardvorlagen. Der Rang ist ein heuristischer Indikator, **keine Modellgewissheit** und kein Beweis für Identifikation.
3. **Schemavalidierung**: Es werden nur Schlüsselnamen der explizit ausgewählten Vorlage übernommen; Felder mit falschem Typ, unzulässigen Choice-Werten oder leeren Werten werden verworfen. Keine Schema-Mutation und keine ungeprüfte Übernahme.
4. **Pflichtfeldprüfung**: Fehlende Pflichtangaben werden aufgelistet. Eine manuelle Korrektur ist nötig, bevor die lokale Prüfung erfolgreich sein kann.
5. **Review in Flutter**: Die Userin oder der User sieht den vorgeschlagenen Titel und die Attribute und kann sie vor der finalen Prüfung korrigieren. In dieser Phase findet **keine Speicherung** statt.

Die erste sichtbare Ansicht `/capture/suggestion-demo` wird über „KI-Erfassung testen (Demo)“ auf der Startseite geöffnet. Sie verwendet eine ausdrücklich als **simuliert** gekennzeichnete Bucherkennung und eine ungültige, fremde Feldeigenschaft, um das Verwerfen unbekannter Daten vorzuführen.

## Implementierung

- `flutter_app/lib/features/capture/capture_suggestion.dart`: `CaptureSuggestion`, `CaptureSuggestionMatcher`, `CaptureReview`; keine Netzwerkzugriffe.
- `flutter_app/lib/screens/capture/capture_suggestion_demo_screen.dart`: schreibgeschützte Vorgangssteuerung mit editierbarem lokalen Review, kein Aufruf einer Storage-/Save-API.
- `flutter_app/test/capture_suggestion_test.dart`: Untrusted-JSON-Checks, Rangfolge, Feldvalidierung, fehlende Pflichtfelder, Template-Mismatch und Widget-Review.
- Alle sieben unterstützten App-Sprachen erhalten Beschriftungen und eine klare Demo-Kennzeichnung.

## Sicherheit / Abgrenzung

- Keine API-Keys in Flutter, keine direkte KI-Anfrage aus dem Client und keine automatischen Datenbankwrites.
- Die spätere KI-Anfrage muss serverseitig über eine berechtigte Function laufen, mit passenden Nutzereingaben, serverseitiger Vorlagenauflösung, Limits, strukturiertem Output, Quellenbelegen und Kostenkontrolle.
- Externe Metadaten und Bilder dürfen keine Anweisungen zur Systemausführung oder Rechteerweiterung steuern. KI-Ausgaben dürfen weder Arbeitsbereich noch SQL-Tabellen/Funktionen noch Berechtigungen bestimmen.
- Echtes JWT-Isolationstesting mit zwei Accounts bleibt vor der Aktivierung sämtlicher Schreiboperationen erforderlich.
- Der Demoablauf ist **keine echte KI-Bilderkennung**, kein OCR-/Barcode-Scanner und kein fertig integrierter produktiver Erfassungsvorgang.
