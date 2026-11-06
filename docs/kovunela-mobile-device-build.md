# Kovunela – Mobile Android-/iOS-Projektvorbereitung

Stand 06.11.2026 · Branch `feature/kovunela-ui-foundation`. Änderungen ausschließlich im Entwicklungsbranch; keine App-Store-Veröffentlichung.

## Warum die Plattformdateien erzeugt werden

Das vorhandene Repository enthält Flutter-Dart-Code, Tests und `pubspec.yaml`, jedoch noch keine eingecheckten vollständigen `android/`- und `ios/`-Runner. Gradle-, Kotlin-, Android- und Xcode-Templates ändern sich mit Flutter-Versionen. Deshalb verwenden wir **die offiziellen Flutter-Templates der installierten SDK-Version** und halten nur reproduzierbare Konfigurationsschritte im Repository vor, statt fragile Einzeldateien zu erfinden.

### Reproduzierbare Projektgenerierung

Auf Linux (Android) beziehungsweise macOS (Android und iOS), im Repository:

```bash
cd flutter_app
bash tool/bootstrap_mobile.sh
```

Das Skript führt `flutter create --platforms=android[,ios] --project-name=curio --org=de.kovunela .` aus und ergänzt die minimalen Berechtigungen.

- **Android:** `tool/configure_android_permissions.py` setzt idempotent nur `android.permission.INTERNET` für Supabase, aber **keine breiten Speicherrechte**. `image_picker` nutzt systemeigene Auswahl-/Kameraaktionen.
- **iOS:** `tool/configure_ios_permissions.py` ergänzt `NSCameraUsageDescription` und `NSPhotoLibraryUsageDescription` in der generierten `Runner/Info.plist`. Es wird keine Mikrofonberechtigung angefordert (keine Videoaufnahme).
- **Vor Store-Veröffentlichung:** Android-Paketname und iOS-Bundle-Identifier prüfen und verbindlich festlegen. Der aktuell generierte Wert `de.kovunela.curio` ist ein technischer Platzhalter, keine freigegebene Store-Identität.

Die generierten Runner werden **nicht automatisch nach GitHub zurückgeschrieben**. Sie stehen im lokalen Entwicklungsverzeichnis beziehungsweise im CI-Workspace zur Verfügung. Für eine spätere dauerhafte Plattformstruktur sollten die generierten Dateien nach Review explizit eingecheckt werden.

## Android-Debug-APK in GitHub Actions

`.github/workflows/android-debug-apk.yml` erzeugt in einem isolierten Runner den Android-Shell, löst Flutter-Dependencies auf, generiert die Lokalisierung und baut ein **Debug-APK**. Nach erfolgreichem Build veröffentlicht die Action ein 7 Tage verfügbares Artifact `kovunela-android-debug-apk` mit `app-debug.apk`.

Der ressourcenintensive Debug-Build wird bewusst nur über **GitHub Actions → Android debug device build → Run workflow** gestartet; der normale Flutter-Testworkflow läuft bei jedem Push. Der Debug-Build enthält die **öffentliche** Projekt-URL und den dafür bestimmten **Supabase Publishable Key** des Curio-/Kovunela-Testprojekts. Diese Werte sind ausdrücklich keine Geheimnisse; sie identifizieren das zu verwendende Testbackend. Niemals `service_role`, `sb_secret`, OpenAI- oder Google-Books-Secret in die App packen!

Beide KI-/Speicher-Flags werden beim APK-Build auf `false` gesetzt:
```
KOVUNELA_ENABLE_VISION_UPLOAD=false
KOVUNELA_ENABLE_PERSONAL_ITEM_SAVE=false
```

### APK auf Android installieren und testen

1. GitHub Actions öffnen und den neuesten **Android debug device build** wählen.
2. Unter **Artifacts** `kovunela-android-debug-apk` laden; ZIP entpacken.
3. `app-debug.apk` auf einem eigenen Android-Gerät installieren. Bei Bedarf Android-Einstellungen für das Installieren aus dieser Quelle bewusst bestätigen.
4. Mit einem **Testkonto im Curio-Supabase-Testprojekt** anmelden. Danach: `Foto aufnehmen` → Kamera/Galerie → lokale Vorschau → Verwerfen und Einwilligungs-Checkbox testen.
5. Es darf **keine** KI-Anfrage übertragen werden und kein Gegenstand gespeichert werden. Die Schaltfläche „Foto analysieren“ bleibt deaktiviert.

Ein APK aus einer GitHub-Action ist ein **Debug-Testbuild**, kein Play-Store-Release und kein verifizierter Test auf echter Hardware. Die Möglichkeit, sich anzumelden, hängt von den Auth-/SMTP-Einstellungen des Testprojekts und gültigen Testaccounts ab.

## Android-Lifecycle: Wiederherstellung

`ImagePickerPhotoSelectionService` implementiert jetzt `PhotoRecoveryService.recoverLostPhoto()` über `ImagePicker.retrieveLostData()`. Der Foto-Screen ruft diese Wiederherstellung beim Öffnen auf. Wiedergefundene Bilder werden genauso auf Format und 700-KB-Grenze geprüft wie neue. Eine Wiederherstellung **setzt keine vorherige Einwilligung** wieder ein, startet **keine automatische Analyse** und speichert nichts.

Die automatische Wiederherstellung benötigt auf einem realen Android-Gerät noch einen Lebenszyklus-Test: Fotoauswahl öffnen, App im Hintergrund beenden lassen, App neu starten und Foto-Screen öffnen. Die Unit-/Widget-Tests verwenden injizierte Testdienste.

## Noch offen

- Der eigentliche Android-/iOS-Runner ist bis zum expliziten Einchecken auf CI-/Entwicklungsgeräte beschränkt; nach späteren Flutter-Updates muss die Kompatibilität der Generator-Konfiguration geprüft werden.
- Ein **echter Android-Hardwaretest**, iOS-Build auf macOS, Signierung, Store-IDs, Launcher-Icons, Splash-Screen, Deep Links und Integrations-Tests mit zwei Supabase-Auth-Konten stehen aus.
- Bilder werden vor dem Upload noch **nicht garantiert neu kodiert und von EXIF/GPS-Daten befreit**. KI-Upload bleibt deshalb deaktiviert.
- Fotoauswahl per Systemdialog und Android-Lifecycle sind nicht mit reinen Flutter-Widget-Tests vollständig testbar. Die Debug-APK hilft bei der anschließenden manuellen Validierung.

## Referenzen

- Flutter Android-Build: https://docs.flutter.dev/deployment/android
- Flutter image_picker: https://pub.dev/packages/image_picker
- Build-Workflow: `.github/workflows/android-debug-apk.yml`
- Foto-Recovery-Test: `flutter_app/test/photo_capture_test.dart`
