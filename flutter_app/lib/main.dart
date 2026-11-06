import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:curio/core/router.dart';
import 'package:curio/core/theme.dart';
import 'package:curio/core/locale_controller.dart';
import 'package:curio/l10n/app_localizations.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  const supabaseUrl = String.fromEnvironment('SUPABASE_URL');
  const publishableKey = String.fromEnvironment('SUPABASE_PUBLISHABLE_KEY');
  const legacyAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY');
  final clientKey = publishableKey.isNotEmpty ? publishableKey : legacyAnonKey;

  if (supabaseUrl.isEmpty || clientKey.isEmpty) {
    throw StateError('Missing Supabase URL or publishable key');
  }

  await Supabase.initialize(
    url: supabaseUrl,
    publishableKey: clientKey,
  );

  runApp(const ProviderScope(child: CurioApp()));
}

class CurioApp extends ConsumerWidget {
  const CurioApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    final locale = ref.watch(selectedLocaleProvider);

    return MaterialApp.router(
      locale: locale,
      onGenerateTitle: (context) => AppLocalizations.of(context)!.appTitle,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      routerConfig: router,
      debugShowCheckedModeBanner: false,
    );
  }
}
