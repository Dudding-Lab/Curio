# Kovunela – Manuelle Objekte speichern (Web-MVP)

Die bestehende Flutter-Web-App erhält ihre erste nutzbare Objekt-Erfassung.
- Auf der Startseite: **Manuell erfassen**.
- Unter **Meine Objekte**: zusätzliche Schaltfläche **Manuelle Erfassung**.
- Titel erforderlich, Beschreibung optional; Formular validiert beide Eingaben vor der Prüfung.
- Nach **Angaben prüfen** genau eine explizite Speicheraktion **Gegenstand speichern**.
- `public.kv_create_personal_item` legt den Datensatz unter dem *authentifizierten* Benutzer an, ohne vom Client gesendete Benutzer- oder Workspace-IDs.
- Erst nach bestätigter Server-Antwort erfolgt Navigation zu `/items`; die Liste wird neu per `public.kv_list_personal_items` geladen.
- Fehler erhalten den eingegebenen Entwurf; mehrfaches Speichern während laufender RPC ist blockiert.
- Die existierende serverseitige interne Contribution-Queue verarbeitet neue Datensätze unabhängig vom Client. Private Daten werden **nicht** automatisch öffentlich veröffentlicht.

## Sicherheit / Freigabe
`KOVUNELA_ENABLE_PERSONAL_ITEM_SAVE=true` wird **ausschließlich** im opt-in GitHub-Pages-Deployment für das hart geprüfte Supabase-Development-Projekt gesetzt. Der Standardwert bei anderen Builds bleibt `false`. Der reale Zwei-Auth-Benutzer-Test hat bereits das Erstellen und Auflisten privater Datensätze, RLS/Access-Checks und anonyme Zugriffssperren bestätigt: https://github.com/Dudding-Lab/Curio/actions/runs/42361967481.

Bild-/KI-Upload bleibt hinter `KOVUNELA_ENABLE_VISION_UPLOAD=false`, keine globale Katalogpublikation. Noch nicht implementiert: Typ-/Template-Auswahl im manuellen Formular, Objektbearbeitung und -löschung, ISBN/Fotodaten-Übernahme in denselben Speicherflow.

## Prüfungen
- `flutter test` und `flutter analyze` über Workflow `Flutter quality checks`.
- Flutter-Web-Kompilierung über `Kovunela web build`.
- Manuelle Browser-Prüfung nach Deployment: mit Testuser 1 Titel/Beschreibung speichern; Eintrag unter Meine Objekte sehen; mit Testuser 2 sicherstellen, dass der Eintrag nicht auftaucht. Dabei können bereits vorhandene synthetische Testdaten angezeigt werden.
