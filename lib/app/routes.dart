import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../features/onboarding/ui/onboarding_screen.dart';
import '../features/auth/ui/login_screen.dart';
import '../features/auth/ui/register_screen.dart';
import '../features/home/ui/collection_screen.dart';
import '../features/home/ui/discover_screen.dart';
import '../features/home/ui/home_screen.dart';
import '../features/home/ui/favorites_map_screen.dart';
import '../features/auth/ui/forgot_password_screen.dart';
import '../features/home/ui/favorites_screen.dart';
import '../features/swipe/ui/swipe_screen.dart';
import '../features/places/ui/place_detail_screen.dart';
import '../features/group/ui/costs_screen.dart';
import '../features/group/ui/day_map_screen.dart';
import '../features/group/ui/group_join_screen.dart';
import '../features/group/ui/journal_screen.dart';
import '../features/group/ui/recap_screen.dart';
import '../features/group/ui/trip_detail_screen.dart';
import '../features/group/ui/trips_screen.dart';
import '../features/group/ui/group_matches_screen.dart';
import '../features/group/ui/day_plan_screen.dart';
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
      GoRoute(
        path: '/forgot-password',
        builder: (ctx, state) => ForgotPasswordScreen(
          initialEmail: state.uri.queryParameters['email'],
          fromSettings: state.uri.queryParameters['from'] == 'settings',
        ),
      ),
      // Full-screen, outside the shell: the photo uses the whole screen and
      // the bottom bar is the page's own action bar.
      GoRoute(
        path: '/favorites-map',
        builder: (ctx, state) => const AccountGate(
          reason: GateReason.favorites,
          icon: Icons.map_outlined,
          child: FavoritesMapScreen(),
        ),
      ),
      // The solo swipe deck, full screen with a back button; opened from
      // the home feed's hero ticket.
      GoRoute(
        path: '/discover',
        builder: (ctx, state) => const DiscoverScreen(),
      ),
      GoRoute(
        path: '/place/:id',
        builder: (ctx, state) => const PlaceDetailScreen(),
      ),
      // A trip (group): full screen, the photo header and the floating
      // primary button replace the bottom navigation.
      GoRoute(
        path: '/trip/:groupId',
        builder: (ctx, state) => AccountGate(
          reason: GateReason.groups,
          icon: Icons.luggage_rounded,
          child: TripDetailScreen(groupId: state.pathParameters['groupId']!),
        ),
        routes: [
          GoRoute(
            path: 'day/:index',
            builder: (ctx, state) => AccountGate(
              reason: GateReason.groups,
              icon: Icons.map_outlined,
              child: DayMapScreen(
                groupId: state.pathParameters['groupId']!,
                day: int.tryParse(state.pathParameters['index'] ?? '') ?? 0,
              ),
            ),
          ),
          GoRoute(
            path: 'costs',
            builder: (ctx, state) => AccountGate(
              reason: GateReason.groups,
              icon: Icons.receipt_long_rounded,
              child: CostsScreen(groupId: state.pathParameters['groupId']!),
            ),
          ),
          GoRoute(
            path: 'journal',
            builder: (ctx, state) => AccountGate(
              reason: GateReason.groups,
              icon: Icons.photo_library_outlined,
              child: JournalScreen(groupId: state.pathParameters['groupId']!),
            ),
          ),
          GoRoute(
            path: 'recap',
            builder: (ctx, state) => AccountGate(
              reason: GateReason.groups,
              icon: Icons.auto_stories_outlined,
              child: RecapScreen(groupId: state.pathParameters['groupId']!),
            ),
          ),
        ],
      ),
      // All main routes wrapped in ShellRoute for persistent bottom nav
      ShellRoute(
        builder: (context, state, child) => ShellNavigation(child: child),
        routes: [
          GoRoute(
            path: '/',
            builder: (ctx, state) => const HomeScreen(),
          ),
          GoRoute(
            path: '/home',
            builder: (ctx, state) => const HomeScreen(),
          ),
          // "All" of a home row: must-sees | tonight | hidden-gems.
          GoRoute(
            path: '/collection/:theme',
            builder: (ctx, state) =>
                CollectionScreen(theme: state.pathParameters['theme']!),
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
            path: '/trips',
            builder: (ctx, state) => AccountGate(
              reason: GateReason.groups,
              icon: Icons.luggage_rounded,
              child: TripsScreen(
                openCreate: state.uri.queryParameters['create'] == '1',
              ),
            ),
          ),
          // Old groups tab; groups are trips now.
          GoRoute(
            path: '/group',
            redirect: (ctx, state) => '/trips',
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
            path: '/day-plan/:groupId/:sessionId',
            builder: (ctx, state) => AccountGate(
              reason: GateReason.groupMatches,
              icon: Icons.route,
              child: DayPlanScreen(
                groupId: state.pathParameters['groupId']!,
                sessionId: state.pathParameters['sessionId']!,
              ),
            ),
          ),
          GoRoute(
            path: '/group-matches/:groupId',
            builder: (ctx, state) => AccountGate(
              reason: GateReason.groupMatches,
              icon: Icons.group,
              child: GroupMatchesScreen(
                groupId: state.pathParameters['groupId']!,
                // Set when arriving straight from a session that just ended.
                celebrate: state.uri.queryParameters['celebrate'] == '1',
              ),
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
  // Also opened from settings by signed-in users, so never redirected away.
  if (path == '/forgot-password') return null;

  // No session at all means guest sign-in failed (e.g. Anonymous Auth is
  // disabled), so fall back to requiring a login like before guest mode.
  if (!hasSession) return isGoingToAuth ? null : '/login';

  // Guests may open login/register to upgrade; real accounts never need to.
  // Accounts start on their trips, guests (who cannot have trips) on the
  // discover feed.
  if (hasAccount && isGoingToAuth) return '/trips';
  if (path == '/') return hasAccount ? '/trips' : '/home';
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
      // Details of a card being voted on.
      currentPath.startsWith('/place/') ||
      currentPath.startsWith('/group-matches') ||
      currentPath.startsWith('/day-plan') ||
      currentPath == '/group' ||
      currentPath.startsWith('/group/') ||
      currentPath == '/trips' ||
      currentPath.startsWith('/trip/') ||
      currentPath == '/profile' ||
      currentPath == '/settings' ||
      currentPath == '/favorites';
}
