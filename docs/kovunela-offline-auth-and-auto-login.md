# Kovunela – Automatische Anmeldung und sicherer Offline-Zugriff

Stand 06.11.2026 · Entwicklungsbranch `feature/kovunela-ui-foundation`.

## Verbindliches Produktverhalten

- Beim **ersten Besuch** auf einem Gerät ist eine Online-Anmeldung mit Supabase Auth erforderlich (einschließlich eventuell erforderlicher E-Mail-Bestätigung).
- Auf bereits registrierten Android-/iOS-Geräten wird die **gespeicherte Sitzung beim App-Start automatisch wiederhergestellt**. Falls das Zugriffstoken gültig ist, öffnet die App ohne erneute Passwortabfrage den normalen Bereich. Token-Erneuerung übernimmt das Supabase SDK, wenn Internet verfügbar ist.
- Sobald das Zugriffstoken **abgelaufen** ist, gewährt die App **keinen** Zugriff auf Online-Routen. Stattdessen führt die Navigation zu `/offline`. Dort muss der Gerätebesitzer mit PIN/Passcode oder Biometrie entsperren.
- Die Offline-Entsperrung verlangt: (1) einen restaurierten Sitzungs-Account, (2) ein nach **echter Online-Anmeldung** sicher gespeichertes Matching dieses Accounts auf dem Gerät und (3) erfolgreiche Geräte-Authentifizierung. Sie ist **keine serverseitige Anmeldung** und kann keine abgelaufene JWT für Supabase-API oder Haushaltsrechte ersetzen.
- Bei ausdrücklicher Abmeldung wird das lokale Konto-Merkmal gelöscht. Ein anderes Konto kann das vorhandene Konto-Merkmal nicht übernehmen.
- Die aktuell unverschlüsselte Drift-Datenbank wird **noch nicht** durch das Offline-Entsperren angezeigt. Die Offline-Ansicht kennzeichnet ihre Grenzen klar. Vollständig nutzbare Offline-Sammlungsansichten erfordern erst die verschlüsselte lokale Datenspeicherung und die berechtigungsgeprüfte Synchronisation.

## Implementierte Komponenten

- `features/offline/secure_session_storage.dart`: mobile Supabase-Sitzungs- und Refresh-Token über `LocalStorage` in `flutter_secure_storage` (Android Keystore / iOS Keychain) statt `SharedPreferences`. `Supabase.initialize` erhält `FlutterAuthClientOptions(localStorage: ..., persistSession:true, autoRefreshToken:true)`.
- `features/offline/offline_access_controller.dart`: `SecureKnownDeviceStore` speichert ausschließlich eine Kontokennung, `PlatformDeviceUnlock` nutzt `local_auth`. `OfflineAccessController` verweigert fremde Identitäten, fehlende Sitzungen und gescheiterte Geräteentsperrung.
- `core/router.dart`: reine Routingregel `authRedirect`: ohne Sitzung Login, mit gültiger Sitzung normale App, mit abgelaufener Sitzung ausschließlich gesonderter Offline-Modus bzw. manuelle Online-Anmeldung. Fehler bei Token-Erneuerung werden nicht als erfolgreiche Anmeldung behandelt und nicht ungefangen weitergeworfen.
- `screens/auth/offline_unlock_screen.dart`: lokale Geräteentsperrung und ausdrückliche Grenzen. Noch kein Offline-Zugriff auf Sammlungseinträge.
- `screens/auth/login_screen.dart`: legt Geräte-Konto-Merkmal erst nach erfolgreichem Login mit gültiger Sitzung an. `main.dart` löscht es bei `signedOut`.
- Android-Bootstrap ergänzt `USE_BIOMETRIC` und `FlutterFragmentActivity` für die Gerätesperre; iOS-Bootstrap ergänzt `NSFaceIDUsageDescription`.
- Alle sieben UI-Sprachversionen ergänzt. Automatisierte Tests decken Sitzungs-/Routingzustände und User-Isolation ab.

## Einschränkungen, Sicherheits- und Geräteprüfungen

1. **Kein echter Gerätetest** der Biometrie/PIN (Android/iOS) durchgeführt; native Projektdateien werden beim Build über Flutter generiert. Android-Build nach den neuen Änderungen ist noch zu validieren.
2. Die Umstellung der Session-Persistenz von SharedPreferences auf den sicheren Speicher übernimmt bestehende Sitzungsdaten **nicht automatisch**. Nach einem Update kann eine **einmalige neue Online-Anmeldung** nötig sein. Danach sollte sie ohne erneute Passworteingabe automatisch wiederhergestellt werden.
3. Online-Berechtigungen und Widerrufe von Haushaltsmitgliedschaften sind offline prinzipiell nicht erneut verifizierbar. Selbst ein lokales Geräte-Unlock kann niemals beweisen, dass eine Cloud-Berechtigung noch besteht.
4. `local_auth` benötigt sichere Gerätesperre; ohne PIN oder unterstützte Biometrie **kein** Offline-Unlock. Auf web-/Desktop-Plattformen ist diese neue Offline-Ansicht noch nicht produktreif.
5. Die lokale Drift-Datenbank ist bisher unverschlüsselt und nicht in normale Flutter-Sammlungsansichten integriert. Nicht als sicheren, fertigen Offline-Datenzugriff deklarieren. Weitere Voraussetzung: verschlüsselte DB-Dateien, benutzerspezifische Schlüssel, Zugriff nach Logout/Rollenentzug, sichere lokale Bilddateien.
6. Die App speichert **kein Klartextpasswort** und kein wiederverwendbares Offline-Passwort. Die Geräteprüfung ist eine lokale Zugangskontrolle, keine Übernahme des Supabase Auth-Systems.
7. Bis zum erfolgreichen echten Zwei-Benutzer-Test bleibt das schreibende Sync-System deaktiviert. Auch die zuvor gesperrte kostenpflichtige KI-Erfassung bleibt unverändert deaktiviert.

## Nachfolgende Pakete

- Verschlüsselte, nutzerspezifische SQLite- und Medien-Dateien mit Keystore/Keychain-Schlüssel; sorgfältige Migrations- und Neuinstallationsstrategie.
- Offline zugängliche Listen/Erfassungsansichten, nur nach erfolgreichem Geräte-Unlock und mit klaren Änderungszuständen.
- Serverseitig versionierte, idempotente Push-/Pull-Synchronisation mit RLS/Rollenprüfung und Konfliktbehandlung.
- Echte Android-/iOS-Tests für Neustart ohne Netzwerk, abgelaufenen JWT, Token-Refresh, Abmeldung, Konto-Wechsel, Haushaltsentzug sowie Geräte-PIN/Face ID/Fingerabdruck.

## Quellen

- Supabase Auth-Sessions: https://supabase.com/docs/guides/auth/sessions
- Supabase Flutter Sessionstart: https://supabase.com/docs/reference/dart/upgrade-guide
- Flutter secure storage: https://pub.dev/packages/flutter_secure_storage
- Flutter local_auth: https://pub.dev/packages/local_auth
