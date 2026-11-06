import 'dart:typed_data';

import 'package:curio/features/capture/photo_selection_service.dart';
import 'package:curio/l10n/app_localizations.dart';
import 'package:curio/screens/capture/photo_capture_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakePhotoService implements PhotoSelectionService {
  _FakePhotoService(this.photo);
  final CapturedPhoto? photo;
  @override
  Future<CapturedPhoto?> select(PhotoSource source) async => photo;
}

void main() {
  final fakeJpeg = Uint8List.fromList([
    0xff, 0xd8, 0xff, 0xe0, 0, 0, 0, 0,
  ]);

  test('photo signatures are enforced and bytes are size-limited', () {
    final selected = ImagePickerPhotoSelectionService.fromBytes(
      fakeJpeg,
      PhotoSource.gallery,
    );
    expect(selected.mimeType, 'image/jpeg');
    expect(selected.bytes, same(fakeJpeg));
    expect(
      () => ImagePickerPhotoSelectionService.fromBytes(
        Uint8List.fromList([0, 1, 2]),
        PhotoSource.gallery,
      ),
      throwsFormatException,
    );
    expect(
      () => ImagePickerPhotoSelectionService.fromBytes(
        Uint8List(700001),
        PhotoSource.gallery,
      ),
      throwsFormatException,
    );
  });

  testWidgets('photo stays local and consent cannot enable gated API',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('de'),
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        home: PhotoCaptureScreen(
          photoService: _FakePhotoService(CapturedPhoto(
            bytes: fakeJpeg,
            mimeType: 'image/jpeg',
            source: PhotoSource.gallery,
          )),
        ),
      ),
    );
    await tester.tap(find.text('Aus Galerie auswählen'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('photo-preview')), findsOneWidget);
    expect(find.byKey(const ValueKey('photo-vision-disabled')), findsOneWidget);

    final analyze = find.byKey(const ValueKey('analyze-photo'));
    expect(tester.widget<FilledButton>(analyze).onPressed, isNull);
    await tester.ensureVisible(find.byKey(const ValueKey('photo-consent')));
    await tester.tap(find.byType(CheckboxListTile));
    await tester.pumpAndSettle();
    expect(tester.widget<CheckboxListTile>(
      find.byType(CheckboxListTile)).value, isTrue);
    expect(tester.widget<FilledButton>(analyze).onPressed, isNull);

    await tester.ensureVisible(find.text('Foto verwerfen'));
    await tester.tap(find.text('Foto verwerfen'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('photo-preview')), findsNothing);
    expect(find.byKey(const ValueKey('photo-consent')), findsNothing);
  });

  testWidgets('picker errors do not imply a photo was uploaded',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('de'),
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        home: PhotoCaptureScreen(
          photoService: _FakePhotoService(null),
        ),
      ),
    );
    await tester.tap(find.text('Aus Galerie auswählen'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('photo-preview')), findsNothing);
    expect(find.byKey(const ValueKey('analyze-photo')), findsNothing);
  });
}
