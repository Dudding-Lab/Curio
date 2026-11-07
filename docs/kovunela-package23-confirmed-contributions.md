# Paket 23 – Nutzerbestätigte Katalogbeiträge (Backend-Gate)

## Produktentscheidung
Der **gemeinsame Kovunela-Katalog bleibt ausschließlich online** in Supabase. Kein persistenter Katalogcache auf Endgeräten. Private Sammlungen und ihre gesonderten Offline-Funktionen bleiben unabhängig davon.

Ablauf: online Katalog-Lookup → bei fehlendem Treffer KI-Vorschlag → Nutzer prüft und korrigiert → vollständiger Eintrag in privater Sammlung → **ausdrücklicher Bestätigungsschritt** für einen möglichen Katalogbeitrag → private Queue → serverseitige Lizenz-, Datenschutz-, Qualitäts- und Duplikatprüfung → nur erlaubte Basisfakten freigeben.

Eine Nutzerbestätigung ist kein Beweis sachlicher Richtigkeit und keine Lizenzfreigabe. Drittdaten (insbesondere Google Books) werden ohne geprüfte Rechte nicht in den öffentlichen Katalog übernommen.

## Tatsächlich implementierter Teil
Migration `20261106180000_confirmed_catalog_contributions.sql`:
- entfernt den bisherigen Trigger, der auf jedem Insert/Update ungeprüft Beiträge in die Queue eingetragen hat;
- ergänzt `confirmed_at` und `confirmed_item_updated_at` in der **privaten** `kovunela_catalog.contribution_queue`;
- bietet die authentifizierte RPC `public.kv_confirm_item_catalog_contribution(uuid)`;
- prüft `auth.uid()`, tatsächliche Ersteller-ID, nicht gelöschten Eintrag sowie einen nichtleeren Titel; verhindert so, dass Nutzer fremde Objekte bestätigen;
- setzt einen bestätigten Datensatz auf `pending`, ohne ihn öffentlich zu veröffentlichen;
- schränkt die RPC-Ausführung auf `authenticated` ein.

Der spätere Worker muss einen Beitrag ignorieren, falls sich `items.updated_at` seit der Bestätigung verändert hat; dies verhindert eine nachträgliche Veränderung der bestätigten Vorlage. Die Queue enthält interne `item_id` und `workspace_id` ausschließlich im nicht exponierten Schema, keine öffentliche Antwort darf diese IDs offenlegen.

## Ausstehend – nicht als fertig ausgeben
- Flutter: reale KI-Erfassung, vollständiges Speichern der geprüften Vorlage und anschließende bewusste Bestätigung über die neue RPC miteinander verbinden. Die bisherige ISBN-Ansicht ist **review-only**, die KI-Demo speichert überhaupt nicht.
- Worker: stabile Identifier-Normalisierung, PII-/Freitext-Filter, einzelne erlaubte Fakten, Quellenprüfung, Attribution und rechtliche Erlaubnis, Konfliktlösung, Freigabe, Entzug und Löschung.
- End-to-End-Tests mit zwei echten JWTs, negative Berechtigungstests und GitHub-CI.
- Bereits live vorhandene Supabase-Migrationen vollständig nach GitHub synchronisieren (Paket 22 und Auto-Beitrags-Queue).
- Bestehende Security-Advisor-Warnungen getrennt beheben.

**Keine automatische Veröffentlichung ohne bestätigten und lizenzrechtlich zulässigen Prozess.**
