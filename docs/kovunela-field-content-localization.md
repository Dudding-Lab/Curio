# Kovunela – Sprachabhängige Feldinhalte (November 2026)

## Entscheidung: Feldlabels und Feldwerte sind zwei unabhängige Sprachschichten

- **UI-/Feldbezeichnung**: Wird über die App-Lokalisierung und künftig lokalisierte Feldlabels angezeigt.
- **Feldinhalt**: Pro Textfeld einstellbar als `original` oder `translate`. Nicht-Textfelder dürfen nicht als übersetzbar markiert werden.
- **Originaltext**: Wird niemals durch eine maschinelle Übersetzung ersetzt. Bei Umschalten der App-Sprache kann nur eine vorhandene, gültige Sprachvariante angezeigt werden. Ohne Übersetzung erscheint automatisch das Original.
- **Standardannahmen im lokalen Editor**: `title`/ISBN/Autor etc. erhalten `original`; `description`, `summary`, `notes`, `synopsis`, `review` erhalten `translate`. Jede Texteigenschaft kann explizit umgestellt werden. Die App-eigene Gegenstandsbezeichnung `items.title` bleibt im Original; für `items.description` ist künftig die Übersetzungsanzeige vorgesehen.
- Bei Übersetzungsdienst-Ausfall oder fehlender Einwilligung darf die Sprachumschaltung nie Gegenstandsdaten verändern.

## Umgesetzt

### Supabase
Im Projekt `tgawxheqrcqhcvxaexvd` wurde die Migration `kovunela_per_field_translation_mode_and_original_text_snapshots` eingespielt.

- `kovunela.configure_personal_template` erlaubt nun unter `object_templates.presentation[fieldKey].translation_mode` ausschließlich `original` oder `translate` und überprüft auf dem Server, dass `translate` nur für Felder des Datentyps `text` verwendet wird. Standardannahme bei alten Vorlagen ohne gespeicherte Einstellung ist `original`; das Client-Editor-Modell wendet gesondert die beschriebenen sinnvollen Default-Regeln an.
- `kovunela.items.source_language` – optionaler BCP-47-artiger Sprachcode für den Quellinhalt. Noch nicht durch die Erfassungsoberfläche gesetzt.
- `kovunela.item_text_translations` – separate Textfassungen pro Gegenstand, Feld und Zielsprache; gespeichert werden Quelltext-Snapshot, Quellsprache, Zieltext, Zielsprache, Herkunftsart (`manual`/`ai`) und Aktualisierungszeit. RLS aktiv, derzeit **kein direkter Clientzugriff und kein RPC zum Schreiben**. Aufbewahrung/Änderung von Original und Übersetzung bleiben getrennt.

### Flutter
- Der lokale Vorlagenentwurf bietet pro Textfeld die Wahl „Immer Originaltext anzeigen“ versus „In der App-Sprache anzeigen (falls Übersetzung vorhanden)“.
- Neue Metadaten-Schnittstelle `TemplateDraft.translationModeFor`, `setTranslationMode` und `fieldPresentation`.
- `LocalizedText.display` wählt lediglich **vorhandene** Sprachfassungen aus und zeigt bei fehlender/veralteter Übersetzung das Original.
- Alle sieben Sprachdateien sind um die neuen Einstellungen erweitert.
- Unit-/Widget-Tests prüfen Buchtitel/ Beschreibung, Ablehnung nicht-textueller Felder, Sprach-Fallback, Originalerhalt und Steuerelemente.

## Explizit noch nicht umgesetzt
1. KI- oder manuelle Erstellung und Speicherung von Übersetzungen – dafür braucht es einen authorisierten Backend-Workflow und gegebenenfalls Kosten-/Einwilligungskontrollen.
2. Automatische, durch Sprachwechsel ausgelöste Übersetzungsaufträge – **nicht** die gewünschte Voreinstellung für Privatsphäre, Kosten und Performanz. Stattdessen ist ein optionaler Abruf bzw. eine bewusste Übersetzungsaktion geplant.
3. Lokalisation von Feldlabels und offizielle Standardtitel sowie mehrsprachige Varianten innerhalb einer Vorlage.
4. Speicherung der lokalen Vorlagen-Editorentwürfe ist bis zum erfolgreichen realen Zwei-Auth-Benutzer-Test weiterhin gesperrt; die `presentation`-RPC bleibt nur serverseitig vorbereitet.
5. Echte Zwei-Nutzer-/Haushalts-Isolationstests inklusive Übersetzungsdatensätzen, bevor ein lesender oder schreibender Übersetzungs-RPC verfügbar wird.
