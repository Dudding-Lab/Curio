import 'package:curio/core/adaptive_navigation.dart';
import 'package:curio/core/design_tokens.dart';
import 'package:curio/core/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('viewport classes are deterministic at boundaries', () {
    expect(KovunelaBreakpoints.isCompact(599), isTrue);
    expect(KovunelaBreakpoints.isCompact(600), isFalse);
    expect(KovunelaBreakpoints.isExpanded(1023), isFalse);
    expect(KovunelaBreakpoints.isExpanded(1024), isTrue);
  });

  test('light and dark themes use Material 3', () {
    expect(AppTheme.light.useMaterial3, isTrue);
    expect(AppTheme.dark.useMaterial3, isTrue);
    expect(AppTheme.light.brightness, Brightness.light);
    expect(AppTheme.dark.brightness, Brightness.dark);
    expect(AppTheme.light.colorScheme.primary, KovunelaColors.primary);
  });

  Future<void> pumpNavigation(WidgetTester tester, double width) async {
    tester.view.physicalSize = Size(width, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: KovunelaAdaptiveScaffold(
          title: 'Kovunela',
          body: const Center(child: Text('Empty state')),
          selectedIndex: 0,
          onDestinationSelected: (_) {},
        ),
      ),
    );
  }

  testWidgets('phone uses bottom navigation', (tester) async {
    await pumpNavigation(tester, 390);
    expect(find.byType(NavigationBar), findsOneWidget);
    expect(find.byType(NavigationRail), findsNothing);
    expect(find.text('Empty state'), findsOneWidget);
  });

  testWidgets('wide web viewport uses a navigation rail', (tester) async {
    await pumpNavigation(tester, 1200);
    expect(find.byType(NavigationRail), findsOneWidget);
    expect(find.byType(NavigationBar), findsNothing);
    expect(find.text('Empty state'), findsOneWidget);
  });
}
