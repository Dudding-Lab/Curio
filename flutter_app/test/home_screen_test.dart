import 'package:curio/core/theme.dart';
import 'package:curio/l10n/app_localizations.dart';
import 'package:curio/screens/home/home_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

void main() {
  testWidgets('home presents localized capture actions without fake scanning',
      (tester) async {
    final router = GoRouter(
      initialLocation: '/home',
      routes: [
        GoRoute(
          path: '/home',
          builder: (context, state) => const HomeScreen(),
        ),
        GoRoute(
          path: '/households',
          builder: (context, state) => const Scaffold(body: Text('Households')),
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp.router(
        locale: const Locale('de'),
        theme: AppTheme.light,
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        routerConfig: router,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Willkommen bei Kovunela'), findsOneWidget);
    expect(find.text('Foto aufnehmen'), findsOneWidget);
    await tester.tap(find.text('Foto aufnehmen'));
    await tester.pump();
    expect(
      find.text('Die Objekterfassung ist noch in Vorbereitung.'),
      findsOneWidget,
    );

    await tester.tap(find.text('Haushalte verwalten'));
    await tester.pumpAndSettle();
    expect(find.text('Households'), findsOneWidget);
  });
}
