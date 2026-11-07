# Kovunela – Standardvorlagen, strukturierte Objekte und Katalogkandidaten

## Implementiert im Entwicklungs-Branch
- Die Flutter-Web-App bietet unter **Meine Objekte → Gegenstand erfassen** eine datengesteuerte Erfassung für die veröffentlichten Standardvorlagen **Buch, Kamera, Spiel, Film, Musik, Pflanze**.
- Die vorhandene einfache manuelle Erfassung bleibt erhalten und enthält einen Link **Mit Objektvorlage erfassen**.
- Vorlage auswählen, Titel/Beschreibung und passende Metadaten eingeben, Angaben prüfen, **einmal speichern**. Es gibt keine zusätzliche Freigabe für die interne Katalog-Aufbereitung.
- Unterstützte Attributtypen: Text, Zahl, Datum, Boolean. Für ISBN-10/-13 wird die Prüfziffer vor dem Speichern validiert.
- Neue RPC `public.kv_create_standard_personal_item` legt private Gegenstände mit einem serverseitig abgeleiteten Standardobjekttyp an. Nach Möglichkeit wird die zur Standardvorlage gehörige persönliche Vorlage wiederverwendet; parallele Speichervorgänge werden pro Benutzer/Standard serialisiert.
- Die private `kovunela.create_standard_personal_item` verwendet das authentifizierte `auth.uid()` und den serverseitigen privaten Workspace. Der öffentliche Wrapper läuft als `SECURITY INVOKER`; nur `authenticated` erhält EXECUTE. `anon` ist ausgeschlossen.
- Die bestehende Datenbankautomatik legt beim Speichern den internen Katalogbeitrag an und prüft ihn regelmäßig. Nur Bücher mit gültiger ISBN und einer echten Buchstandard-Ableitung werden als **interne Review-Kandidaten** gestaged, andere Gegenstände sicher übersprungen. Private Beschreibungen, benutzereigene Notizen und Besitzerdaten werden nicht veröffentlicht.
- Ein `review`-Eintrag ist **keine öffentliche Freigabe**: Veröffentlichung in `kovunela_catalog.entities` bleibt ein eigener späterer Prozess mit Qualität, Rechten und Dublettenkontrolle.

## Verifikation
- Reale Supabase-Zwei-Benutzer-Integration: beide Konten verwenden separate Auth-JWTs. Neues Szenario legt ein standardisiertes Buch mit Test-ISBN `9780306406157` an und bestätigt, dass Konto B dessen private ID nicht auflisten kann; anonymer RPC-Aufruf wird zurückgewiesen.
- Automatischer Worker hat das synthetische ISBN-Buch in `kovunela_catalog.review_candidates` mit Zustand `pending_review` eingereiht und die Queue auf `review` gesetzt; `kovunela_catalog.entities` enthielt weiterhin 0 öffentliche Entitäten.
- GitHub Flutter Quality Checks und Web-Build müssen vor dem Deployment erfolgreich sein.
- Supabase Security Advisor zeigt weiterhin ältere bestehende Findings (u.a. `public.item_loan_status` als Definer-View), die vor Produktionsfreigabe aufgearbeitet werden müssen. Die RPC-Änderung fügt nach Umstellung auf Invoker-Wrapper keine neue Definer-Warnung hinzu.

## Noch offen
- Eigene, vom Benutzer anpassbare Objektvorlagen direkt aus dem Erfassungsformular auswählen.
- EAN/GTIN bei weiteren Objektarten; aktuell nur die von Supabase gelieferten Standardfelder.
- Einbindung der ISBN-Suche und KI-Fotovorschläge in denselben Speicherablauf.
- Bearbeiten, Löschen, Sammlungszuordnung und vollständige Browser-End-to-End-Prüfung.
- Öffentliche Katalogpublikation mit Dublettenprüfung und Lizenz-/Provenienzregeln.
