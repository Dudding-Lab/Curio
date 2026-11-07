import 'package:curio/features/capture/standard_item_capture_repository.dart';
import 'package:curio/screens/capture/standard_capture_screen.dart';
import 'package:go_router/go_router.dart';
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

class _FakeSave implements StandardItemCaptureRepository {
  int calls = 0;
  String? savedTitle;
  Map<String, dynamic>? savedAttributes;

  @override
  Future<List<StandardObjectTemplate>> listStandards() =>
      _FakeCatalog().listStandards();

  @override
  Future<String> create({
    required String standardCode,
    required String title,
    required String description,
    required Map<String, dynamic> attributes,
  }) async {
    calls++;
    savedTitle = title;
    savedAttributes = attributes;
    return 'saved-book';
  }
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

  testWidgets('ISBN search presents real source data for review before save',
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
    expect(find.text('Buchdaten übernehmen'), findsOneWidget);
  });
  testWidgets('ISBN result pre-fills editable capture and saves only after confirmation',
      (tester) async {
    final save = _FakeSave();
    final router = GoRouter(
      initialLocation: '/capture/isbn',
      routes: [
        GoRoute(path: '/capture/isbn',
            builder: (_, __) => IsbnLookupScreen(
              repository: _FakeBooks(), templates: _FakeCatalog())),
        GoRoute(path: '/capture/standard', builder: (_, state) =>
            StandardCaptureScreen(
              repository: save,
              initialBook: state.extra as GoogleBookCandidate?,
              enableSave: true,
            )),
        GoRoute(path: '/items', builder: (_, __) =>
            const Scaffold(body: Text('Saved item list'))),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(MaterialApp.router(
      locale: const Locale('de'),
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      routerConfig: router,
    ));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('isbn-input')),
        '9783522202602');
    await tester.tap(find.text('Buch suchen'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Die unendliche Geschichte'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const ValueKey('isbn-use-book')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('isbn-use-book')));
    await tester.pumpAndSettle();
    expect(save.calls, 0);
    expect(find.byKey(const ValueKey('standard-title')), findsOneWidget);
    expect(tester.widget<TextField>(
      find.byKey(const ValueKey('standard-title'))).controller!.text,
      'Die unendliche Geschichte');
    expect(tester.widget<TextField>(
      find.byKey(const ValueKey('field-isbn'))).controller!.text,
      '9783522202602');

    await tester.enterText(find.byKey(const ValueKey('standard-title')),
        'Mein geprüftes Buch');
    await tester.ensureVisible(find.text('Angaben prüfen'));
    await tester.pumpAndSettle();
    await tester.drag(find.byType(ListView), const Offset(0, -200));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Angaben prüfen'));
    await tester.pumpAndSettle();
    expect(save.calls, 0);
    await tester.ensureVisible(find.text('Gegenstand speichern'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Gegenstand speichern'));
    await tester.pumpAndSettle();
    expect(save.calls, 1);
    expect(save.savedTitle, 'Mein geprüftes Buch');
    expect(save.savedAttributes?['isbn'], '9783522202602');
    expect(save.savedAttributes?['author'], 'Michael Ende');
    expect(save.savedAttributes?['publication_year'], 1979);
    expect(find.text('Saved item list'), findsOneWidget);
  });

}
