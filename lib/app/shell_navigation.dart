import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../features/swipe/logic/swipe_controller.dart';
import '../l10n/l10n.dart';

/// Bottom navigation for the four main areas. Material 3 NavigationBar with
/// a pill indicator; favorites have their own tab with a count badge.
class ShellNavigation extends ConsumerWidget {
  final Widget child;

  const ShellNavigation({super.key, required this.child});

  static const _tabs = ['/home', '/group', '/favorites', '/profile'];

  static int _indexFor(String location) {
    if (location.startsWith('/group')) return 1;
    if (location.startsWith('/favorites')) return 2;
    if (location.startsWith('/profile') || location.startsWith('/settings')) {
      return 3;
    }
    return 0; // /home, /swipe, /place
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final location = GoRouterState.of(context).matchedLocation;
    // Rebuild the badge when favorites change.
    ref.watch(swipeControllerProvider);
    final favoritesCount =
        ref.read(swipeControllerProvider.notifier).favoritesList.length;

    return Scaffold(
      body: child,
      bottomNavigationBar: NavigationBar(
        selectedIndex: _indexFor(location),
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        onDestinationSelected: (index) => context.go(_tabs[index]),
        destinations: [
          NavigationDestination(
            icon: const Icon(Icons.explore_outlined),
            selectedIcon: const Icon(Icons.explore),
            label: l10n.navDiscover,
          ),
          NavigationDestination(
            icon: const Icon(Icons.group_outlined),
            selectedIcon: const Icon(Icons.group),
            label: l10n.navGroups,
          ),
          NavigationDestination(
            icon: Badge(
              isLabelVisible: favoritesCount > 0,
              label: Text('$favoritesCount'),
              child: const Icon(Icons.favorite_border),
            ),
            selectedIcon: Badge(
              isLabelVisible: favoritesCount > 0,
              label: Text('$favoritesCount'),
              child: const Icon(Icons.favorite),
            ),
            label: l10n.navFavorites,
          ),
          NavigationDestination(
            icon: const Icon(Icons.person_outline),
            selectedIcon: const Icon(Icons.person),
            label: l10n.navProfile,
          ),
        ],
      ),
    );
  }
}
