import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../features/auth/logic/auth_controller.dart';
import '../l10n/l10n.dart';

/// Why a guest is asked to create an account. Each reason has its own full
/// sentence in the translations, because word order differs per language.
enum GateReason { groupSwipe, groups, joinGroup, groupMatches, profile, favorites }

/// Shows [child] only to users with a real account. Guests (anonymous
/// sessions) see a short explanation with buttons to sign up or log in.
class AccountGate extends ConsumerWidget {
  final GateReason reason;
  final IconData icon;
  final Widget child;

  /// Extra app-bar actions shown to guests, e.g. a settings button.
  final List<Widget>? guestActions;

  const AccountGate({
    super.key,
    required this.reason,
    required this.child,
    this.icon = Icons.lock_outline,
    this.guestActions,
  });

  String _title(AppLocalizations l10n) => switch (reason) {
        GateReason.groupSwipe => l10n.gateGroupSwipeTitle,
        GateReason.groups => l10n.gateGroupsTitle,
        GateReason.joinGroup => l10n.gateJoinGroupTitle,
        GateReason.groupMatches => l10n.gateGroupMatchesTitle,
        GateReason.profile => l10n.gateProfileTitle,
        GateReason.favorites => l10n.gateFavoritesTitle,
      };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isGuest = ref.watch(
      authControllerProvider.select((s) => s.value?.isAnonymous ?? false),
    );
    if (!isGuest) return child;

    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(actions: guestActions),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 72, color: theme.colorScheme.primary),
              const SizedBox(height: 24),
              Text(
                _title(context.l10n),
                style: theme.textTheme.titleLarge,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(
                context.l10n.gateBody,
                style: theme.textTheme.bodyMedium
                    ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => context.push('/register'),
                  child: Text(context.l10n.gateCreateAccount),
                ),
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: () => context.push('/login'),
                child: Text(context.l10n.gateHaveAccount),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
