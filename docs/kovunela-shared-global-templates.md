# Kovunela – Globale Vorlagen, Ableitungen und bereichsübergreifende Freigabe

Stand: 06.11.2026. Implementiert **nur** im nichtproduktiven Supabase-Projekt Curio (`tgawxheqrcqhcvxaexvd`) und im GitHub-Branch `feature/kovunela-ui-foundation`. Die Altdaten im `public`-Schema bleiben unangetastet.

## Architekturentscheidung
1. **Standardvorlage**: Kuratierte, schreibgeschützte, globale Definition. Benutzer können sie als Ausgangspunkt verwenden, nicht direkt verändern.
2. **Bereichsvorlage**: Im Eigentum eines privaten oder gemeinsamen Arbeitsbereichs. Enthält eine **versionierte, eigenständige Kopie** des Feldschemas und optional einen Herkunftsverweis.
3. **Ableitung**: Die persönliche Vorlage aus einem Standard bewahrt `source_standard_id` und `source_version` und enthält das aufgelöste Feldschema (`Standardfelder + neue Felder`). Keine automatische Aktualisierung/Änderung bestehender Datensätze.
4. **Freigabe**: Der private Eigentümer gibt seine Vorlage gezielt für einen Haushalt frei. Ausschließlich Mitglieder des Zielhaushalts dürfen die freigegebene Felddefinition sehen. Aktuell autorisiert die Freigabe nur der Haushaltseigentümer oder Administrator.
5. **Übernahme/Kopie**: Berechtigte Haushaltsmitglieder (`owner`, `admin`, `editor`) erstellen eine **unabhängige Kopie** im Haushalt, verknüpft über `source_template_id` und `source_version`. Bestehende Gegenstände des ursprünglichen Bereichs werden nicht freigegeben.
6. **Bereichsübergreifendes Kopieren**: Die Autorin oder der Autor einer Vorlage kann sie zwischen den eigenen, administrierbaren Arbeitsbereichen kopieren. Die Kopie bekommt eine neue Identität und eine unveränderliche Feldschema-Snapshot-Version.
7. **Kontrolliertes Verschieben**: Die Vorlage wird nur dann in einen anderen eigenen, administrierbaren Bereich übertragen, wenn **keine Gegenstände, Freigaben oder abgeleitete Vorlagen** auf das Original verweisen. Das Ziel bekommt eine neue Vorlagen-ID und die zuletzt veröffentlichte Feldschema-Version; das Original wird innerhalb derselben Transaktion entfernt. Bestehende Versionshistorie wird dabei nicht als vollständige Historie übertragen. Jede Abhängigkeit blockiert den Vorgang statt ihn stillschweigend zu verändern.

Die bestehende `items`-Tabelle verwendet weiterhin zusammengesetzte Fremdschlüssel (`workspace_id`, `template_version_id`), sodass ein Gegenstand keine Vorlage aus einem fremden Bereich direkt referenzieren kann. Das schützt die Trennung privater Gegenstandsdaten und schließt eine versehentliche Datenfreigabe durch Vorlagenteilung aus.

## Neue Datenbankstruktur
- `kovunela.standard_templates`: globale Standardvorlagen mit Code, Titel, Kategorie, Schema und aktuellem Versionszeiger. RLS aktiviert, keine direkten Clientrechte.
- `kovunela.standard_template_versions`: gespeicherte Versions-Snapshots; Herkunftsverweise auf Standards erhalten eine zusammengesetzte Versions-Fremdschlüsselprüfung.
- `kovunela.object_templates.source_standard_id`, `source_template_id`, `source_version`: Herkunft und Ausgangsversion; nur eine Herkunft pro Vorlage.
- `kovunela.object_templates.presentation`: pro Feld optionale Anzeigeattribute `label`, `hidden`, `order`, ohne Schema-/Datentypänderung.
- `kovunela.template_shares`: explizite Verknüpfung aus Quellvorlage, Zielarbeitsbereich, Urheber und Freigabezeitpunkt. RLS aktiviert, keine direkten Clientrechte.

Aktuell angelegte **sechs** Standardvorlagen: `book`, `movie`, `music`, `game`, `camera`, `plant`. In dieser ersten Version sind die Standardtitel deutsch; lokalisierte Katalogfelder folgen. Jeder Eintrag verwendet den bereits existierenden Feldtypenvertrag (`text`, `number`, `boolean`, `date`).

### Neue RPC-API
- `kv_list_standard_templates()` – kuratierten Katalog abrufen.
- `kv_derive_standard_template(p_standard_id,p_title,p_added_fields)` – persönliche Ableitung mit eigenen **zusätzlichen** Feldern erstellen. Das Umdefinieren von Standardfeldtypen ist bewusst ausgeschlossen; Änderungen an Standardfeldern erfordern in Zukunft eine explizite, versionierte Override-Policy.
- `kv_share_personal_template(p_template_id,p_target_workspace_id)` – eine eigene persönliche Vorlage für einen eigenen Haushalt freigeben.
- `kv_list_shared_templates(p_workspace_id)` – freigegebene Vorlagen ausschließlich an Mitglieder des Haushalts ausgeben.
- `kv_copy_shared_template(p_template_id,p_target_workspace_id)` – versionierte Kopie in den Zielhaushalt anlegen, nur mit Editierrechten.
- `kv_copy_owned_template(p_template_id,p_target_workspace_id)` – Kopie einer selbst erstellten Vorlage in einen anderen eigenen oder administrierten Arbeitsbereich.
- `kv_move_owned_template(p_template_id,p_target_workspace_id)` – geprüfte, transaktionale Übertragung ohne abhängige Gegenstände, Freigaben oder abgeleitete Vorlagen; kein Übertragen von Gegenständen.
- `kv_configure_personal_template(p_template_id,p_presentation)` – Feldbezeichnungen, Sichtbarkeit und Reihenfolge im persönlichen Bereich anpassen (ohne Feldtypänderung).
- `kv_get_personal_template_presentation(p_template_id)` – eigene Feldeinstellungen abrufen.
- `kv_revoke_personal_template_share(p_template_id,p_target_workspace_id)` – Freigabe widerrufen; bereits erstellte Zielkopien bleiben bestehen.

Nur authentifizierte Benutzer erhalten `EXECUTE` für öffentliche **SECURITY INVOKER**-Wrapper; interne Funktionen liegen im privaten Schema mit validierter `auth.uid()`- und Mitgliedschaftsprüfung. Auch die Tabellen selbst sind nicht direkt erreichbar.

## Implementiert in Flutter
- `lib/features/taxonomy/template_catalog_repository.dart`: typisierte API für Katalog, Ableitung, Freigabe, Haushaltssuche, Kopie und kontrolliertes Verschieben.
- `lib/screens/taxonomy/standard_templates_screen.dart`: Katalog unter `/templates/standard`, **schreibgeschützt**, von der Startseite erreichbar.
- Lokalisierte Katalogoberfläche in den sieben ARB-Sprachen.
- `test/standard_templates_test.dart`: Modell- und Widget-Tests.
- `test/two_user_supabase_integration_test.dart`: ergänzt Ableitung und verweigerte Fremdfreigabe; dieser **echte** JWT-Test wird im normalen CI weiterhin übersprungen, solange zwei separate Auth-Konten nicht konfiguriert sind.

## Offene Sicherheits-/Produktaufgaben
1. Echte Zwei-Nutzer- und Zwei-Haushalts-Integrationstests: Owner/Admin, Editor, Viewer, Fremdmitgliedschaft, Übernahme, Entzug von Freigaben.
2. Freigabe widerrufen: RPC existiert; die UI und echte End-to-End-Tests fehlen. Zielbereich-Kopien bleiben unabhängig und werden nicht nachträglich gelöscht.
3. Verschieben: Datenreferenzprüfungen sind serverseitig implementiert; vollständige Haushaltstests, Versionshistorien-UX, Nutzerbestätigung und die Freischaltung der Aktion fehlen noch.
4. Editieren und neue Versionen: Präsentationsanpassungen sind bereits als RPC vorhanden; strukturelle Feldtypänderungen, neue Versionen und Bestandsmigrationen gesondert implementieren.
5. Feldlabels, Hilfetexte, Pflichtfelder, Sichtbarkeit und lokalisierte Standardtitel ergänzen; KI-Erfassung kann danach die Schema-IDs nutzen.
6. App-Schreibaktionen erst nach realem JWT-Sicherheitstest freischalten. Die offiziellen Vorlagen haben historische Snapshots, aber noch **keinen Admin-Publikationsworkflow** für eine neue Standardversion.
7. Bereits bekannte Legacy-Advisory-Warnungen beheben, bevor irgendein Produktivbetrieb beginnt.

**Nicht verwechseln:** Vorlagenfreigaben übertragen niemals die zugehörigen Gegenstände, Fotos, Standorte oder personenbezogenen Informationen.
