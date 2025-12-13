import 'package:go_router/go_router.dart';
import '../features/onboarding/ui/onboarding_screen.dart';
import '../features/auth/ui/login_screen.dart';
import '../features/auth/ui/register_screen.dart';
import '../features/home/ui/home_screen.dart';
import '../features/swipe/ui/swipe_screen.dart';
import '../features/places/ui/place_detail_screen.dart';
import '../features/group/ui/group_screen.dart';
import '../features/group/ui/group_matches_screen.dart';
import '../features/profile/ui/profile_screen.dart';

GoRouter createRouter() {
  return GoRouter(
    routes: [
      GoRoute(
        path: '/',
        builder: (ctx, state) => OnboardingScreen(),
      ),
      GoRoute(
        path: '/login',
        builder: (ctx, state) => LoginScreen(),
      ),
      GoRoute(
        path: '/register',
        builder: (ctx, state) => RegisterScreen(),
      ),
      GoRoute(
        path: '/home',
        builder: (ctx, state) => HomeScreen(),
      ),
      GoRoute(
        path: '/swipe',
        builder: (ctx, state) => SwipeScreen(),
      ),
      GoRoute(
        path: '/place/:id',
        builder: (ctx, state) => PlaceDetailScreen(),
      ),
      GoRoute(
        path: '/group',
        builder: (ctx, state) => GroupScreen(),
      ),
      GoRoute(
        path: '/group-matches',
        builder: (ctx, state) => GroupMatchesScreen(),
      ),
      GoRoute(
        path: '/profile',
        builder: (ctx, state) => ProfileScreen(),
      ),
    ],
  );
}
