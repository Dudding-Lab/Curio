import 'package:curio/features/capture/standard_item_capture_repository.dart';
import 'package:curio/features/taxonomy/template_catalog_repository.dart';
import 'package:curio/screens/capture/standard_capture_screen.dart';
import 'package:curio/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

class _CaptureRepo implements StandardItemCaptureRepository {
  int calls = 0;
  Map<String, dynamic>? saved;
  @override
  Future<List<StandardObjectTemplate>> listStandards() async => [
    const StandardObjectTemplate(
      id: 'book-standard', code: 'book', title: 'Buch',
      categoryCode: 'books', version: 1,
      fields: {'isbn':'text', 'author':'text', 'publication_year':'number'},
    ),
  ];

  @override
  Future<String> create({
    required String standardCode,
    required String title,
    required String description,
    required Map<String, dynamic> attributes,
  }) async {
    calls++;
    saved = {'standardCode': standardCode, 'title': title, 'attributes': attributes};
    return 'saved-id';
  }
}

void main() {
  testWidgets('book with ISBN saves typed facts exactly once after review', (tester) async {
    final repo = _CaptureRepo();
    final router = GoRouter(initialLocation: '/capture/standard', routes: [
      GoRoute(path: '/capture/standard',
          builder: (_, __) => StandardCaptureScreen(repository: repo, enableSave: true)),
      GoRoute(path: '/items', builder: (_, __) =>
          const Scaffold(body: Text('Private inventory loaded'))),
    ]);
    addTearDown(router.dispose);
    await tester.pumpWidget(MaterialApp.router(
      locale: const Locale('de'),
      localizationsDelegates: const [
        AppLocalizations.delegate, GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate, GlobalWidgetsLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      routerConfig: router,
    ));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('standard-selection')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Buch').last);
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('standard-title')), 'Mein Buch');
    await tester.enterText(find.byKey(const ValueKey('field-isbn')), '9780306406157');
    await tester.ensureVisible(find.text('Angaben prüfen'));
    await tester.tap(find.text('Angaben prüfen'));
    await tester.pumpAndSettle();
    expect(find.text('Gegenstand speichern'), findsOneWidget);
    await tester.tap(find.text('Gegenstand speichern'));
    await tester.pumpAndSettle();
    expect(repo.calls, 1);
    expect(repo.saved?['standardCode'], 'book');
    expect((repo.saved?['attributes'] as Map)['isbn'], '9780306406157');
    expect(find.text('Private inventory loaded'), findsOneWidget);
  });

  testWidgets('invalid ISBN is rejected before saving', (tester) async {
    final repo = _CaptureRepo();
    await tester.pumpWidget(MaterialApp(
      locale: const Locale('de'),
      localizationsDelegates: const [
        AppLocalizations.delegate, GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate, GlobalWidgetsLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      home: StandardCaptureScreen(repository: repo, enableSave: true),
    ));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('standard-selection')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Buch').last);
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('standard-title')), 'Falsche ISBN');
    await tester.enterText(find.byKey(const ValueKey('field-isbn')), '9780306406158');
    await tester.ensureVisible(find.text('Angaben prüfen'));
    await tester.tap(find.text('Angaben prüfen'));
    await tester.pumpAndSettle();
    expect(find.text('Die ISBN hat eine ungültige Prüfziffer.'), findsOneWidget);
    expect(repo.calls, 0);
  });
}
