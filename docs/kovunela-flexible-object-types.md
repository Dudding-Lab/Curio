# Kovunela – Flexible Objekttypen und Attribute (06.11.2026)

## Live im Supabase-Projekt Curio
Projekt-Ref: `tgawxheqrcqhcvxaexvd`; weiterhin kein Produktivbetrieb.

Erfolgreich eingespielte Migrationen:
- `kovunela_categories_templates_attributes_foundation`
- `kovunela_template_workspace_scope_guards`
- `kovunela_personal_taxonomy_typed_items_api`
- `kovunela_fix_schema_validation_postgres17`

Die bestehenden Kategorien, Vorlagen und Objekte des neuen Systems liegen weiterhin **ausschließlich** im privaten Schema `kovunela`. Alte `public`-Tabellen sind unangetastet.

## Unterscheidung der Konzepte
- **Gegenstand** (`items`): eigenständiger Datensatz, **ohne Pflicht zur Sammlungszuordnung**.
- **Sammlung** (`collections` + `collection_items`): optionale Mehrfachzuordnung bestehender Gegenstände.
- **Kategorie** (`categories`): frei benennbare, pro Arbeitsbereich eindeutige Klassifizierung (etwa Technik, Bücher, Pflanzen).
- **Objekttyp** (`object_templates`): eine vom Nutzer erstellte Erfassungsvorlage (etwa Kamera oder Buch).
- **Vorlagenversion** (`template_versions`): unveränderliche Felddefinition aus heutiger API-Perspektive; keine Client-Schreibrechte.
- **Eigenschaften** (`items.attributes`): frei erweiterbare JSON-Daten, deren Feldnamen und Werttypen bei der Anlage mit der gewählten Vorlagenversion abgeglichen werden.

## Datenmodell / Schutzmechanismen
- Zusätzliche Tabellen `kovunela.categories`, `kovunela.object_templates` und `kovunela.template_versions`.
- `items.category_id`, `items.template_version_id`, `items.attributes` (standardmäßig leeres JSON-Objekt).
- Kategorie und Vorlagenversion sind über **zusammengesetzte Fremdschlüssel** an denselben Arbeitsbereich wie das Objekt gebunden.
- Feldschema: JSON-Objekt, z. B. `{"manufacturer":"text","year":"number","working":"boolean","purchased":"date"}`.
- Unterstützte Feldarten: `text`, `number`, `boolean`, `date`; maximal 30 Felder pro Vorlage; Maximalgröße 32 KiB für Schema und Attribute.
- Server überprüft beim typisierten Anlegen die Kategorie, Vorlagenversion, die zulässigen Attributnamen und passende JSON-Werttypen.
- Datum besitzt derzeit **nur eine Formprüfung YYYY-MM-DD**, noch keine vollständige Kalenderprüfung.
- Aktuell wird die erste Vorlagenversion erzeugt; UI und API zum Bearbeiten/Versionieren kommen später.

## Aktive API
Alle `public.kv_*`-Funktionen sind `SECURITY INVOKER`; interne Schreibfunktionen liegen im nicht exponierten Schema und leiten die Identität aus `auth.uid()` ab:
- `kv_create_personal_category(p_code,p_label)`
- `kv_list_personal_categories()`
- `kv_create_personal_object_type(p_title,p_fields)`
- `kv_list_personal_object_types()`
- `kv_create_typed_personal_item(p_title,p_description,p_category_id,p_template_version_id,p_attributes)`

**Berechtigungen geprüft:** `anon` besitzt keine Ausführungsberechtigung; `authenticated` darf die Funktionen nutzen, nicht aber direkt aus den privaten Tabellen lesen. Alle acht `kovunela`-Tabellen haben RLS aktiviert.

## Flutter
- `PersonalTaxonomyRepository` und die Supabase-Implementierung für Kategorien, Typen und die vorbereitete typisierte Erfassung.
- `/object-types` zeigt die eigenen Vorlagen schreibgeschützt, neue Navigation in der Startseite.
- Feldanzahl und Fehlermeldungen übersetzt in den sieben vorhandenen Sprachvarianten.
- Widget-/Modelltests sowie erweiterter echter Zwei-Benutzer-Integrationstest im Entwicklungsbranch.

## Noch offen
- Zwei regulär angelegte Supabase-Auth-Testkonten und tatsächliche JWT-Integrationstests; im gewöhnlichen CI werden diese Tests übersprungen.
- Kategorien- und Vorlageneditor in Flutter; typisierte Eingabeformulare; verifizierte Datenbank-End-to-End-Tests.
- Saubere Versionierungsregeln, komplexe Feldtypen, Vollvalidierung von Kalenderdaten, globale Typbibliothek und KI-Vorschläge.
- Vor Freigabe: Legacy-Sicherheitswarnungen zu privilegierten Funktionen/Views bearbeiten. Die neuen Tabellen ohne Policies sind absichtlich **deny-by-default**.
