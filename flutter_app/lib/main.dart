import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:curio/core/router.dart';
import 'package:curio/features/offline/secure_session_storage.dart';
import 'package:curio/features/offline/offline_access_controller.dart';
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
    authOptions: FlutterAuthClientOptions(
      localStorage: SecureSupabaseSessionStorage(),
      persistSession: true,
      autoRefreshToken: true,
    ),
  );

  // Explicit sign-out removes offline enrollment as well. Network refresh
  // failures must not be mistaken for a user-requested sign-out.
  Supabase.instance.client.auth.onAuthStateChange.listen(
    (event) async {
      if (event.event == AuthChangeEvent.signedOut) {
        try {
          await SecureKnownDeviceStore().clear();
        } catch (_) {
          // The absence of storage does not grant access; unlock fails closed.
        }
      }
    },
    onError: (Object error, StackTrace stack) {
      // Offline refresh errors are expected and must not crash the app.
    },
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
