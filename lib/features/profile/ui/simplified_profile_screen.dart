import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../logic/profile_controller.dart';
import '../../auth/logic/auth_controller.dart';
import '../../../common/widgets/error_view.dart';
import '../../../core/errors/user_message.dart';
import '../../../l10n/l10n.dart';
import '../../../app/theme.dart';
import '../../../common/widgets/skeleton.dart';
import '../../../common/widgets/member_avatar.dart';
import '../../group/logic/group_controller.dart';
import '../../swipe/logic/swipe_controller.dart';

class SimplifiedProfileScreen extends ConsumerWidget {
  const SimplifiedProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authControllerProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(context.l10n.profileTitle),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () => context.push('/settings'),
          ),
        ],
      ),
      body: authState.when(
        loading: () => const SkeletonList(count: 3, thumbnail: false),
        error: (e, st) => ErrorView(
          message: userMessage(e, fallback: context.l10n.errorLoadProfile, l10n: context.l10n),
          onRetry: () => ref.refresh(authControllerProvider),
        ),
        data: (user) {
          if (user == null) {
            return ErrorView(
              message: context.l10n.loginToViewProfile,
              title: context.l10n.notLoggedIn,
              icon: Icons.login,
              onRetry: () => context.go('/login'),
            );
          }

          final profileState = ref.watch(profileControllerProvider);

          return profileState.when(
            loading: () => _buildProfileContent(context, ref, user, isLoading: true),
            error: (e, st) => ErrorView(
              message: userMessage(e, fallback: context.l10n.errorLoadProfile, l10n: context.l10n),
              onRetry: () => ref.refresh(profileControllerProvider),
            ),
            data: (profileUser) {
              final displayUser = profileUser ?? user;
              return _buildProfileContent(context, ref, displayUser);
            },
          );
        },
      ),
    );
  }

  Widget _buildProfileContent(BuildContext context, WidgetRef ref, user, {bool isLoading = false}) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final l10n = context.l10n;
    final String name = (user.displayName as String?)?.trim().isNotEmpty == true
        ? user.displayName as String
        : l10n.userFallbackName;
    ref.watch(swipeControllerProvider);
    final favorites =
        ref.read(swipeControllerProvider.notifier).favoritesList.length;
    final groups = ref.watch(userGroupsProvider).value?.length ?? 0;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Column(
              children: [
                user.photoUrl != null
                    ? ClipOval(
                        child: CachedNetworkImage(
                          imageUrl: user.photoUrl!,
                          width: 96,
                          height: 96,
                          fit: BoxFit.cover,
                          placeholder: (context, url) => const SkeletonImage(),
                          errorWidget: (context, url, error) =>
                              MemberAvatar(id: user.uid, name: name, size: 96),
                        ),
                      )
                    : MemberAvatar(id: user.uid, name: name, size: 96),
                const SizedBox(height: 16),
                Text(name, style: text.headlineSmall),
                if (user.email != null && user.email.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    user.email,
                    style: text.bodyMedium
                        ?.copyWith(color: scheme.onSurfaceVariant),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: _StatTile(
                  icon: Icons.favorite_rounded,
                  value: favorites,
                  label: l10n.navFavorites,
                  onTap: () => context.go('/favorites'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _StatTile(
                  icon: Icons.groups_rounded,
                  value: groups,
                  label: l10n.navGroups,
                  onTap: () => context.go('/group'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => _showEditProfileDialog(context, ref, user),
              icon: const Icon(Icons.edit_outlined),
              label: Text(l10n.editProfile),
            ),
          ),
          const SizedBox(height: 32),
          Text(l10n.accountInfo, style: text.titleMedium),
          const SizedBox(height: 8),
          Card(
            child: ListTile(
              leading: const Icon(Icons.mail_outline),
              title: Text(l10n.emailLabel),
              subtitle: Text(
                user.email?.isNotEmpty == true ? user.email! : l10n.noEmail,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showEditProfileDialog(BuildContext context, WidgetRef ref, user) {
    final nameController = TextEditingController(text: user.displayName ?? '');

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(context.l10n.editProfile),
        content: TextField(
          controller: nameController,
          decoration: InputDecoration(
            labelText: context.l10n.displayNameLabel,
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(dialogContext);
            },
            child: Text(context.l10n.cancel),
          ),
          ElevatedButton(
            onPressed: () async {
              try {
                await ref.read(profileControllerProvider.notifier).updateProfile(
                  user.uid,
                  {'displayName': nameController.text.trim()},
                );
                if (dialogContext.mounted) {
                  Navigator.pop(dialogContext);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(context.l10n.profileUpdated), backgroundColor: context.swipeColors.like),
                  );
                }
              } catch (e) {
                if (dialogContext.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(userMessage(e, fallback: context.l10n.errorUpdateProfile, l10n: context.l10n)), backgroundColor: Theme.of(context).colorScheme.error),
                  );
                }
              }
            },
            child: Text(context.l10n.save),
          ),
        ],
      ),
    ).then((_) {
      nameController.dispose();
    });
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({
    required this.icon,
    required this.value,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final int value;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: scheme.primaryContainer,
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, size: 20, color: scheme.primary),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('$value', style: text.headlineSmall),
                  Text(
                    label,
                    style: text.bodySmall
                        ?.copyWith(color: scheme.onSurfaceVariant),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
