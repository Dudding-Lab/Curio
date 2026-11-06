# Kovunela – Verschlüsselte Offline-Datenbank pro Benutzer (Paket 21)

Stand: 6. November 2026. Entwicklungsbranch `feature/kovunela-ui-foundation`; `main` und Supabase-Tabellen unverändert.

## Architekturentscheid

Die lokale SQLite-Datenbank darf **niemals unverschlüsselt** angelegt werden. Das zuvor vorhandene `OfflineDatabase()`-Fallback auf ein unverschlüsseltes SQLite-File wurde entfernt; ein expliziter `QueryExecutor` ist nun zwingend.

Nach Prüfung der aktuellen Drift-Dokumentation wird `sqlite3` Version 3 / **SQLite3MultipleCiphers (sqlite3mc)** über einen `pubspec.yaml`-Build-Hook verwendet:
```yaml
hooks:
  user_defines:
    sqlite3:
      source: sqlite3mc
```

Die neue Datei `flutter_app/lib/features/offline/encrypted_offline_database.dart` implementiert `EncryptedOfflineDatabaseFactory` und `SecureOfflineEncryptionKeyStore`.

1. Nur syntaktisch gültige Supabase-Account-UUIDs dürfen eine eigene Datenbank öffnen. Der Dateiname ist zusätzlich nach dem Supabase-Projekt-Host getrennt.
2. Jeder Benutzer erhält einen eigenen, kryptographisch zufälligen 256-Bit-Schlüssel (Base64URL-kodiert); Schlüssel liegen über `flutter_secure_storage` in der mobilen OS-Schlüsselspeicherung, **nicht** im SQLite-File.
3. Bei erstmaliger Erstellung speichert die Factory den Schlüssel und startet den nativen Drift-Executor. Bevor irgendeine SQL-Tabelle erstellt wird, überprüft sie zur Laufzeit `PRAGMA cipher;` auf einen tatsächlich geladenen Verschlüsselungs-Backend und setzt `PRAGMA key`.
4. Der Schlüssel wird vor dem Zugriff auf die Schema-Tabelle angewendet; bei falschem Schlüssel schlägt der Lesezugriff fehl. Fehlende Schlüssel bei vorhandener Datei führen zu einem Fehler, **nicht** zu einer automatischen Neuanlage oder Datenlöschung.
5. Existierende Dateien, deren Header mit dem bekannten unverschlüsselten SQLite-Signaturtext beginnt, werden abgewiesen. Eine etwaige Migration ist ein **eigener, ausdrücklich autorisierter Vorgang**, keine stille Umwandlung.
6. Account-/Workspace-Zuordnungen innerhalb der lokalen Datenbank bleiben bestehen, ersetzen aber nicht die Verschlüsselung. Die vorhandene Outbox wird dadurch ebenfalls als Teil der SQLite-Datei verschlüsselt.

### Automatisierte Sicherheitsprüfungen

`flutter_app/test/encrypted_offline_database_test.dart` testet:
- Datei öffnen, Datensatz schreiben und schließen, dann Dateibits auf SQLite-Klartextheader und Klartextinhalte prüfen.
- Mit demselben Geräteschlüssel erneut öffnen und gespeicherte Gegenstände wieder lesen.
- Trennung von Datei und Verschlüsselungsschlüssel für zwei Konten.
- Falscher Schlüssel, verlorener Schlüssel, unverschlüsselte Legacydatei und bösartige Account-ID müssen scheitern.
- Bereits bestehende SQLite-/Outbox-/Konto-Isolationstests bleiben unverändert bestehen.

## Sicherheitsgrenzen und **noch nicht aktivierte Features**

**Diese Factory ist absichtlich noch nicht in Home, Sammlungsansichten oder Upload/Sync-Repositories verdrahtet.** Ihre Tests beweisen Dateiverschlüsselung auf dem Linux-CI-Runner, **noch nicht** das Verhalten nach Android-/iOS-Sperren, Geräte-Neustart, Face ID oder Keystore/Keychain-Restore. Vor echten Benutzerdaten erforderlich:

- Gerätesperre mit `OfflineAccessController` und Verknüpfung der entsperrten Identität mit der zu öffnenden Datenbank. Alle offenen DB-Verbindungen nach Logout, Kontowechsel und Sperren schließen.
- Sicheres Sperren und Bereinigen von Android-Keystore/iOS-Keychain-Schlüsseln bei Logout, Benutzerwechsel oder Datenlöschwunsch. Entscheidung, ob ein abgemeldetes Konto lokal erhalten bleibt, muss explizit sein: Schlüsselverlust würde alle noch nicht synchronisierten Daten unwiederbringlich machen.
- Datenbank-Keychain/Keystore-Migrationen, Backup-/Restore-, Neuinstallations- und Gerätewechsel-Verhalten auf echter Hardware prüfen.
- Sicherstellen, dass auch Medien-Dateien (Fotos, Vorschaubilder) verschlüsselt werden und Backups nicht ungewollt unverschlüsselte Informationen enthalten.
- Vor Einsatz von `OfflineDatabase` in Flutter sind die lokalen Tabellen vollständig zu modellieren, der serverseitige Sync inkl. Idempotenz/Optimistic Locking bereitzustellen und echte Zwei-Benutzer-Tests durchzuführen.
- Die noch existierenden Online-Listen werden bisher weiterhin direkt aus Supabase gelesen. **Die App bietet deshalb noch keine vollständige Offline-Sammlungsverwaltung.**
- Es wurden in Paket 21 weder neue Supabase-Tabellen angelegt noch produktive Berechtigungen verändert.

## Referenz

- <https://drift.simonbinder.eu/platforms/encryption/> – offizielle Drift-Anleitung für SQLite3MultipleCiphers und `NativeDatabase`
- `flutter_app/lib/features/offline/offline_database.dart`
- `flutter_app/lib/features/offline/encrypted_offline_database.dart`
- `flutter_app/test/encrypted_offline_database_test.dart`

GitHub-CI: 65 bestandene Tests, 1 realer Zwei-Benutzer-Supabase-Test übersprungen; SHA und Run in der zugehörigen Entwicklungskonversation.
