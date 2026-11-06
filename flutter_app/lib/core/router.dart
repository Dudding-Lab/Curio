import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:curio/screens/auth/login_screen.dart';
import 'package:curio/screens/home/home_screen.dart';
import 'package:curio/screens/items/personal_items_screen.dart';
import 'package:curio/screens/taxonomy/personal_object_types_screen.dart';
import 'package:curio/screens/taxonomy/standard_templates_screen.dart';
import 'package:curio/screens/collections/personal_collections_screen.dart';
import 'package:curio/screens/capture/manual_capture_screen.dart';
import 'package:curio/screens/households/household_list_screen.dart';
import 'package:curio/screens/collections/collections_list_screen.dart';

final supabase = Supabase.instance.client;

final authStateProvider = StreamProvider<AuthState>((ref) {
  return supabase.auth.onAuthStateChange;
});

final routerProvider = Provider<GoRouter>((ref) {
  final authState = ref.watch(authStateProvider);

  return GoRouter(
    initialLocation: '/login',
    redirect: (context, state) {
      final isLoggedIn = authState.value?.session != null;
      final isLoginRoute = state.matchedLocation == '/login';

      if (!isLoggedIn && !isLoginRoute) return '/login';
      if (isLoggedIn && isLoginRoute) return '/home';
      return null;
    },
    routes: [
      GoRoute(
        path: '/login',
        builder: (context, state) => const LoginScreen(),
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
        path: '/object-types',
        builder: (context, state) => const PersonalObjectTypesScreen(),
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
