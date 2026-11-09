import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../logic/profile_controller.dart';
import '../logic/passport_controller.dart';
import '../widgets/suitcase_card.dart';
import '../../auth/logic/auth_controller.dart';
import '../../../common/utils/passport_mrz.dart';
import '../../../common/widgets/error_view.dart';
import '../../../core/errors/user_message.dart';
import '../../../l10n/l10n.dart';
import '../../../app/theme.dart';
import '../../../common/widgets/skeleton.dart';
import '../../../common/widgets/member_avatar.dart';
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
          message: userMessage(e,
              fallback: context.l10n.errorLoadProfile, l10n: context.l10n),
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
            loading: () =>
                _buildProfileContent(context, ref, user, isLoading: true),
            error: (e, st) => ErrorView(
              message: userMessage(e,
                  fallback: context.l10n.errorLoadProfile, l10n: context.l10n),
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

  Widget _buildProfileContent(BuildContext context, WidgetRef ref, user,
      {bool isLoading = false}) {
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
    const avatarSize = 64.0;
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

    final suitcase = ref.watch(suitcaseProgressProvider);
    final stamps = ref.watch(passportStampsProvider).value?.length ?? 0;

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
          // The travel ID first; the suitcase game sits in front of the wallet.
          Container(
            decoration: BoxDecoration(
              color: scheme.surface,
              borderRadius: BorderRadius.circular(_walletRadius),
              border: Border.all(color: edge, width: AppSizes.edge),
            ),
            padding: const EdgeInsets.fromLTRB(16, 10, 8, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 26,
                      height: 26,
                      decoration: BoxDecoration(
                        color: BrandColors.navy,
                        borderRadius: BorderRadius.circular(7),
                      ),
                      child: const Icon(Icons.flight_rounded,
                          size: 16, color: BrandColors.amber),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(l10n.profileIdTitle,
                              style: text.titleSmall
                                  ?.copyWith(fontWeight: FontWeight.w600)),
                          Text(
                            l10n.profileIdNumber(
                                passportNumber(user.uid as String)),
                            style: text.labelSmall?.copyWith(
                              color: scheme.onSurfaceVariant,
                              fontFamily: 'Courier',
                              fontFamilyFallback: const ['Menlo'],
                              letterSpacing: 1.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      tooltip: l10n.editProfile,
                      icon: Icon(Icons.edit_outlined, color: scheme.primary),
                      onPressed: () =>
                          _showEditProfileDialog(context, ref, user),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    avatar,
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
                          if (email.isNotEmpty)
                            Text(
                              email,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: text.bodySmall
                                  ?.copyWith(color: scheme.onSurfaceVariant),
                            ),
                          const SizedBox(height: AppSizes.space12),
                          Row(
                            children: [
                              _IdField(
                                label: l10n.navTrips,
                                value: groups,
                                onTap: () => context.go('/trips'),
                              ),
                              _IdField(
                                label: l10n.passportDataCities,
                                value: suitcase?.cities ?? 0,
                              ),
                              _IdField(
                                label: l10n.passportDataCountries,
                                value: suitcase?.countries ?? 0,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSizes.space16),
                // Machine-readable zone, as at the foot of a passport.
                Container(
                  margin: const EdgeInsets.only(right: 8),
                  padding:
                      const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
                  decoration: BoxDecoration(
                    color: scheme.onSurface.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      () {
                        final (l1, l2) = passportMrz(
                          name: name,
                          uid: user.uid as String,
                          issued: user.createdAt as DateTime? ?? DateTime.now(),
                        );
                        return '$l1\n$l2';
                      }(),
                      style: TextStyle(
                        fontFamily: 'Courier',
                        fontFamilyFallback: const ['Menlo'],
                        fontSize: 13,
                        height: 1.35,
                        letterSpacing: 1,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSizes.space24),
          // The collections as a wallet: full cards stacked so only their
          // tops show, the suitcase in front (like Apple Wallet).
          Stack(
            children: [
              for (final (i, card) in [
                _WalletCard(
                  color: BrandColors.navy,
                  onColor: Colors.white,
                  icon: Icons.public_rounded,
                  title: l10n.passportTitle,
                  value: l10n.passportStampCount(stamps),
                  onTap: () => context.push('/passport'),
                ),
                _WalletCard(
                  color: BrandColors.amber,
                  onColor: BrandColors.navy,
                  icon: Icons.favorite_rounded,
                  title: l10n.navFavorites,
                  value: '$favorites',
                  onTap: () => context.push('/favorites'),
                ),
                _WalletCard(
                  color: BrandColors.coral,
                  onColor: Colors.white,
                  icon: Icons.map_rounded,
                  title: l10n.profileMapTab,
                  onTap: () => context.push('/favorites-map'),
                ),
              ].indexed)
                Positioned(
                  top: i * _walletPeek,
                  left: 0,
                  right: 0,
                  height: _walletCardHeight,
                  child: card,
                ),
              Padding(
                padding: const EdgeInsets.only(top: 3 * _walletPeek),
                child: DecoratedBox(
                  decoration: const BoxDecoration(
                    borderRadius: BorderRadius.all(Radius.circular(24)),
                    boxShadow: _walletShadow,
                  ),
                  child: SuitcaseCard(),
                ),
              ),
            ],
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
                await ref
                    .read(profileControllerProvider.notifier)
                    .updateProfile(
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
                    SnackBar(
                        content: Text(userMessage(e,
                            fallback: context.l10n.errorUpdateProfile,
                            l10n: context.l10n)),
                        backgroundColor: Theme.of(context).colorScheme.error),
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

/// Profile wallet geometry: how much of each card shows above the next,
/// the full card height and the corner radius.
const double _walletPeek = 54;
const double _walletCardHeight = 200;
const double _walletRadius = 18;

/// The soft shadow a card casts upward onto the card behind it.
const _walletShadow = [
  BoxShadow(color: Color(0x2E000000), blurRadius: 10, offset: Offset(0, -3)),
];

/// One collection card in the wallet; only its top band shows.
class _WalletCard extends StatelessWidget {
  const _WalletCard({
    required this.color,
    required this.onColor,
    required this.icon,
    required this.title,
    required this.onTap,
    this.value,
  });

  final Color color;
  final Color onColor;
  final IconData icon;
  final String title;
  final String? value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(_walletRadius),
        boxShadow: _walletShadow,
      ),
      child: Material(
        color: color,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(_walletRadius),
          side: BorderSide(
              color: Colors.white.withValues(alpha: 0.18), width: 0.5),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Align(
            alignment: Alignment.topCenter,
            child: SizedBox(
              height: _walletPeek,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 18),
                child: Row(
                  children: [
                    Icon(icon, color: onColor, size: 22),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(title,
                          style: text.titleMedium?.copyWith(
                              color: onColor, fontWeight: FontWeight.w700)),
                    ),
                    if (value != null)
                      Text(value!,
                          style: text.labelLarge?.copyWith(color: onColor)),
                    Icon(Icons.chevron_right_rounded,
                        color: onColor.withValues(alpha: 0.7)),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A labelled number on the travel ID.
class _IdField extends StatelessWidget {
  const _IdField({required this.label, required this.value, this.onTap});

  final String label;
  final int value;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label,
                style:
                    text.labelSmall?.copyWith(color: scheme.onSurfaceVariant)),
            Text('$value', style: text.titleLarge),
          ],
        ),
      ),
    );
  }
}
