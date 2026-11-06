import 'package:curio/features/capture/capture_suggestion.dart';
import 'package:curio/features/taxonomy/template_catalog_repository.dart';
import 'package:curio/l10n/app_localizations.dart';
import 'package:curio/screens/capture/capture_suggestion_demo_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

const _book = StandardObjectTemplate(
  id: 'book-id',
  code: 'book',
  title: 'Buch',
  categoryCode: 'books',
  version: 1,
  fields: {'author': 'text', 'isbn': 'text', 'edition': 'text', 'pages': 'number'},
);
const _camera = StandardObjectTemplate(
  id: 'camera-id',
  code: 'camera',
  title: 'Kamera',
  categoryCode: 'technology',
  version: 1,
  fields: {'manufacturer': 'text', 'model': 'text'},
);

class _FakeCatalog implements TemplateCatalogRepository {
  @override
  Future<List<StandardObjectTemplate>> listStandards() async =>
      [_book, _camera];
  @override
  Future<String> deriveStandard({
    required String standardId,
    String? title,
    Map<String, String> addedFields = const {},
  }) => throw UnimplementedError();
  @override
  Future<List<SharedObjectTemplate>> listSharedForWorkspace(String id) =>
      throw UnimplementedError();
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
  Future<void> sharePersonalTemplate({
    required String templateId,
    required String householdWorkspaceId,
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
  test('untrusted suggestion rejects unbounded and invalid payloads', () {
    expect(
      () => CaptureSuggestion.fromJson({
        'title': 'Book',
        'template_code': 'book',
        'attributes': <String, dynamic>{},
        'confidence': 1.5,
      }),
      throwsFormatException,
    );
    expect(
      () => CaptureSuggestion.fromJson({
        'title': 'Book',
        'template_code': 'book',
        'attributes': List<int>.filled(1, 1),
      }),
      throwsFormatException,
    );
  });

  test('ranking is deterministic and only considers matching field keys', () {
    final matches = CaptureSuggestionMatcher.rank(
      {'author': 'Example', 'isbn': '123', 'mystery': 'x'},
      [_camera, _book],
    );
    expect(matches, hasLength(1));
    expect(matches.first.template.code, 'book');
    expect(matches.first.matches, 2);
  });

  test('review discards unknown, empty and invalid AI fields', () {
    final suggestion = CaptureSuggestion(
      templateCode: 'book',
      title: 'The story',
      attributes: {
        'author': 'Example',
        'isbn': '012345',
        'pages': 'incorrect',
        'invented_field': 'danger',
      },
    );
    final review = CaptureReview(
      template: _book,
      proposal: suggestion,
      requiredFields: {'author', 'edition'},
    );
    expect(review.accepted.keys, containsAll(['author', 'isbn']));
    expect(review.draft.values, isNot(contains('invented_field')));
    expect(review.rejectedReasons['invented_field'], 'unknown_field');
    expect(review.rejectedReasons['pages'], 'type_or_choice_mismatch');
    expect(review.missingRequiredFields, ['edition']);
    expect(() => review.validatedAttributes(), throwsFormatException);
    review.draft.values['edition'] = 'First';
    expect(review.validatedAttributes(), {
      'author': 'Example',
      'isbn': '012345',
      'edition': 'First',
    });
  });

  test('review refuses template substitutions and out-of-list values', () {
    const suggestion = CaptureSuggestion(
      templateCode: 'book',
      title: 'Example',
      attributes: {'edition': 'Unlisted'},
    );
    expect(
      () => CaptureReview(template: _camera, proposal: suggestion),
      throwsFormatException,
    );
    final review = CaptureReview(
      template: _book,
      proposal: suggestion,
      choices: {
        'edition': ['First', 'Second'],
      },
    );
    expect(review.rejectedReasons['edition'], 'type_or_choice_mismatch');
    expect(review.accepted, isEmpty);
  });

  testWidgets('demo labels simulated results, allows review, never saves',
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
        home: CaptureSuggestionDemoScreen(repository: _FakeCatalog()),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('Demo mit simulierten Angaben'), findsOneWidget);
    expect(find.text('Buchvorschlag prüfen'), findsOneWidget);
    await tester.tap(find.text('Buchvorschlag prüfen'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Pflichtangaben fehlen:'), findsOneWidget);
    expect(find.byKey(const ValueKey('suggestion-author')), findsOneWidget);
    expect(find.textContaining('ungeprüfte Felder verworfen'), findsOneWidget);
    expect(find.text('Gegenstand speichern'), findsNothing);
  });
}
