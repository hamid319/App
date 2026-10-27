import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../auth/logic/account_deletion_controller.dart';
import '../../auth/logic/auth_controller.dart';
import '../../../app/language_picker.dart';
import '../../../app/locale_controller.dart';
import '../../../app/theme_mode_controller.dart';
import '../../../app/theme_mode_picker.dart';
import '../../../app/theme.dart';
import '../../../common/widgets/ticket.dart';
import '../../../core/constants/sizes.dart';
import '../../../core/errors/user_message.dart';
import '../../../l10n/l10n.dart';
import '../../../common/widgets/member_avatar.dart';
import '../../group/logic/group_controller.dart';
import '../logic/profile_controller.dart';
import '../../swipe/logic/swipe_controller.dart';

/// Open to everyone. The "App" section (language, privacy, security) works
/// for guests too; the "Account" section depends on having a real account.
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final user = ref.watch(authControllerProvider).value;
    final hasAccount = user != null && !user.isAnonymous;
    final languageCode = ref.watch(localeControllerProvider)?.languageCode;
    final themeMode = ref.watch(themeModeControllerProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.settingsTitle),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          AppSizes.screenEdge,
          AppSizes.space8,
          AppSizes.screenEdge,
          AppSizes.space32,
        ),
        children: [
          _ProfileCard(hasAccount: hasAccount),
          const SizedBox(height: AppSizes.groupGap),
          _SettingsGroup(
            label: l10n.settingsAppSection,
            tiles: [
              ListTile(
                leading: const Icon(Icons.language_rounded),
                title: Text(l10n.languageTitle),
                subtitle: Text(languageName(l10n, languageCode)),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () => showLanguagePicker(context, ref),
              ),
              ListTile(
                leading: const Icon(Icons.dark_mode_outlined),
                title: Text(l10n.appearanceTitle),
                subtitle: Text(themeModeName(l10n, themeMode)),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () => showThemeModePicker(context, ref),
              ),
              ListTile(
                leading: const Icon(Icons.privacy_tip_outlined),
                title: Text(l10n.privacy),
                subtitle: Text(l10n.privacySubtitle),
                onTap: () => _showDataPrivacy(context),
              ),
              ListTile(
                leading: const Icon(Icons.security_outlined),
                title: Text(l10n.security),
                subtitle: Text(l10n.securitySubtitle),
                onTap: () => _showSecurity(context),
              ),
              ListTile(
                leading: const Icon(Icons.article_outlined),
                title: Text(l10n.licenses),
                onTap: () => showLicensePage(
                  context: context,
                  applicationName: 'SwipeTrip',
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSizes.groupGap),
          _SettingsGroup(
            label: l10n.settingsAccountSection,
            tiles: hasAccount
                ? [
                    ListTile(
                      leading: const Icon(Icons.payments_outlined),
                      title: Text(l10n.paypalHandleTitle),
                      subtitle: Text(
                        ref.watch(profileControllerProvider).value?.paypalHandle ??
                            l10n.paypalHandleNone,
                      ),
                      trailing: const Icon(Icons.chevron_right_rounded),
                      onTap: () => _editPaypalHandle(context, ref),
                    ),
                    if (user.email.isNotEmpty)
                      ListTile(
                        leading: const Icon(Icons.lock_reset_rounded),
                        title: Text(l10n.resetPasswordSetting),
                        subtitle: Text(l10n.resetPasswordSettingSubtitle),
                        trailing: const Icon(Icons.chevron_right_rounded),
                        onTap: () => context.push(
                          Uri(
                            path: '/forgot-password',
                            queryParameters: {
                              'email': user.email,
                              'from': 'settings',
                            },
                          ).toString(),
                        ),
                      ),
                    ListTile(
                      leading: Icon(Icons.logout_rounded,
                          color: Theme.of(context).colorScheme.error),
                      title: Text(
                        l10n.logout,
                        style: TextStyle(
                            color: Theme.of(context).colorScheme.error),
                      ),
                      subtitle: Text(l10n.logoutSubtitle),
                      onTap: () => _showLogoutDialog(context, ref),
                    ),
                    const _DeleteAccountTile(),
                  ]
                : [
                    ListTile(
                      leading: const Icon(Icons.person_add_alt_1_outlined),
                      title: Text(l10n.gateCreateAccount),
                      subtitle: Text(l10n.createAccountToManage),
                      trailing: const Icon(Icons.chevron_right_rounded),
                      onTap: () => context.push('/register'),
                    ),
                    ListTile(
                      leading: const Icon(Icons.login_rounded),
                      title: Text(l10n.gateHaveAccount),
                      trailing: const Icon(Icons.chevron_right_rounded),
                      onTap: () => context.push('/login'),
                    ),
                    const _DeleteAccountTile(),
                  ],
          ),
        ],
      ),
    );
  }

  /// Optional paypal.me name, used for payment links in trip costs.
  Future<void> _editPaypalHandle(BuildContext context, WidgetRef ref) async {
    final l10n = context.l10n;
    final uid = ref.read(authControllerProvider).value?.uid;
    if (uid == null) return;
    final controller = TextEditingController(
        text: ref.read(profileControllerProvider).value?.paypalHandle ?? '');
    final value = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.paypalHandleTitle),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l10n.paypalHandleBody),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              autofocus: true,
              autocorrect: false,
              decoration: InputDecoration(
                prefixText: l10n.paypalHandlePrefix,
                hintText: l10n.paypalHandleHint,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            style: FilledButton.styleFrom(minimumSize: const Size(96, 44)),
            onPressed: () => Navigator.pop(dialogContext, controller.text),
            child: Text(l10n.save),
          ),
        ],
      ),
    );
    controller.dispose();
    if (value == null) return;
    final handle = value.trim().replaceFirst(
        RegExp(r'^(https?://)?(www\.)?paypal\.me/'), '');
    await ref.read(profileControllerProvider.notifier).updateProfile(
      uid,
      {'paypalHandle': handle.isEmpty ? null : handle},
    );
  }

  void _showLogoutDialog(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.logout),
        content: Text(l10n.logoutConfirm),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(l10n.cancel),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(dialogContext);
              await ref.read(authControllerProvider.notifier).logout();
              if (context.mounted) {
                // Logging out starts a fresh guest session, so go back to swiping.
                context.go('/home');
              }
            },
            style: TextButton.styleFrom(foregroundColor: Theme.of(context).colorScheme.error),
            child: Text(l10n.logout),
          ),
        ],
      ),
    );
  }

  void _showDataPrivacy(BuildContext context) {
    final l10n = context.l10n;
    _showInfoDialog(
      context,
      title: l10n.privacy,
      children: [
        _bold(l10n.privacyWhatWeStore),
        const SizedBox(height: 8),
        Text(l10n.privacyItemEmail),
        Text(l10n.privacyItemProfile),
        Text(l10n.privacyItemActivity),
        Text(l10n.privacyItemLocation),
        const SizedBox(height: 16),
        _bold(l10n.privacyWhereStored),
        const SizedBox(height: 8),
        Text(l10n.privacyWhereStoredBody),
        const SizedBox(height: 16),
        _bold(l10n.privacyRights),
        const SizedBox(height: 8),
        Text(l10n.privacyRightsBody),
      ],
    );
  }

  void _showSecurity(BuildContext context) {
    final l10n = context.l10n;
    _showInfoDialog(
      context,
      title: l10n.security,
      children: [
        _bold(l10n.securityHeader),
        const SizedBox(height: 16),
        Text(l10n.securityItemAuth),
        const SizedBox(height: 8),
        Text(l10n.securityItemHttps),
        const SizedBox(height: 16),
        _bold(l10n.securityTips),
        const SizedBox(height: 8),
        Text(l10n.securityTipPassword),
        Text(l10n.securityTipLogout),
        Text(l10n.securityTipUpdate),
        const SizedBox(height: 16),
        Text(
          l10n.securityComingSoon,
          style: const TextStyle(fontSize: 12, fontStyle: FontStyle.italic),
        ),
      ],
    );
  }

  Widget _bold(String text) =>
      Text(text, style: const TextStyle(fontWeight: FontWeight.bold));

  void _showInfoDialog(
    BuildContext context, {
    required String title,
    required List<Widget> children,
  }) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(title),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: children,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(context.l10n.close),
          ),
        ],
      ),
    );
  }
}

/// Deletes the account after explaining what goes and what stays; asks for
/// the password when Firebase wants a recent sign-in.
class _DeleteAccountTile extends ConsumerWidget {
  const _DeleteAccountTile();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final error = Theme.of(context).colorScheme.error;
    final busy = ref.watch(accountDeletionControllerProvider).isLoading;
    return ListTile(
      enabled: !busy,
      leading: Icon(Icons.delete_forever_outlined, color: error),
      title: Text(l10n.deleteAccount, style: TextStyle(color: error)),
      subtitle: Text(l10n.deleteAccountSubtitle),
      trailing: busy
          ? SizedBox.square(
              dimension: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                semanticsLabel: l10n.deleteAccountInProgress,
              ),
            )
          : null,
      onTap: () => _deleteAccount(context, ref),
    );
  }

  Future<void> _deleteAccount(BuildContext context, WidgetRef ref) async {
    final l10n = context.l10n;
    if (await _confirm(context) != true || !context.mounted) return;

    // The settings page goes away once the account is signed out, so keep
    // what is needed afterwards.
    final router = GoRouter.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final controller = ref.read(accountDeletionControllerProvider.notifier);

    String? password;
    while (true) {
      final AccountDeletionOutcome outcome;
      try {
        outcome = await controller.deleteAccount(password: password);
      } catch (e) {
        messenger.showSnackBar(SnackBar(
          content: Text(
              userMessage(e, fallback: l10n.deleteAccountFailed, l10n: l10n)),
        ));
        return;
      }
      if (outcome == AccountDeletionOutcome.deleted) {
        messenger.showSnackBar(
            SnackBar(content: Text(l10n.deleteAccountDone)));
        router.go('/onboarding');
        return;
      }
      if (!context.mounted) return;
      password = await _askPassword(context);
      if (password == null || password.isEmpty) return;
    }
  }

  Future<bool?> _confirm(BuildContext context) {
    final l10n = context.l10n;
    final scheme = Theme.of(context).colorScheme;
    const bold = TextStyle(fontWeight: FontWeight.bold);
    return showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.deleteAccountDialogTitle),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(l10n.deleteAccountIntro, style: bold),
              const SizedBox(height: 8),
              Text(l10n.deleteAccountItemProfile),
              Text(l10n.deleteAccountItemActivity),
              Text(l10n.deleteAccountItemTrips),
              const SizedBox(height: 16),
              Text(l10n.deleteAccountKeptTitle, style: bold),
              const SizedBox(height: 8),
              Text(l10n.deleteAccountKeptBody),
              const SizedBox(height: 16),
              Text(l10n.deleteAccountIrreversible, style: bold),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: scheme.error,
              foregroundColor: scheme.onError,
              minimumSize: const Size(96, 44),
            ),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(l10n.deleteAccountConfirm),
          ),
        ],
      ),
    );
  }

  Future<String?> _askPassword(BuildContext context) async {
    final l10n = context.l10n;
    final scheme = Theme.of(context).colorScheme;
    final controller = TextEditingController();
    final password = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.deleteAccountPasswordTitle),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l10n.deleteAccountPasswordBody),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              autofocus: true,
              obscureText: true,
              autocorrect: false,
              enableSuggestions: false,
              autofillHints: const [AutofillHints.password],
              decoration: InputDecoration(labelText: l10n.passwordLabel),
              onSubmitted: (value) => Navigator.pop(dialogContext, value),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: scheme.error,
              foregroundColor: scheme.onError,
              minimumSize: const Size(96, 44),
            ),
            onPressed: () => Navigator.pop(dialogContext, controller.text),
            child: Text(l10n.deleteAccountConfirm),
          ),
        ],
      ),
    );
    controller.dispose();
    return password;
  }
}

/// A [SectionLabel] above a ticket holding [tiles], split by hairlines.
class _SettingsGroup extends StatelessWidget {
  const _SettingsGroup({required this.label, required this.tiles});

  final String label;
  final List<Widget> tiles;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionLabel(label),
        Ticket(
          child: Column(
            children: [
              for (final (i, tile) in tiles.indexed) ...[
                if (i > 0) const Divider(height: 1, indent: 56),
                tile,
              ],
            ],
          ),
        ),
      ],
    );
  }
}

/// Who is signed in, with a quick count of what they have saved.
class _ProfileCard extends ConsumerWidget {
  const _ProfileCard({required this.hasAccount});

  final bool hasAccount;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final user = ref.watch(authControllerProvider).value;
    ref.watch(swipeControllerProvider);
    final favorites =
        ref.read(swipeControllerProvider.notifier).favoritesList.length;
    final groups = ref.watch(userGroupsProvider).value?.length ?? 0;
    final name = hasAccount
        ? (user?.displayName?.trim().isNotEmpty == true
            ? user!.displayName!.trim()
            : (user?.email ?? l10n.userFallbackName))
        : l10n.guestName;

    return Ticket(
      raised: true,
      onTap: () => context.go('/profile'),
      padding: const EdgeInsets.all(AppSizes.space16),
      child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: context.swipeColors.edge,
                      width: AppSizes.edge,
                    ),
                  ),
                  child: hasAccount
                      ? MemberAvatar(id: user?.uid ?? '', name: name, size: 48)
                      : CircleAvatar(
                          radius: 24,
                          backgroundColor: scheme.surfaceContainerHighest,
                          child: Icon(Icons.person_outline,
                              color: scheme.onSurface),
                        ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: text.titleMedium,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        hasAccount
                            ? l10n.profileStats(favorites, groups)
                            : l10n.guestSubtitle,
                        style: text.bodyMedium
                            ?.copyWith(color: scheme.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right_rounded, color: scheme.onSurfaceVariant),
              ],
            ),
    );
  }
}
