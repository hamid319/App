import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../auth/logic/auth_controller.dart';
import '../../../app/language_picker.dart';
import '../../../app/locale_controller.dart';
import '../../../app/theme_mode_controller.dart';
import '../../../app/theme_mode_picker.dart';
import '../../../l10n/l10n.dart';

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
        children: [
          _SectionHeader(l10n.settingsAppSection),
          ListTile(
            leading: const Icon(Icons.language),
            title: Text(l10n.languageTitle),
            subtitle: Text(languageName(l10n, languageCode)),
            onTap: () => showLanguagePicker(context, ref),
          ),
          ListTile(
            leading: const Icon(Icons.dark_mode_outlined),
            title: Text(l10n.appearanceTitle),
            subtitle: Text(themeModeName(l10n, themeMode)),
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
          const Divider(),
          _SectionHeader(l10n.settingsAccountSection),
          if (hasAccount)
            ListTile(
              leading: Icon(Icons.logout, color: Theme.of(context).colorScheme.error),
              title: Text(l10n.logout),
              subtitle: Text(l10n.logoutSubtitle),
              onTap: () => _showLogoutDialog(context, ref),
            )
          else ...[
            ListTile(
              leading: const Icon(Icons.person_add_alt_1),
              title: Text(l10n.gateCreateAccount),
              subtitle: Text(l10n.createAccountToManage),
              onTap: () => context.push('/register'),
            ),
            ListTile(
              leading: const Icon(Icons.login),
              title: Text(l10n.gateHaveAccount),
              onTap: () => context.push('/login'),
            ),
          ],
        ],
      ),
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

class _SectionHeader extends StatelessWidget {
  final String text;
  const _SectionHeader(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: Text(
        text,
        style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: Theme.of(context).colorScheme.primary,
            ),
      ),
    );
  }
}
