import 'package:flutter/material.dart';
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
import 'account_gate.dart';
import 'shell_navigation.dart';
import '../l10n/l10n.dart';

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

      final user = authState.value;
      final authRedirect = resolveAuthRedirect(
        path: currentPath,
        hasSeenOnboarding: hasSeenOnboarding,
        hasSession: user != null,
        hasAccount: user != null && !user.isAnonymous,
      );
      if (authRedirect != null) return authRedirect;

      // Guests cannot be in groups, so there is no active session to resume.
      if (user == null || user.isAnonymous) return null;

      final List<GroupModel> groupsSnapshot =
          ref.read(userGroupsProvider).value ??
              await ref.read(userGroupsProvider.future);
      final activeGroup = _pickActiveSessionGroup(groupsSnapshot);
      if (activeGroup != null) {
        if (!isActiveSessionRouteAllowed(currentPath)) {
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
      // Auth screens sit outside the shell so logged-out users never see the
      // bottom navigation.
      GoRoute(
        path: '/login',
        builder: (ctx, state) => const LoginScreen(),
      ),
      GoRoute(
        path: '/register',
        builder: (ctx, state) => const RegisterScreen(),
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
            path: '/swipe/:groupId',
            builder: (ctx, state) => AccountGate(
              reason: GateReason.groupSwipe,
              icon: Icons.group,
              child: SwipeScreen(groupId: state.pathParameters['groupId']!),
            ),
          ),
          GoRoute(
            path: '/group',
            builder: (ctx, state) => const AccountGate(
              reason: GateReason.groups,
              icon: Icons.group,
              child: SimplifiedGroupScreen(),
            ),
          ),
          GoRoute(
            path: '/group/join',
            builder: (ctx, state) {
              final groupId = state.uri.queryParameters['groupId'] ?? '';
              final code = state.uri.queryParameters['code'] ?? '';
              return AccountGate(
                reason: GateReason.joinGroup,
                icon: Icons.group_add,
                child: GroupJoinScreen(groupId: groupId, code: code),
              );
            },
          ),
          GoRoute(
            path: '/group-matches/:groupId',
            builder: (ctx, state) => AccountGate(
              reason: GateReason.groupMatches,
              icon: Icons.group,
              child: GroupMatchesScreen(
                  groupId: state.pathParameters['groupId']!),
            ),
          ),
          GoRoute(
            path: '/profile',
            builder: (ctx, state) => AccountGate(
              reason: GateReason.profile,
              icon: Icons.person,
              // Guests still need a way into the app settings (language).
              guestActions: [
                IconButton(
                  icon: const Icon(Icons.settings),
                  tooltip: ctx.l10n.settingsTitle,
                  onPressed: () => ctx.push('/settings'),
                ),
              ],
              child: const SimplifiedProfileScreen(),
            ),
          ),
          GoRoute(
            path: '/settings',
            // Open to guests: language and other app settings must be
            // reachable without an account. Account-only parts hide inside.
            builder: (ctx, state) => const SettingsScreen(),
          ),
          GoRoute(
            path: '/favorites',
            builder: (ctx, state) => const AccountGate(
              reason: GateReason.favorites,
              icon: Icons.favorite,
              child: FavoritesScreen(),
            ),
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

/// Onboarding is handled before this. [hasSession] is any Firebase session,
/// guest included; [hasAccount] is a real (non-anonymous) account.
/// Returns the path to redirect to, or null to stay.
String? resolveAuthRedirect({
  required String path,
  required bool hasSeenOnboarding,
  required bool hasSession,
  required bool hasAccount,
}) {
  if (!hasSeenOnboarding) return null;
  final isGoingToAuth = path == '/login' || path == '/register';

  // No session at all means guest sign-in failed (e.g. Anonymous Auth is
  // disabled), so fall back to requiring a login like before guest mode.
  if (!hasSession) return isGoingToAuth ? null : '/login';

  // Guests may open login/register to upgrade; real accounts never need to.
  if (hasAccount && isGoingToAuth) return '/home';
  if (path == '/') return '/home';
  return null;
}

GroupModel? _pickActiveSessionGroup(List<GroupModel> groups) {
  for (final group in groups) {
    if (group.activeSessionId != null) return group;
  }
  return null;
}

bool isActiveSessionRouteAllowed(String currentPath) {
  return currentPath.startsWith('/swipe') ||
      currentPath.startsWith('/group-matches') ||
      currentPath == '/group' ||
      currentPath.startsWith('/group/') ||
      currentPath == '/profile' ||
      currentPath == '/settings' ||
      currentPath == '/favorites';
}
