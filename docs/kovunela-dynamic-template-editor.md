# Kovunela – Dynamischer Vorlagen- und Formularentwurf

Entwicklungsstand 06.11.2026, Branch `feature/kovunela-ui-foundation`. Die Oberfläche arbeitet bis zum erfolgreichen realen Zwei-Benutzer-Test **ausschließlich lokal**.

## Nutzerfluss

1. Auf der Startseite `Standardvorlagen` öffnen (`/templates/standard`).
2. Eine der sechs offiziellen Vorlagen auswählen; die App öffnet `/templates/standard/:code/draft`.
3. Im Editor die technische Feldstruktur sehen, neue Felder ergänzen und Anzeigenamen, Sichtbarkeit und Reihenfolge anpassen.
4. Mit `Formular testen` ein dynamisch aus den Vorlagenfeldern aufgebautes Eingabeformular öffnen.
5. Mit `Formular prüfen` die eingegebenen Werte clientseitig validieren. Das ist eine Vorschau, **keine serverseitige Speicherung und kein Template-Publishing**.

## Implementierung

- `features/taxonomy/template_draft.dart`: lokaler Entwurf ohne Netzwerkzugriff, keine Änderungen an globalen Standards. `TemplateDraft` hält Standardfelder, zusätzliche Feldtypen, Feldlabels, Sichtbarkeit und Reihenfolge und validiert Eingaben für JSON-Attribute.
- `screens/taxonomy/template_draft_screen.dart`: Editor + Vorschau mit Text-, Zahlen-, Datums- und Ja/Nein-Feldern. Angezeigte Feldreihenfolge kann verändert, nicht benötigte Felder können ausgeblendet werden.
- `screens/taxonomy/standard_templates_screen.dart`: Navigation in den Entwurf.
- Alle sieben ARB-Sprachvarianten ergänzt.
- `test/template_draft_test.dart`: Tests für Feldduplikate, Identifikator-Regeln, typisierte Konvertierung, ungültige Datumswerte, versteckte Felder und Widgets.

## Sicherheits- und Funktionsgrenzen

- Schreibende APIs wie `kv_derive_standard_template` oder `kv_configure_personal_template` werden **nicht** aus dieser neuen UI aufgerufen.
- Entwürfe bleiben nur während der Bildschirmnutzung im Speicher und gehen beim Verlassen verloren. Ein späterer Draft-Store muss explizit implementiert werden.
- Der Renderer ist derzeit ein funktionsfähiger Prototyp. Standardvorlagen liefern noch technische Feldschlüssel als Standardlabels; eine übersetzte Field-Label-Bibliothek ist noch zu ergänzen.
- Die Validierung im Editor erfolgt clientseitig. Vor einer Persistierung bleibt die Validierung durch die bestehenden Backend-RPCs verbindlich.
- Weitere Arbeiten: eigene Vorlagen im Editor öffnen, Feldpräsentation persistieren, Typversionen veröffentlichen, Felder lokalisiert benennen, Vorschau als echten Objekt-Review-Schritt verwenden.
- Reale JWT-Tests mit zwei eigenständigen Supabase-Benutzern und Haushaltsrechten bleiben erforderlich, bevor Schreiben in der Oberfläche aktiviert wird.
