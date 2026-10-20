import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../app/theme.dart';
import '../../../common/models/place_model.dart';
import '../../../common/utils/place_type_labels.dart';
import '../../../common/widgets/place_photo.dart';
import '../../../common/widgets/skeleton.dart';
import '../../../core/constants/colors.dart';
import '../../../core/constants/sizes.dart';
import '../../../core/errors/user_message.dart';
import '../../../core/services/maps_launcher.dart';
import '../../../l10n/l10n.dart';
import '../../swipe/data/places_repository.dart';
import '../../swipe/logic/swipe_controller.dart';
import '../widgets/maps_app_sheet.dart';
import '../widgets/photo_credits.dart';
import '../widgets/prompt_tile.dart';

final placeDetailProvider =
    FutureProvider.family<PlaceModel?, String>((ref, placeId) async {
  final repo = PlacesRepository();
  return await repo.getPlaceById(placeId);
});

class PlaceDetailScreen extends ConsumerWidget {
  const PlaceDetailScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final placeId = GoRouterState.of(context).pathParameters['id'] ?? '';
    final placeAsync = ref.watch(placeDetailProvider(placeId));

    return placeAsync.when(
      loading: () => const Scaffold(body: SkeletonDetail()),
      error: (error, stack) => _Message(
        icon: Icons.error_outline,
        iconColor: Theme.of(context).colorScheme.error,
        text: userMessage(
          error,
          fallback: context.l10n.errorLoadPlace,
          l10n: context.l10n,
        ),
      ),
      data: (place) => place == null
          ? _Message(
              icon: Icons.place,
              iconColor: Theme.of(context).colorScheme.onSurfaceVariant,
              text: context.l10n.placeNotFound,
            )
          : _PlaceDetailContent(place: place),
    );
  }
}

class _Message extends StatelessWidget {
  const _Message({
    required this.icon,
    required this.iconColor,
    required this.text,
  });

  final IconData icon;
  final Color iconColor;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSizes.space24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 64, color: iconColor),
              const SizedBox(height: AppSizes.space16),
              Text(text, textAlign: TextAlign.center),
              const SizedBox(height: AppSizes.space16),
              OutlinedButton(
                onPressed: () => context.pop(),
                child: Text(context.l10n.back),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Big photo that shrinks as you scroll (the card's photo flies in via
/// Hero), floating glass buttons, and the main action pinned at the bottom.
class _PlaceDetailContent extends ConsumerStatefulWidget {
  const _PlaceDetailContent({required this.place});

  final PlaceModel place;

  @override
  ConsumerState<_PlaceDetailContent> createState() =>
      _PlaceDetailContentState();
}

class _PlaceDetailContentState extends ConsumerState<_PlaceDetailContent> {
  final _scroll = ScrollController();

  /// True once the photo has scrolled away; the status bar text then has to
  /// switch from light (on the photo) to the theme's normal colour.
  bool _collapsed = false;

  PlaceModel get place => widget.place;

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  void _onScroll(double heroHeight) {
    final collapsed = _scroll.offset > heroHeight - kToolbarHeight - 24;
    if (collapsed != _collapsed) setState(() => _collapsed = collapsed);
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(swipeControllerProvider);
    final swipeCtrl = ref.read(swipeControllerProvider.notifier);
    final isFav = swipeCtrl.isFavorite(place.id);
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final l10n = context.l10n;
    final tags = placeTypeLabels(l10n, place.types);
    final description = place.description?.trim() ?? '';
    final heroHeight = MediaQuery.sizeOf(context).height * 0.46;
    final darkTheme = Theme.of(context).brightness == Brightness.dark;

    Future<void> toggleFavorite() async {
      final messenger = ScaffoldMessenger.of(context);
      if (isFav) {
        await swipeCtrl.removeFavorite(place.id);
        messenger.showSnackBar(
          SnackBar(content: Text(l10n.placeRemovedFromFavorites(place.name))),
        );
      } else {
        await swipeCtrl.addFavorite(place.id);
        messenger.showSnackBar(
          SnackBar(content: Text(l10n.placeAddedToFavorites(place.name))),
        );
      }
    }

    return Scaffold(
      body: NotificationListener<ScrollNotification>(
        onNotification: (_) {
          _onScroll(heroHeight);
          return false;
        },
        child: CustomScrollView(
          controller: _scroll,
          slivers: [
            SliverAppBar(
              systemOverlayStyle: _collapsed && !darkTheme
                  ? SystemUiOverlayStyle.dark
                  : SystemUiOverlayStyle.light,
              expandedHeight: heroHeight,
              pinned: true,
              stretch: true,
              backgroundColor: scheme.surfaceContainerLowest,
              automaticallyImplyLeading: false,
              leading: Padding(
                padding: const EdgeInsets.all(8),
                child: _GlassButton(
                  icon: Icons.arrow_back_rounded,
                  tooltip: MaterialLocalizations.of(context).backButtonTooltip,
                  onPressed: () => context.pop(),
                ),
              ),
              actions: [
                Padding(
                  padding: const EdgeInsets.all(8),
                  child: _GlassButton(
                    icon: isFav ? Icons.favorite : Icons.favorite_border,
                    color: isFav ? scheme.primary : null,
                    tooltip:
                        isFav ? l10n.removeFromFavorites : l10n.addToFavorites,
                    onPressed: toggleFavorite,
                  ),
                ),
              ],
              flexibleSpace: FlexibleSpaceBar(
                stretchModes: const [StretchMode.zoomBackground],
                background: Stack(
                  fit: StackFit.expand,
                  children: [
                    Hero(
                      tag: placePhotoHeroTag(place.id),
                      child: PlacePhoto(place: place),
                    ),
                    if (place.photoCredits.isNotEmpty)
                      Positioned(
                        left: AppSizes.screenEdge,
                        right: AppSizes.screenEdge * 3,
                        bottom: AppSizes.radiusLg + AppSizes.space8,
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: PhotoCreditChip(credits: place.photoCredits),
                        ),
                      ),
                  ],
                ),
              ),
              // Rounded top edge of the content sheet, overlapping the photo.
              bottom: PreferredSize(
                preferredSize: const Size.fromHeight(AppSizes.radiusLg),
                child: Container(
                  height: AppSizes.radiusLg,
                  decoration: BoxDecoration(
                    color: scheme.surfaceContainerLowest,
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(AppSizes.radiusLg),
                    ),
                  ),
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(
                AppSizes.screenEdge + 2,
                0,
                AppSizes.screenEdge + 2,
                AppSizes.space32,
              ),
              sliver: SliverList.list(
                children: [
                  Text(place.name, style: text.headlineMedium),
                  const SizedBox(height: AppSizes.space8),
                  _MetaRow(place: place),
                  if (tags.isNotEmpty) ...[
                    const SizedBox(height: AppSizes.space16),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [for (final t in tags) _SoftTag(label: t)],
                    ),
                  ],
                  for (final prompt in place.prompts) ...[
                    const SizedBox(height: AppSizes.space12),
                    PromptTile(prompt: prompt),
                  ],
                  if (description.isNotEmpty) ...[
                    const SizedBox(height: AppSizes.groupGap),
                    Text(
                      description,
                      style: text.bodyLarge?.copyWith(
                        color: scheme.onSurfaceVariant,
                        height: 1.6,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: _ActionBar(
        isFav: isFav,
        onToggleFavorite: toggleFavorite,
        onOpenMaps: () async {
          // iOS users choose between Apple Maps and Google Maps.
          final app = Theme.of(context).platform == TargetPlatform.iOS
              ? await showMapsAppSheet(context)
              : MapsApp.google;
          if (app == null) return;
          try {
            await MapsLauncher.open(app, place.lat, place.lng, place.name);
          } catch (e) {
            if (!context.mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  userMessage(e, fallback: l10n.errorOpenMaps, l10n: l10n),
                ),
              ),
            );
          }
        },
      ),
    );
  }
}

class _MetaRow extends StatelessWidget {
  const _MetaRow({required this.place});

  final PlaceModel place;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final style = Theme.of(context)
        .textTheme
        .bodyMedium
        ?.copyWith(color: scheme.onSurfaceVariant);
    final rating = place.averageRating;
    final address = place.address?.trim();
    return Wrap(
      spacing: AppSizes.space12,
      runSpacing: AppSizes.space4,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        if (rating != null && rating > 0)
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.star_rounded,
                  size: 18, color: context.swipeColors.gold),
              const SizedBox(width: 2),
              Text(
                rating.toStringAsFixed(1),
                style: style?.copyWith(
                  color: scheme.onSurface,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.place_outlined,
                size: 16, color: scheme.onSurfaceVariant),
            const SizedBox(width: 4),
            Flexible(
              child: Text(
                (address != null && address.isNotEmpty)
                    ? address
                    : '${place.lat.toStringAsFixed(4)}, '
                        '${place.lng.toStringAsFixed(4)}',
                style: style,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _SoftTag extends StatelessWidget {
  const _SoftTag({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelLarge?.copyWith(
              fontWeight: FontWeight.w600,
              color: scheme.onSurface,
            ),
      ),
    );
  }
}

/// Round, light button that floats on top of the photo.
class _GlassButton extends StatelessWidget {
  const _GlassButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.color,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: PhotoColors.glass,
      shape: const CircleBorder(),
      child: IconButton(
        tooltip: tooltip,
        icon: Icon(icon, color: color ?? PhotoColors.onGlass, size: 20),
        onPressed: onPressed,
      ),
    );
  }
}

class _ActionBar extends StatelessWidget {
  const _ActionBar({
    required this.isFav,
    required this.onToggleFavorite,
    required this.onOpenMaps,
  });

  final bool isFav;
  final VoidCallback onToggleFavorite;
  final VoidCallback onOpenMaps;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final l10n = context.l10n;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: scheme.surface,
        border: Border(top: BorderSide(color: scheme.outlineVariant)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSizes.screenEdge,
            AppSizes.space12,
            AppSizes.screenEdge,
            AppSizes.space12,
          ),
          child: Row(
            children: [
              SizedBox(
                width: 52,
                height: 52,
                child: OutlinedButton(
                  onPressed: onToggleFavorite,
                  style: OutlinedButton.styleFrom(
                    padding: EdgeInsets.zero,
                    minimumSize: const Size(52, 52),
                  ),
                  child: Icon(
                    isFav ? Icons.favorite : Icons.favorite_border,
                    color: scheme.primary,
                    semanticLabel:
                        isFav ? l10n.removeFromFavorites : l10n.addToFavorites,
                  ),
                ),
              ),
              const SizedBox(width: AppSizes.space8),
              Expanded(
                child: FilledButton.icon(
                  onPressed: onOpenMaps,
                  style: FilledButton.styleFrom(
                    backgroundColor: scheme.onSurface,
                    foregroundColor: scheme.surface,
                  ),
                  icon: const Icon(Icons.map_outlined),
                  label: Text(l10n.openInMaps),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
