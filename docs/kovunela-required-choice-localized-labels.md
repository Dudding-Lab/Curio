# Kovunela – Pflichtfelder, Auswahlfelder und übersetzte Feldlabels

Stand: 6. November 2026. Entwicklungsbranch `feature/kovunela-ui-foundation`, Supabase-Entwicklungsprojekt `tgawxheqrcqhcvxaexvd`. Keine Änderungen an `main`.

## Feldmodell

Eine Text-Feldeigenschaft kann eine optionale **Auswahlliste** erhalten. In der ersten Ausbaustufe sind es 2–30 eindeutige, nichtleere Textwerte, jeweils höchstens 120 Zeichen. Der gespeicherte Wert bleibt ein einfacher String; dadurch bleibt das bestehende Schema mit den Basistypen `text/number/boolean/date` kompatibel.

Jedes Feld kann als **Pflichtfeld** markiert werden. In der Erfassungsvorschau werden fehlende oder leere Pflichtwerte abgelehnt; bei Booleans ist `false` ein gültiger Wert. Pflichtfelder können nicht gleichzeitig ausgeblendet werden, wenn diese Regel in der UI gesetzt wird.

Für jede Eigenschaft können **lokalisierte Feldlabels** gespeichert werden, zum Beispiel `{"de":"Autor","en":"Author","fr":"Auteur"}`. Die Anzeige nimmt die exakte App-Sprache, danach die Basissprache und schließlich den allgemeinen Anzeigenamen oder den technischen Schlüssel. Die Labels sind bewusst unabhängig von der Übersetzung des Objektinhalts.

Beispiel-Präsentationsschema (für persönliche Vorlagen):
```json
{
  "binding": {
    "required": true,
    "choices": ["Hardcover", "Paperback"],
    "labels": {"de":"Einband", "en":"Binding"},
    "translation_mode": "original"
  },
  "description": {
    "labels": {"de":"Beschreibung", "en":"Description"},
    "translation_mode": "translate"
  }
}
```

## Implementiert

- Flutter: `TemplateDraft` verwaltet `requiredFields`, `fieldChoices`, `localizedLabels`. `validatedAttributes()` prüft Pflichtwerte und Auswahlwerte. Der Editor bietet für jedes Feld einen Pflicht-Schalter und Feldbezeichnungen je Sprache, bei Textfeldern ein kommagetrenntes Auswahlfeld. Die Vorschau zeigt Auswahllisten als Dropdown.
- Supabase: Migrationen `kovunela_validate_required_choice_and_localized_field_presentation` und `kovunela_enforce_required_and_choice_metadata_in_typed_item_rpc`. Die Konfigurations-RPC prüft Form und Länge von Labels, Sprachcodes, Pflicht-Flags und Choice-Arrays, einschließlich der Beschränkung auf Textfelder. Die typisierte Gegenstands-Erfassungs-RPC kontrolliert Pflichtfelder und erlaubte Auswahlwerte anhand der persönlichen Vorlagenpräsentation.
- Bestehende Nutzerobjekte werden nicht geändert. Es gibt noch keine freigeschaltete Schreibaktion im Flutter-Editor. Die Feldbezeichnungs- und Formularvorschau bleibt lokal.

## Absichtlich noch offen

1. Reale Tests mit zwei separat authentifizierten Testbenutzern, inklusive Haushaltsrollen und unzulässigen Schema-Änderungen.
2. Versionsbezogene Speicherung der Präsentationsregeln: Änderungen an den Regeln einer bestehenden Vorlage können derzeit die Validierung später angelegter Datensätze beeinflussen. Vor produktiver Aktivierung sollten Regeln pro Version eingefroren und kompatibel migriert werden.
3. Übersetzte Anzeigenamen der einzelnen Auswahlwerte (aktuell nur die Feldlabels lokalisiert); stabilere maschinenlesbare Choice-IDs.
4. Bessere Validierung und Fehlermeldungen direkt im Editor, Auswahlfeld-Editor statt Kommatrennung sowie eine ausdrückliche Nutzerprüfung vor persistierenden Aktionen.
5. KI-Vorschläge für Pflichtangaben, Auswahloptionen und lokalisierte Feldbezeichnungen.
