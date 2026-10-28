import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../logic/profile_controller.dart';
import '../logic/passport_controller.dart';
import '../../auth/logic/auth_controller.dart';
import '../../../common/widgets/error_view.dart';
import '../../../core/errors/user_message.dart';
import '../../../l10n/l10n.dart';
import '../../../app/theme.dart';
import '../../../common/widgets/skeleton.dart';
import '../../../common/widgets/member_avatar.dart';
import '../../../common/widgets/ticket.dart';
import '../../../core/constants/sizes.dart';
import '../../../core/constants/colors.dart';
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
            tooltip: context.l10n.settingsTitle,
            icon: const Icon(Icons.settings_outlined),
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

    final email = (user.email as String?)?.trim() ?? '';
    final edge = context.swipeColors.edge;
    const avatarSize = 76.0;
    final Widget avatar = user.photoUrl != null
        ? ClipOval(
            child: CachedNetworkImage(
              imageUrl: user.photoUrl!,
              width: avatarSize,
              height: avatarSize,
              fit: BoxFit.cover,
              placeholder: (context, url) => const SkeletonImage(),
              errorWidget: (context, url, error) =>
                  MemberAvatar(id: user.uid, name: name, size: avatarSize),
            ),
          )
        : MemberAvatar(id: user.uid, name: name, size: avatarSize);

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(
        AppSizes.screenEdge,
        AppSizes.space8,
        AppSizes.screenEdge,
        AppSizes.space32,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Passport-style ticket: who you are above the perforation, what
          // you collected below it.
          Ticket(
            raised: true,
            notchFromBottom: _stubHeight,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.all(AppSizes.space16 + 4),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(3),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: scheme.surface,
                          border: Border.all(color: edge, width: AppSizes.edge),
                        ),
                        child: avatar,
                      ),
                      const SizedBox(width: AppSizes.space16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              name,
                              style: text.headlineSmall,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            if (email.isNotEmpty) ...[
                              const SizedBox(height: 2),
                              Text(
                                email,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: text.bodySmall
                                    ?.copyWith(color: scheme.onSurfaceVariant),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(
                  height: _stubHeight,
                  child: Row(
                    children: [
                      Expanded(
                        child: _Stat(
                          icon: Icons.favorite_rounded,
                          value: favorites,
                          label: l10n.navFavorites,
                          onTap: () => context.go('/favorites'),
                        ),
                      ),
                      Container(
                        width: 1,
                        height: _stubHeight - 28,
                        color: scheme.outlineVariant,
                      ),
                      Expanded(
                        child: _Stat(
                          icon: Icons.luggage_rounded,
                          value: groups,
                          label: l10n.navTrips,
                          onTap: () => context.go('/trips'),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSizes.space16),
          OutlinedButton.icon(
            onPressed: () => _showEditProfileDialog(context, ref, user),
            icon: const Icon(Icons.edit_outlined),
            label: Text(l10n.editProfile),
          ),
          const SizedBox(height: AppSizes.groupGap),
          const _PassportRow(),
          const SizedBox(height: AppSizes.space16),
          // Favorites moved here from their own tab.
          ClipRRect(
            borderRadius: BorderRadius.circular(AppSizes.radiusMd),
            child: Material(
              color: scheme.surface,
              child: Column(
                children: [
                  ListTile(
                    leading: Icon(Icons.favorite_rounded, color: scheme.primary),
                    title: Text(l10n.navFavorites),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('$favorites',
                            style: text.bodyLarge
                                ?.copyWith(color: scheme.onSurfaceVariant)),
                        const Icon(Icons.chevron_right_rounded),
                      ],
                    ),
                    onTap: () => context.push('/favorites'),
                  ),
                  Divider(
                      height: 0.5,
                      thickness: 0.5,
                      indent: 56,
                      color: scheme.outlineVariant),
                  ListTile(
                    leading: Icon(Icons.map_outlined, color: scheme.primary),
                    title: Text(l10n.profileFavoritesMap),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: () => context.push('/favorites-map'),
                  ),
                ],
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
                    SnackBar(content: Text(context.l10n.profileUpdated)),
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

/// Height of the stats stub under the passport's perforation.
const double _stubHeight = 76;

class _Stat extends StatelessWidget {
  const _Stat({
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
    return InkWell(
      onTap: onTap,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 18, color: scheme.onSurface),
              const SizedBox(width: AppSizes.space4),
              Text('$value', style: text.titleLarge),
            ],
          ),
          Text(
            label.toUpperCase(),
            style: text.labelSmall?.copyWith(
              color: scheme.onSurfaceVariant,
              letterSpacing: 1.1,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

/// Entry to the passport: a small navy booklet and the stamp count.
class _PassportRow extends ConsumerWidget {
  const _PassportRow();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final count = ref.watch(passportStampsProvider).value?.length ?? 0;
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppSizes.radiusMd),
      child: Material(
        color: scheme.surface,
        child: ListTile(
          contentPadding: const EdgeInsets.symmetric(
              horizontal: AppSizes.space16, vertical: AppSizes.space4),
          leading: Container(
            width: 36,
            height: 48,
            decoration: const BoxDecoration(
              color: BrandColors.navy,
              borderRadius: BorderRadius.horizontal(
                left: Radius.circular(3),
                right: Radius.circular(7),
              ),
            ),
            child: const Icon(Icons.public_rounded,
                color: Color(0xFFE8C46A), size: 20),
          ),
          title: Text(context.l10n.passportTitle),
          subtitle: Text(context.l10n.passportStampCount(count)),
          trailing: const Icon(Icons.chevron_right_rounded),
          onTap: () => context.push('/passport'),
        ),
      ),
    );
  }
}
