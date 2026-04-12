import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
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
import '../core/services/preferences_service.dart';

class AuthNotifier extends ChangeNotifier {
  AuthNotifier() {
    _subscription = FirebaseAuth.instance.authStateChanges().listen((_) {
      notifyListeners();
    });
  }

  late final StreamSubscription<User?> _subscription;

  User? get currentUser => FirebaseAuth.instance.currentUser;
  bool get isLoggedIn => currentUser != null;

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }
}

final _authNotifier = AuthNotifier();

const _publicRoutes = {'/', '/login', '/register'};

GoRouter createRouter() {
  return GoRouter(
    initialLocation: '/',
    refreshListenable: _authNotifier,
    redirect: (context, state) async {
      final hasSeenOnboarding = await PreferencesService.hasSeenOnboarding();
      final isLoggedIn = _authNotifier.isLoggedIn;
      final currentPath = state.matchedLocation;

      if (!hasSeenOnboarding && currentPath != '/') {
        return '/';
      }

      if (hasSeenOnboarding && currentPath == '/') {
        return isLoggedIn ? '/home' : '/login';
      }

      final isPublicRoute = _publicRoutes.contains(currentPath);

      if (!isLoggedIn && !isPublicRoute) {
        return '/login';
      }

      if (isLoggedIn && (currentPath == '/login' || currentPath == '/register')) {
        return '/home';
      }

      return null;
    },
    routes: [
      GoRoute(
        path: '/',
        builder: (ctx, state) => const OnboardingScreen(),
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
        path: '/home',
        builder: (ctx, state) => const HomeScreen(),
      ),
      GoRoute(
        path: '/swipe',
        builder: (ctx, state) => const SwipeScreen(),
      ),
      GoRoute(
        path: '/place/:id',
        builder: (ctx, state) => const PlaceDetailScreen(),
      ),
      GoRoute(
        path: '/group',
        builder: (ctx, state) => const GroupScreen(),
      ),
      GoRoute(
        path: '/group-matches',
        builder: (ctx, state) => const GroupMatchesScreen(),
      ),
      GoRoute(
        path: '/profile',
        builder: (ctx, state) => const ProfileScreen(),
      ),
    ],
  );
}
