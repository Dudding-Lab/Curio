# Kovunela – Paket 23: Automatische Katalogaufbereitung

## Produktregel
Nach Prüfung des KI-Vorschlags drückt der Nutzer genau einmal **Speichern**. Der vollständige Eintrag wird in seiner privaten Sammlung angelegt. Das Backend stellt automatisch einen internen Katalogbeitrag in die Warteschlange. Es gibt keinen zweiten Bestätigungsbutton. Der gemeinsame Katalog wird ausschließlich online bei Supabase gespeichert.

## In Supabase Development umgesetzt
- `auto_enqueue_catalog_on_save`: Trigger auf `kovunela.items`; legt bei INSERT und relevanten Updates automatisch Queue-Einträge an; Soft-Delete entfernt Queue-Einträge.
- `disable_separate_catalog_confirmation_rpc`: separate Bestätigungs-RPC für normale Nutzer gesperrt.
- `stage_book_candidates_from_saved_items`: geschützte Tabelle `kovunela_catalog.review_candidates` und `kovunela_catalog.process_contribution_batch(50)`.
- `schedule_kovunela_catalog_staging`: Supabase Cron mit aktivem Minutentakt.
- Nur anhand des Standard-Buchtemplates erkannte Bücher mit gültiger ISBN-10 oder ISBN-13 werden in die Prüf-Tabelle aufgenommen.
- Nur `title`, `author`, `publisher`, `language`, `publication_year` und die normalisierte ISBN gehen in diese **nicht öffentliche** Prüf-Stufe; keine Fotos, Beschreibungen, beliebigen Attribute, Standort-, Kauf- oder Besitzdaten.
- Übersprungene, inzwischen gelöschte oder geänderte Objekte werden nicht übernommen. Der Worker prüft `confirmed_item_updated_at` gegen `items.updated_at`.
- Normale `authenticated`-User können `review_candidates` nicht lesen und den Worker nicht ausführen.

## Unbedingt zu unterscheiden
- `pending` = privates Objekt hat automatisch einen Beitrag erzeugt.
- `review` = die ausgewählten Basisdaten liegen im **internen, gesperrten Prüfbereich**.
- `approved` in `kovunela_catalog.entities/facts` = erst nach Quellen- und Qualitätsfreigabe öffentlich suchbar.
- Die rechtssichere automatische Freigabe und Deduplikation nach Kennung ist **noch ausstehend**; es wird kein ungeklärter Google-Books-/KI-Inhalt automatisch publiziert.
- Userbestätigung des privaten Eintrags ersetzt weder die unabhängige Richtigkeitsprüfung noch eine Lizenz-/Nutzungsrechte-Prüfung.
- Nur Daten mit nachvollziehbarer, zur Wiederverwendung berechtigender Provenienz dürfen später öffentliche Katalogfakten werden.

## Offene Arbeiten
1. KI-Erfassung mit vollständigem privaten typed-item-Speicherweg verbinden, einschließlich Template-/Attributvalidierung. ISBN-Bildschirm ist derzeit read-only.
2. Provenienzmodell pro Faktenfeld und rechtliche Beitragsgrundlage; dann Regeln zur automatischen Veröffentlichung/Abgleich mit bestehenden Entitäten.
3. Echte End-to-End-Tests mit zwei Nutzer-JWTs sowie Cron-/DB-Integrationstests mit zurückgerollten Fixtures.
4. Vorgängermigrationen aus Supabase als reproduzierbare, versionierte GitHub-SQL-Dateien nachziehen.
5. Bekannte Security-Advisor-Warnungen separat beseitigen.

## Technische Prüfung
Nach Deployment: `cron.job` zeigt aktiven Job `kovunela-catalog-stage-pending`, Zeitplan `* * * * *`; `authenticated` hat weder `SELECT` auf `review_candidates` noch `EXECUTE` auf `process_contribution_batch`. Ausgangszustand: 0 Queue-Einträge, 0 Prüfkandidaten. Ein Real-User-Katalogisierungs-E2E-Test ist noch offen.
