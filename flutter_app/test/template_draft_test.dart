import 'package:curio/features/taxonomy/template_catalog_repository.dart';
import 'package:curio/features/taxonomy/template_draft.dart';
import 'package:curio/l10n/app_localizations.dart';
import 'package:curio/screens/taxonomy/template_draft_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('extension rejects duplicates and invalid keys without mutating schema', () {
    final draft = TemplateDraft(
      standardCode: 'book',
      standardFields: {'isbn': 'text'},
    );
    expect(draft.addField('isbn', 'number'), 'duplicate_key');
    expect(draft.addField('Invalid Key', 'text'), 'invalid_key');
    expect(draft.addField('rating', 'integer'), 'invalid_type');
    expect(draft.addedFields, isEmpty);
    expect(draft.addField('reading_status', 'text'), isNull);
    expect(draft.fields['isbn'], 'text');
    expect(draft.fields['reading_status'], 'text');
  });

  test('dynamic preview validates and serializes typed metadata', () {
    final draft = TemplateDraft(
      standardCode: 'camera',
      standardFields: {
        'manufacturer': 'text',
        'purchase_year': 'number',
        'working': 'boolean',
        'purchased': 'date',
      },
    );
    draft.values.addAll({
      'manufacturer': ' Canon ',
      'purchase_year': '1997',
      'working': false,
      'purchased': '2026-11-06',
    });
    expect(draft.validatedAttributes(), {
      'manufacturer': 'Canon',
      'purchase_year': 1997,
      'working': false,
      'purchased': '2026-11-06',
    });
    draft.values['purchase_year'] = 'not a number';
    expect(() => draft.validatedAttributes(), throwsFormatException);
    draft.values['purchase_year'] = '1997';
    draft.values['purchased'] = '2026-02-30';
    expect(() => draft.validatedAttributes(), throwsFormatException);
  });

  test('hidden fields retain data while presentation order changes', () {
    final draft = TemplateDraft(
      standardCode: 'book',
      standardFields: {'author': 'text', 'isbn': 'text'},
    );
    draft.hiddenFields.add('isbn');
    draft.fieldLabels['author'] = 'Verfasser';
    draft.values['isbn'] = '1234567890';
    expect(draft.visibleFieldKeys, ['author']);
    expect(draft.labelFor('author'), 'Verfasser');
    expect(draft.validatedAttributes()['isbn'], '1234567890');
  });

  testWidgets('template draft edits and previews typed fields without saving',
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
        home: TemplateDraftScreen(
          standardCode: 'camera',
          initialTemplate: StandardObjectTemplate(
            id: 'camera-id',
            code: 'camera',
            title: 'Kamera',
            categoryCode: 'technology',
            version: 1,
            fields: {
              'maker': 'text',
              'working': 'boolean',
            },
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Nur Vorschau: Diese Änderungen werden noch nicht gespeichert.'),
        findsOneWidget);
    expect(find.text('maker · text'), findsOneWidget);
    expect(find.text('working · boolean'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Formular testen'),
      250,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.ensureVisible(find.text('Formular testen'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Formular testen'));
    await tester.pumpAndSettle();
    expect(find.byType(SwitchListTile), findsOneWidget);
    expect(find.text('Formular prüfen'), findsOneWidget);
    expect(find.text('Gegenstand speichern'), findsNothing);
  });
}
