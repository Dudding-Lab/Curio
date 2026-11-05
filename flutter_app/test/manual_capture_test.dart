import 'package:curio/features/capture/manual_item_draft.dart';
import 'package:curio/l10n/app_localizations.dart';
import 'package:curio/screens/capture/manual_capture_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('manual item draft normalizes and validates without a collection', () {
    const draft = ManualItemDraft(
      title: '  My camera  ',
      description: '  On the shelf  ',
    );
    expect(draft.validate(), isNull);
    expect(draft.normalized().title, 'My camera');
    expect(draft.normalized().description, 'On the shelf');
    expect(const ManualItemDraft(title: '   ').validate(), 'title');
    expect(
      ManualItemDraft(title: 'x' * 201).validate(),
      'title',
    );
  });

  testWidgets('review requires a name and never claims backend save',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        locale: Locale('de'),
        localizationsDelegates: [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        home: ManualCaptureScreen(),
      ),
    );
    await tester.tap(find.text('Angaben prüfen'));
    await tester.pumpAndSettle();
    expect(find.text('Bitte einen Namen für den Gegenstand eingeben.'),
        findsOneWidget);

    await tester.enterText(
      find.byType(TextFormField).first,
      'Meine Kamera',
    );
    await tester.tap(find.text('Angaben prüfen'));
    await tester.pumpAndSettle();
    expect(find.text('Gegenstand prüfen'), findsWidgets);
    expect(find.text('Meine Kamera'), findsOneWidget);
    expect(find.text('Eine Sammlung ist optional.'), findsOneWidget);

    final save = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Gegenstand speichern'),
    );
    expect(save.onPressed, isNull);
  });
}
