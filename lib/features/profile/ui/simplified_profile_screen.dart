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
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Column(
              children: [
                CircleAvatar(
                  radius: 50,
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  child: user.photoUrl != null
                      ? ClipOval(
                          child: CachedNetworkImage(
                            imageUrl: user.photoUrl!,
                            width: 100,
                            height: 100,
                            fit: BoxFit.cover,
                            placeholder: (context, url) => const SkeletonImage(),
                            errorWidget: (context, url, error) =>
                                const Icon(Icons.person, size: 50, color: Colors.white),
                          ),
                        )
                      : const Icon(Icons.person, size: 50, color: Colors.white),
                ),
                const SizedBox(height: 16),
                Text(
                  user.displayName ?? context.l10n.userFallbackName,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                if (user.email != null && user.email.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    user.email,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => _showEditProfileDialog(context, ref, user),
              icon: const Icon(Icons.edit),
              label: Text(context.l10n.editProfile),
            ),
          ),
          const SizedBox(height: 32),
          Text(
            context.l10n.accountInfo,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 16),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.email_outlined),
            title: Text(context.l10n.emailLabel),
            subtitle: Text(user.email?.isNotEmpty == true ? user.email! : context.l10n.noEmail),
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