import 'package:go_router/go_router.dart';
import '../features/onboarding/ui/onboarding_screen.dart';
import '../features/auth/ui/login_screen.dart';
import '../features/auth/ui/register_screen.dart';
import '../features/home/ui/simplified_home_screen.dart';
import '../features/swipe/ui/swipe_screen.dart';
import '../features/places/ui/place_detail_screen.dart';
import '../features/group/ui/simplified_group_screen.dart';
import '../features/group/ui/group_matches_screen.dart';
import '../features/profile/ui/simplified_profile_screen.dart';
import '../core/services/preferences_service.dart';
import 'shell_navigation.dart';

GoRouter createRouter() {
  return GoRouter(
    initialLocation: '/',
    redirect: (context, state) async {
      final currentPath = state.matchedLocation;
      final hasSeenOnboarding = await PreferencesService.hasSeenOnboarding();
      
      // First time users see onboarding
      if (!hasSeenOnboarding && currentPath != '/onboarding') {
        return '/onboarding';
      }
      
      // After onboarding, redirect root to home
      if (hasSeenOnboarding && currentPath == '/') {
        return '/home';
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
            path: '/swipe',
            builder: (ctx, state) => const SwipeScreen(),
          ),
          GoRoute(
            path: '/group',
            builder: (ctx, state) => const SimplifiedGroupScreen(),
          ),
          GoRoute(
            path: '/group-matches',
            builder: (ctx, state) => const GroupMatchesScreen(),
          ),
          GoRoute(
            path: '/profile',
            builder: (ctx, state) => const SimplifiedProfileScreen(),
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
