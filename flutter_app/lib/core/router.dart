import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:curio/screens/auth/login_screen.dart';
import 'package:curio/screens/auth/offline_unlock_screen.dart';
import 'package:curio/screens/home/home_screen.dart';
import 'package:curio/screens/items/personal_items_screen.dart';
import 'package:curio/screens/taxonomy/personal_object_types_screen.dart';
import 'package:curio/screens/taxonomy/standard_templates_screen.dart';
import 'package:curio/screens/taxonomy/template_draft_screen.dart';
import 'package:curio/screens/collections/personal_collections_screen.dart';
import 'package:curio/screens/capture/manual_capture_screen.dart';
import 'package:curio/screens/capture/isbn_lookup_screen.dart';
import 'package:curio/screens/capture/photo_capture_screen.dart';
import 'package:curio/screens/capture/capture_suggestion_demo_screen.dart';
import 'package:curio/screens/households/household_list_screen.dart';
import 'package:curio/screens/collections/collections_list_screen.dart';

final supabase = Supabase.instance.client;

final authStateProvider = StreamProvider<AuthState>((ref) {
  return supabase.auth.onAuthStateChange.handleError((Object error, StackTrace stack) {
    // A disconnected refresh is not a sign-out. Keep the restored session
    // identity available for the strictly local unlock screen.
  });
});

final routerProvider = Provider<GoRouter>((ref) {
  ref.watch(authStateProvider);

  return GoRouter(
    initialLocation: '/login',
    redirect: (context, state) {
      final session = supabase.auth.currentSession;
      final isLoginRoute = state.matchedLocation == '/login';
      final isOfflineRoute = state.matchedLocation == '/offline';
      if (session == null) return isLoginRoute ? null : '/login';
      if (session.isExpired) {
        // Never expose online-only screens behind an expired JWT.
        return isOfflineRoute || isLoginRoute ? null : '/offline';
      }
      if (isLoginRoute || isOfflineRoute) return '/home';
      return null;
    },
    routes: [
      GoRoute(
        path: '/login',
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: '/offline',
        builder: (context, state) => const OfflineUnlockScreen(),
      ),
      GoRoute(
        path: '/home',
        builder: (context, state) => const HomeScreen(),
      ),
      GoRoute(
        path: '/items',
        builder: (context, state) => const PersonalItemsScreen(),
      ),
      GoRoute(
        path: '/collections/personal',
        builder: (context, state) => const PersonalCollectionsScreen(),
      ),
      GoRoute(
        path: '/templates/standard',
        builder: (context, state) => const StandardTemplatesScreen(),
      ),
      GoRoute(
        path: '/templates/standard/:code/draft',
        builder: (context, state) => TemplateDraftScreen(
          standardCode: state.pathParameters['code']!,
        ),
      ),
      GoRoute(
        path: '/object-types',
        builder: (context, state) => const PersonalObjectTypesScreen(),
      ),
      GoRoute(
        path: '/capture/suggestion-demo',
        builder: (context, state) => const CaptureSuggestionDemoScreen(),
      ),
      GoRoute(
        path: '/capture/photo',
        builder: (context, state) => const PhotoCaptureScreen(),
      ),
      GoRoute(
        path: '/capture/isbn',
        builder: (context, state) => const IsbnLookupScreen(),
      ),
      GoRoute(
        path: '/capture/manual',
        builder: (context, state) => const ManualCaptureScreen(),
      ),
      GoRoute(
        path: '/households',
        builder: (context, state) => const HouseholdListScreen(),
        routes: [
          GoRoute(
            path: ':householdId/collections',
            builder: (context, state) {
              final householdId = state.pathParameters['householdId']!;
              final householdName = state.uri.queryParameters['name'];
              return CollectionsListScreen(
                householdId: householdId,
                householdName: householdName,
              );
            },
          ),
        ],
      ),
    ],
  );
});
