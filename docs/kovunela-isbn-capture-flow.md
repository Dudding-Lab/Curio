# Kovunela: ISBN suchen → prüfen → privat speichern

Stand: 7. November 2026.

Die bestehende Flutter-ISBN-Suche `/capture/isbn` verwendet weiterhin den **internen Kovunela-Katalog zuerst** und bei Nichttreffer das serverseitig geschützte Google-Books-Lookup. Die Suche selbst speichert keine externen Daten.

## Erfassungsablauf

1. Benutzer gibt eine ISBN ein und wählt einen gefundenen Buchkandidaten.
2. Die vorhandene Vorschau zeigt Quelle und die aus dem Buchstandard übernommenen geprüften Felder.
3. Neue Aktion **Buchdaten übernehmen** öffnet `/capture/standard` mit einem ausschließlich lokalen, unvertrauenswürdigen Buchvorschlag als GoRouter-extra.
4. Die dort bereits implementierte Vorlage `book` wird geladen und der Titel sowie **nur passend typisierte Attribute**, die tatsächlich in der Vorlage vorkommen, werden vorausgefüllt. Unbekannte Metadaten und ungültige Typen werden nicht übernommen. Der Benutzer kann alle Werte korrigieren.
5. **Angaben prüfen → Gegenstand speichern** löst exakt einen serverbestätigten `kv_create_standard_personal_item`-Aufruf aus. Erst danach wird die private Objektliste geöffnet.
6. Die bereits vorhandene Katalog-Automatik übernimmt geeignete Bücher mit gültiger ISBN als **interne Prüfungskandidaten**, niemals ungeprüft als öffentliche Katalogentität.

Datenquellen (Google Books) dienen als unsichere Vorschläge und werden nicht im Hintergrund in den öffentlichen Katalog übernommen. Die ISBN-Prüfziffer wird auch beim Bearbeiten erneut validiert.

## Absicherung

- Flutter Widget-Test deckt den vollständigen Navigations- und Speichervorgang mit Fake-Repository ab und prüft, dass kein verfrühter Schreibaufruf stattfindet.
- Bestehende Tests validieren ISBN-Fehler, den Speicher-Button und die serverbestätigte private Schreiboperation.
- Realer Zwei-Benutzer-Integrationstest für `kv_create_standard_personal_item` und private Datentrennung wurde bereits zuvor erfolgreich absolviert.
- Flutter-Qualitätslauf: https://github.com/Dudding-Lab/Curio/actions/runs/42394836601

Grenze: Die Route verwendet lokale `extra`-Daten; ein Browser-Neuladen während der Übernahme stellt den ungespeicherten Vorschlag möglicherweise nicht wieder her. Eine dauerhafte Entwurfsverwaltung ist ein späteres Feature.
