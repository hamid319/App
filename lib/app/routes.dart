import 'package:flutter/foundation.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../features/onboarding/ui/onboarding_screen.dart';
import '../features/auth/ui/login_screen.dart';
import '../features/auth/ui/register_screen.dart';
import '../features/home/ui/simplified_home_screen.dart';
import '../features/home/ui/favorites_screen.dart';
import '../features/swipe/ui/swipe_screen.dart';
import '../features/places/ui/place_detail_screen.dart';
import '../features/group/ui/simplified_group_screen.dart';
import '../features/group/ui/group_matches_screen.dart';
import '../features/profile/ui/simplified_profile_screen.dart';
import '../features/profile/ui/settings_screen.dart';
import '../core/services/preferences_service.dart';
import '../features/group/logic/group_controller.dart';
import '../common/models/group_model.dart';
import '../features/auth/logic/auth_controller.dart';
import 'shell_navigation.dart';

final routerProvider = Provider<GoRouter>((ref) => createRouter(ref));

GoRouter createRouter(Ref ref) {
  final refreshNotifier = ValueNotifier<int>(0);
  ref.listen(userGroupsProvider, (_, __) => refreshNotifier.value++);
  ref.listen(authControllerProvider, (_, __) => refreshNotifier.value++);

  return GoRouter(
    initialLocation: '/',
    refreshListenable: refreshNotifier,
    redirect: (context, state) async {
      final currentPath = state.matchedLocation;
      final hasSeenOnboarding = await PreferencesService.hasSeenOnboarding();

      // First time users see onboarding
      if (!hasSeenOnboarding && currentPath != '/onboarding') {
        return '/onboarding';
      }

      final authState = ref.read(authControllerProvider);
      // Wait for auth to initialize if loading
      if (authState.isLoading) return null;
      
      final isLoggedIn = authState.value != null;
      final isGoingToAuth = currentPath == '/login' || currentPath == '/register';

      if (hasSeenOnboarding) {
        if (!isLoggedIn && !isGoingToAuth) {
          return '/login';
        }
        if (isLoggedIn && isGoingToAuth) {
          return '/home';
        }
        if (isLoggedIn && currentPath == '/') {
          return '/home';
        }
      }
      
      if (!isLoggedIn) return null;

      final List<GroupModel> groupsSnapshot = ref.read(userGroupsProvider).value ??
          await ref.read(userGroupsProvider.future);
      final activeGroup = _pickActiveSessionGroup(groupsSnapshot);
      if (activeGroup != null) {
        final onSwipe = currentPath.startsWith('/swipe');
        final onMatches = currentPath.startsWith('/group-matches');
        if (!onSwipe && !onMatches) {
          return '/swipe/${activeGroup.groupId}';
        }
      }

      return null;
    },
    routes: [
      GoRoute(
        path: '/onboarding',
        builder: (ctx, state) => const OnboardingScreen(),
      ),
      // All main routes wrapped in ShellRoute for persistent bottom nav
      ShellRoute(
        builder: (context, state, child) => ShellNavigation(child: child),
        routes: [
          GoRoute(
            path: '/',
            builder: (ctx, state) => const SimplifiedHomeScreen(),
          ),
          GoRoute(
            path: '/home',
            builder: (ctx, state) => const SimplifiedHomeScreen(),
          ),
          GoRoute(
            path: '/login',
            builder: (ctx, state) => const LoginScreen(),
          ),
          GoRoute(
            path: '/register',
            builder: (ctx, state) => const RegisterScreen(),
          ),
          GoRoute(
            path: '/swipe/:groupId',
            builder: (ctx, state) =>
                SwipeScreen(groupId: state.pathParameters['groupId']!),
          ),
          GoRoute(
            path: '/group',
            builder: (ctx, state) => const SimplifiedGroupScreen(),
          ),
          GoRoute(
            path: '/group/join',
            builder: (ctx, state) {
              final groupId = state.uri.queryParameters['groupId'] ?? '';
              final code = state.uri.queryParameters['code'] ?? '';
              return GroupJoinScreen(groupId: groupId, code: code);
            },
          ),
          GoRoute(
            path: '/group-matches/:groupId',
            builder: (ctx, state) =>
                GroupMatchesScreen(groupId: state.pathParameters['groupId']!),
          ),
          GoRoute(
            path: '/profile',
            builder: (ctx, state) => const SimplifiedProfileScreen(),
          ),
          GoRoute(
            path: '/settings',
            builder: (ctx, state) => const SettingsScreen(),
          ),
          GoRoute(
            path: '/favorites',
            builder: (ctx, state) => const FavoritesScreen(),
          ),
          GoRoute(
            path: '/place/:id',
            builder: (ctx, state) => const PlaceDetailScreen(),
          ),
        ],
      ),
    ],
  );
}

GroupModel? _pickActiveSessionGroup(List<GroupModel> groups) {
  for (final group in groups) {
    if (group.activeSessionId != null) return group;
  }
  return null;
}

