# Kovunela – Fotoauswahl und ausdrückliche KI-Zustimmung

Stand 06.11.2026 · Entwicklungsbranch `feature/kovunela-ui-foundation`.

## Implementiert
- Auf der Startseite führt **Foto aufnehmen** nach `/capture/photo`. Die neue Seite bietet Kamera und Galerie über `image_picker: 1.2.4` (exakt gepinnt).
- Auswahl nutzt `maxWidth:1200`, `maxHeight:1200`, `imageQuality:65` und `requestFullMetadata:false`. Ein ausgewähltes Bild wird anhand der **binären JPEG-/PNG-Signatur** statt einer Dateiendung geprüft.
- Vor dem Lesen werden höchstens 700.000 Dateibytes akzeptiert; nach dem Lesen wird die Grenze erneut geprüft. Überschreitet ein Bild die Grenze oder liefert der Picker einen anderen Bildtyp (z. B. HEIC), zeigt die App einen lokalen Fehler statt eines Uploads. `imageQuality` und die Maximalmaße sind Picker-Parameter, **keine Garantie**, dass alle Plattformen das Bild umkodieren oder sämtliche EXIF/GPS-Daten entfernen.
- Das Bild wird nur lokal mit `Image.memory` vorab angezeigt. **Verwerfen** löscht die Referenz auf den ausgewählten Bildpuffer im Widget-State. Es wird nicht in die Sammlungsdatenbank geschrieben.
- Eine gesonderte Checkbox fordert Zustimmung zur späteren Übermittlung an OpenAI; sie wird bei **jedem neuen Foto** zurückgesetzt und beim Verwerfen gelöscht.
- `KOVUNELA_ENABLE_VISION_UPLOAD` ist per `bool.fromEnvironment` **standardmäßig false**. Selbst bei erteilter Zustimmung kann bei deaktiviertem Flag kein Request gesendet werden.
- Der künftig freischaltbare Ablauf verbindet `VisionSuggestionRepository` mit dem bestehenden `CaptureReview` und zeigt die vorgeschlagenen Felder zur manuellen Prüfung. Er löst keinerlei automatischen Save-Vorgang aus.
- `PhotoSelectionService` ist injizierbar. Tests können Auswahl, Fehler, Einwilligung und Verwerfen ohne echte Kamera oder Netzwerk prüfen.
- Texte und Einwilligungshinweise sind in allen sieben unterstützten ARB-Sprachdateien vorhanden.

## Technische Grenzen vor mobilen Builds
Das Repository enthält derzeit **keine** nativen `flutter_app/android/app/src/main/AndroidManifest.xml`- oder `flutter_app/ios/Runner/Info.plist`-Dateien. Für Android/iOS muss die vollständige Flutter-Projektstruktur angelegt beziehungsweise geprüft werden; dabei sind die jeweiligen nativen Kamera-/Fotobibliotheksrechte erforderlich. Auf iOS sind mindestens `NSCameraUsageDescription` und `NSPhotoLibraryUsageDescription` mit passenden nutzerfreundlichen Gründen zu ergänzen. Auf Desktop-Systemen kann die Kameraauswahl je nach Plattform nicht unterstützt sein; die Galerie bleibt eine Alternative.

Android kann bei Speicherdruck die App während des Plattform-Pickers beenden. Der Wiederherstellungsablauf mit `ImagePicker.retrieveLostData()` ist noch nicht implementiert. Bevor reale Android-Erfassung produktiv wird, ist dieser Pfad zu ergänzen und zu testen.

Derzeit wird nach dem Aufnehmen noch **kein** vollwertiges lokales Umkodieren/Metadaten-Stripping garantiert. Für sensible Fotos sollten Bilder vor der späteren Übermittlung standardisiert in JPEG/PNG neu kodiert und EXIF/GPS-Daten nachweislich entfernt werden.

## Sicherheits-Gates
- `KOVUNELA_ENABLE_VISION_UPLOAD=false` belassen. Die aktive Edge Function `kovunela-vision-analyze` besitzt zusätzlich einen serverseitigen Kill-Switch und startet keine kostenpflichtige KI-Anfrage ohne `OPENAI_API_KEY` und `KOVUNELA_VISION_ENABLED=true`.
- Reale Zwei-Benutzer-Sicherheitstests, Provider-/Kostenlimits, Datenschutzhinweise und Berechtigungsprüfungen bleiben Voraussetzung.
- Erst nach positiver Freigabe Foto-Versand aktivieren; niemals den API-Key in den Flutter-Code aufnehmen.
- Der Widget-/Unit-Test prüft nur die lokale Logik, nicht Kamera-Hardware, iOS-/Android-Berechtigungsdialoge oder einen echten OpenAI-Request.

## Quellen
- Flutter `image_picker`: https://pub.dev/packages/image_picker
- Supabase `kovunela-vision-analyze`: `supabase/functions/kovunela-vision-analyze/index.ts`
