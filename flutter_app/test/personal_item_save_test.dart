import 'dart:async';

import 'package:curio/features/capture/manual_item_draft.dart';
import 'package:curio/features/capture/personal_item_repository.dart';
import 'package:curio/l10n/app_localizations.dart';
import 'package:curio/screens/capture/manual_capture_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

class _FakeItemRepository implements PersonalItemRepository {
  final Completer<String> completion = Completer<String>();
  final List<ManualItemDraft> requests = [];

  @override
  Future<String> create(ManualItemDraft draft) {
    requests.add(draft);
    return completion.future;
  }

  @override
  Future<List<PersonalItem>> list() async => [];
}

void main() {
  Future<GoRouter> pumpCapture(
    WidgetTester tester,
    PersonalItemRepository repository,
  ) async {
    final router = GoRouter(
      initialLocation: '/capture/manual',
      routes: [
        GoRoute(
          path: '/capture/manual',
          builder: (context, state) => ManualCaptureScreen(
            repository: repository,
            enableSave: true,
          ),
        ),
        GoRoute(
          path: '/items',
          builder: (context, state) =>
              const Scaffold(body: Text('Saved items route')),
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      MaterialApp.router(
        locale: const Locale('de'),
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        routerConfig: router,
      ),
    );
    await tester.pumpAndSettle();
    return router;
  }

  testWidgets('server response is required before navigating to inventory',
      (tester) async {
    final repository = _FakeItemRepository();
    await pumpCapture(tester, repository);

    await tester.enterText(find.byType(TextFormField).first, 'Meine Kamera');
    await tester.tap(find.text('Angaben prüfen'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Gegenstand speichern'));
    await tester.pump();
    expect(repository.requests, hasLength(1));
    expect(repository.requests.single.title, 'Meine Kamera');
    expect(find.text('Saved items route'), findsNothing);
    expect(find.text('Gegenstand wird gespeichert …'), findsOneWidget);
    expect(
      tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'Gegenstand wird gespeichert …'),
      ).onPressed,
      isNull,
    );

    repository.completion.complete('confirmed-item-id');
    await tester.pumpAndSettle();
    expect(find.text('Saved items route'), findsOneWidget);
  });

  testWidgets('save failure keeps the draft editable', (tester) async {
    final repository = _FakeItemRepository();
    await pumpCapture(tester, repository);
    await tester.enterText(find.byType(TextFormField).first, 'Uhr');
    await tester.tap(find.text('Angaben prüfen'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Gegenstand speichern'));
    await tester.pump();
    repository.completion.completeError(StateError('Network unavailable'));
    await tester.pumpAndSettle();

    expect(find.text('Der Gegenstand konnte nicht gespeichert werden. Deine Eingaben bleiben erhalten.'),
        findsOneWidget);
    expect(find.text('Uhr'), findsOneWidget);

    await tester.tap(find.text('Angaben bearbeiten'));
    await tester.pumpAndSettle();
    expect(find.text('Uhr'), findsOneWidget);
    expect(find.byType(TextFormField), findsNWidgets(2));
  });
}
