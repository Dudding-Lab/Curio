import 'package:curio/features/capture/book_lookup_repository.dart';
import 'package:curio/features/taxonomy/template_catalog_repository.dart';
import 'package:curio/l10n/app_localizations.dart';
import 'package:curio/screens/capture/isbn_lookup_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeBooks implements BookLookupRepository {
  @override
  Future<List<GoogleBookCandidate>> byIsbn(String isbn) async => [
        const GoogleBookCandidate(
          title: 'Die unendliche Geschichte',
          sourceId: 'book-id',
          attributes: {
            'isbn': '9783522202602',
            'author': 'Michael Ende',
            'publication_year': 1979,
          },
        ),
      ];
}

class _FakeCatalog implements TemplateCatalogRepository {
  @override
  Future<List<StandardObjectTemplate>> listStandards() async => [
        const StandardObjectTemplate(
          id: 'template-id',
          code: 'book',
          title: 'Buch',
          categoryCode: 'books',
          version: 1,
          fields: {
            'isbn': 'text',
            'author': 'text',
            'publication_year': 'number',
          },
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
  @override
  Future<String> copyOwnedToWorkspace({
    required String templateId,
    required String targetWorkspaceId,
  }) => throw UnimplementedError();
  @override
  Future<String> moveOwnedToWorkspace({
    required String templateId,
    required String targetWorkspaceId,
  }) => throw UnimplementedError();
  @override
  Future<void> configurePersonalTemplate({
    required String templateId,
    required Map<String, Map<String, dynamic>> fieldPresentation,
  }) => throw UnimplementedError();
  @override
  Future<Map<String, dynamic>?> getPersonalTemplatePresentation(
    String templateId,
  ) => throw UnimplementedError();
  @override
  Future<bool> revokePersonalShare({
    required String templateId,
    required String householdWorkspaceId,
  }) => throw UnimplementedError();
}

void main() {
  test('Google Books adapter maps only catalog attributes to review input', () {
    final item = GoogleBookCandidate.fromJson({
      'source': 'google_books',
      'title': 'Example book',
      'source_id': 'volume-123',
      'attributes': {'isbn': '9783522202602', 'author': 'Example'},
    });
    final proposal = item.toSuggestion();
    expect(proposal.templateCode, 'book');
    expect(proposal.attributes['isbn'], '9783522202602');
    expect(proposal.title, 'Example book');
    expect(
      () => GoogleBookCandidate.fromJson({
        'source': 'other',
        'title': 'Example',
        'source_id': 'x',
        'attributes': <String, dynamic>{},
      }),
      throwsFormatException,
    );
  });

  testWidgets('ISBN search presents real source data for review without save',
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
        home: IsbnLookupScreen(
          repository: _FakeBooks(),
          templates: _FakeCatalog(),
        ),
      ),
    );
    await tester.enterText(
        find.byKey(const ValueKey('isbn-input')), '9783522202602');
    await tester.tap(find.text('Buch suchen'));
    await tester.pumpAndSettle();
    expect(find.text('Die unendliche Geschichte'), findsOneWidget);
    await tester.tap(find.text('Die unendliche Geschichte'));
    await tester.pumpAndSettle();
    expect(find.text('Buchinformationen prüfen'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.textContaining('Nur Vorschau:'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.ensureVisible(find.textContaining('Nur Vorschau:'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Nur Vorschau:'), findsOneWidget);
    expect(find.text('Gegenstand speichern'), findsNothing);
  });
}
