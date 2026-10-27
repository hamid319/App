import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../l10n/l10n.dart';

/// Bottom navigation for the three main areas: trips (start), discover and
/// profile. Favorites live inside the profile.
class ShellNavigation extends StatelessWidget {
  final Widget child;

  const ShellNavigation({super.key, required this.child});

  static const _tabs = ['/trips', '/home', '/profile'];

  static int indexFor(String location) {
    if (location.startsWith('/trips') || location.startsWith('/group')) {
      return 0;
    }
    if (location.startsWith('/profile') ||
        location.startsWith('/settings') ||
        location.startsWith('/favorites')) {
      return 2;
    }
    return 1; // /home, /collection, /swipe
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final location = GoRouterState.of(context).matchedLocation;

    return Scaffold(
      body: child,
      bottomNavigationBar: DecoratedBox(
        decoration: BoxDecoration(
          border: Border(
            top: BorderSide(
              color: Theme.of(context).colorScheme.outlineVariant,
              width: 0.5,
            ),
          ),
        ),
        child: NavigationBar(
          selectedIndex: indexFor(location),
          labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
          onDestinationSelected: (index) => context.go(_tabs[index]),
          destinations: [
            NavigationDestination(
              icon: const Icon(Icons.luggage_outlined),
              selectedIcon: const Icon(Icons.luggage_rounded),
              label: l10n.navTrips,
            ),
            NavigationDestination(
              icon: const Icon(Icons.explore_outlined),
              selectedIcon: const Icon(Icons.explore),
              label: l10n.navDiscover,
            ),
            NavigationDestination(
              icon: const Icon(Icons.person_outline),
              selectedIcon: const Icon(Icons.person),
              label: l10n.navProfile,
            ),
          ],
        ),
      ),
    );
  }
}
