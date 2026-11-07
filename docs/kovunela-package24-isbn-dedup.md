# Kovunela – Paket 24: ISBN-Dubletten und Konfliktprüfung

Stand: 2026-11-07. Nur Entwicklungsprojekt `tgawxheqrcqhcvxaexvd` und Feature-Branch, kein Merge.

## Produktablauf
1. Der Nutzer überprüft das KI-Ergebnis und klickt einmal auf **Speichern**.
2. Der vollständige Datensatz verbleibt in seinem privaten Bereich. Ein DB-Trigger legt automatisch eine interne Queue-Aufgabe an.
3. Der bestehende Cronjob extrahiert ausschließlich geeignete Buch-Basisdaten und validiert ihre ISBN. Keine Veröffentlichung.
4. Der neue private ISBN-Gruppierungsjob fasst Varianten der gleichen ISBN-10/13 zusammen, erkennt Metadaten-Konflikte und prüft auf bereits freigegebene Katalogentitäten.
5. Erst ein späterer, gesondert abgesicherter Prozess darf nach geklärter Lizenz-/Nutzerbeitragsgrundlage öffentliche Fakten freigeben.

## Implementiert
Migration `20261107080000_catalog_isbn_dedup_review_groups.sql`:
- `canonical_isbn13(text)`: prüft ISBN-10/13, konvertiert gültige ISBN-10 in die 978-ISBN-13 und gibt sonst `null` zurück;
- `identifier_review_groups`: ausschließlich **interne** und RLS-geschützte Gruppen; hält ISBN-13, Kandidatenanzahl, widersprüchliche Felder, Vorhandensein einer publizierten Entität und Prüfzuteilung;
- `refresh_identifier_review_groups()`: gruppiert nur noch gültige, nicht gelöschte, unveränderte Kandidaten aus der privaten Review-Queue; erkennt Unterschiede bei Titel, Autor, Verlag, Sprache und Erscheinungsjahr; entfernt obsolet gewordene Gruppen;
- Cronjob `kovunela-catalog-identifier-review`: alle zwei Minuten.

Ein Mehrfachtreffer ist keine unabhängige Verifizierung; die Gruppenzahl ist intern und wird nicht über öffentliche RPCs ausgegeben. Abweichende Feldangaben werden nicht automatisch überschrieben.

## Überprüft
- `0306406152` → `9780306406157`;
- `9780306406157` → unverändert;
- ungültige ISBN-10 → `null`;
- `authenticated` kann weder `identifier_review_groups` direkt lesen noch `refresh_identifier_review_groups` ausführen;
- beide Cronjobs sind aktiv; Gruppierungsjob unmittelbar nach Einrichtung noch ohne abgeschlossenen Zeitplan-Lauf;
- aktuell 0 echte Katalog-Gruppen und 0 Kandidaten.

## Bewusste Grenzen
- Noch keine Freigabe von KI-/Google-Books-Metadaten in den öffentlichen Katalog. Nutzerprüfung ist kein rechtlich ausreichender Provenienznachweis.
- Keine automatische Übernahme aller Sammlungstypen; aktuell ist die interne Aufbereitung auf Buchobjekte mit gültiger ISBN beschränkt.
- Flutter-KI-Speichern benötigt noch eine Verbindung zum typisierten privaten Item-RPC.
- Es fehlen echte Zwei-Nutzer-E2E-Tests mit unterschiedlichen ISBN-Formaten und widersprüchlichen Fakten.
- Frühere Supabase-Migrationen fehlen weiterhin in GitHub; die Repository-Migrationsfolge ist noch nicht vollständig reproduzierbar.
- Security-Advisor-Fehler `public.item_loan_status` und weitere Warnungen bestehen unverändert.
