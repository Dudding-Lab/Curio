import 'package:curio/features/taxonomy/template_catalog_repository.dart';
import 'package:curio/l10n/app_localizations.dart';
import 'package:curio/screens/taxonomy/standard_templates_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeCatalog implements TemplateCatalogRepository {
  @override
  Future<List<StandardObjectTemplate>> listStandards() async => [
        const StandardObjectTemplate(
          id: 'standard-book',
          code: 'book',
          title: 'Buch',
          categoryCode: 'books',
          version: 1,
          fields: {'author': 'text', 'isbn': 'text'},
        ),
      ];

  @override
  Future<String> deriveStandard({
    required String standardId,
    String? title,
    Map<String, String> addedFields = const {},
  }) => throw UnimplementedError();
  @override
  Future<void> sharePersonalTemplate({
    required String templateId,
    required String householdWorkspaceId,
  }) => throw UnimplementedError();
  @override
  Future<List<SharedObjectTemplate>> listSharedForWorkspace(
    String workspaceId,
  ) => throw UnimplementedError();
  @override
  Future<String> copySharedIntoWorkspace({
    required String templateId,
    required String householdWorkspaceId,
  }) => throw UnimplementedError();
}

void main() {
  test('catalog entry exposes typed standard schema and version', () {
    final standard = StandardObjectTemplate.fromJson({
      'id': 'b',
      'code': 'book',
      'title': 'Buch',
      'category_code': 'books',
      'version': 1,
      'field_schema': {'author': 'text', 'pages': 'number'},
    });
    expect(standard.code, 'book');
    expect(standard.version, 1);
    expect(standard.fields['pages'], 'number');
  });

  test('shared template keeps destination-independent version reference', () {
    final shared = SharedObjectTemplate.fromJson({
      'template_id': 't1',
      'title': 'Kamera',
      'version_id': 'v1',
      'field_schema': {'manufacturer': 'text'},
    });
    expect(shared.templateId, 't1');
    expect(shared.versionId, 'v1');
  });

  testWidgets('read-only official catalog lists book template',
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
        home: StandardTemplatesScreen(repository: _FakeCatalog()),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Standardvorlagen'), findsOneWidget);
    expect(find.text('Buch'), findsOneWidget);
    expect(find.text('2 Eigenschaften'), findsOneWidget);
    expect(find.byType(FloatingActionButton), findsNothing);
  });
}
