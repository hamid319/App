import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../app/theme.dart';
import '../../../common/models/place_model.dart';
import '../../../common/utils/opening_hours_format.dart';
import '../../../common/utils/place_type_labels.dart';
import '../../../common/widgets/place_photo.dart';
import '../../../common/widgets/skeleton.dart';
import '../../../common/widgets/ticket.dart';
import '../../../core/constants/popular_cities.dart';
import '../../../core/constants/sizes.dart';
import '../../../core/errors/user_message.dart';
import '../../../core/services/link_launcher.dart';
import '../../../core/services/maps_launcher.dart';
import '../../../l10n/l10n.dart';
import '../../swipe/data/places_repository.dart';
import '../../swipe/logic/swipe_controller.dart';
import '../widgets/maps_app_sheet.dart';
import '../widgets/photo_credits.dart';
import '../widgets/place_reviews_section.dart';
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
        icon: Icons.error_outline_rounded,
        tone: ChipTone.peach,
        text: userMessage(
          error,
          fallback: context.l10n.errorLoadPlace,
          l10n: context.l10n,
        ),
      ),
      data: (place) => place == null
          ? _Message(
              icon: Icons.wrong_location_outlined,
              tone: ChipTone.sky,
              text: context.l10n.placeNotFound,
            )
          : _PlaceDetailContent(place: place),
    );
  }
}

class _Message extends StatelessWidget {
  const _Message({
    required this.icon,
    required this.tone,
    required this.text,
  });

  final IconData icon;
  final ChipTone tone;
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
              IconBadge(icon: icon, tone: tone),
              const SizedBox(height: AppSizes.space24),
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
/// Hero), round ink-rimmed buttons on it, the place as a perforated ticket
/// below, and the main action pinned at the bottom.
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
    final lang = Localizations.localeOf(context).languageCode;
    final name = place.nameFor(lang);
    final description = place.descriptionFor(lang)?.trim() ?? '';
    final wikipediaUrl = place.wikipediaUrlFor(lang);
    final heroHeight = MediaQuery.sizeOf(context).height * 0.42;
    final darkTheme = Theme.of(context).brightness == Brightness.dark;
    const tones = [ChipTone.mint, ChipTone.sky, ChipTone.peach];
    final hasFacts = place.openingHours != null || place.website != null;
    final hasSources = wikipediaUrl != null ||
        place.osmUrl != null ||
        place.photoCredits.isNotEmpty;

    Future<void> toggleFavorite() async {
      final messenger = ScaffoldMessenger.of(context);
      if (isFav) {
        await swipeCtrl.removeFavorite(place.id);
        messenger.showSnackBar(
          SnackBar(content: Text(l10n.placeRemovedFromFavorites(name))),
        );
      } else {
        await swipeCtrl.addFavorite(place.id);
        messenger.showSnackBar(
          SnackBar(content: Text(l10n.placeAddedToFavorites(name))),
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
              leadingWidth: 64,
              leading: Center(
                child: InkActionButton(
                  icon: Icons.arrow_back_rounded,
                  size: 42,
                  tooltip: MaterialLocalizations.of(context).backButtonTooltip,
                  onPressed: () => context.pop(),
                ),
              ),
              actions: [
                Padding(
                  padding: const EdgeInsets.only(right: AppSizes.screenEdge),
                  child: InkActionButton(
                    icon: isFav
                        ? Icons.favorite_rounded
                        : Icons.favorite_border_rounded,
                    size: 42,
                    iconColor: isFav ? context.swipeColors.like : null,
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
                        bottom: AppSizes.space12,
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: PhotoCreditChip(credits: place.photoCredits),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(
                AppSizes.screenEdge,
                AppSizes.space16,
                AppSizes.screenEdge,
                AppSizes.space32,
              ),
              sliver: SliverList.list(
                children: [
                  _PerforatedTicket(
                    header: Padding(
                      padding: const EdgeInsets.fromLTRB(
                        AppSizes.space16 + 4,
                        AppSizes.space16 + 4,
                        AppSizes.space16 + 4,
                        AppSizes.space16 + 2,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(name, style: text.headlineMedium),
                          _MetaRow(place: place),
                          if (tags.isNotEmpty) ...[
                            const SizedBox(height: AppSizes.space12),
                            Wrap(
                              spacing: 6,
                              runSpacing: 6,
                              children: [
                                for (final (i, t) in tags.indexed)
                                  TagChip(
                                      label: t, tone: tones[i % tones.length]),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                    body: description.isEmpty
                        ? null
                        : Padding(
                            padding: const EdgeInsets.fromLTRB(
                              AppSizes.space16 + 4,
                              AppSizes.space16 + 2,
                              AppSizes.space16 + 4,
                              AppSizes.space16 + 4,
                            ),
                            child: Text(
                              description,
                              style: text.bodyLarge?.copyWith(
                                color: scheme.onSurfaceVariant,
                                height: 1.6,
                              ),
                            ),
                          ),
                  ),
                  for (final prompt in place.prompts) ...[
                    const SizedBox(height: AppSizes.space12),
                    PromptTile(prompt: prompt),
                  ],
                  if (hasFacts) ...[
                    const SizedBox(height: AppSizes.groupGap),
                    SectionLabel(l10n.placeSectionInfo),
                    _PlaceFacts(place: place),
                  ],
                  const SizedBox(height: AppSizes.groupGap),
                  PlaceReviewsSection(placeId: place.id),
                  if (hasSources) ...[
                    const SizedBox(height: AppSizes.groupGap),
                    SectionLabel(l10n.placeSectionSources),
                    _Sources(place: place, wikipediaUrl: wikipediaUrl),
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
            await MapsLauncher.open(app, place.lat, place.lng, name);
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

/// A ticket whose perforation sits exactly between [header] and [body]. The
/// header is measured after layout, so the notch follows its real height.
class _PerforatedTicket extends StatefulWidget {
  const _PerforatedTicket({required this.header, this.body});

  final Widget header;
  final Widget? body;

  @override
  State<_PerforatedTicket> createState() => _PerforatedTicketState();
}

class _PerforatedTicketState extends State<_PerforatedTicket> {
  final _headerKey = GlobalKey();
  double? _notch;

  void _measure() {
    final box = _headerKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize) return;
    final y = box.size.height;
    if (_notch == null || (y - _notch!).abs() > 0.5) {
      setState(() => _notch = y);
    }
  }

  @override
  Widget build(BuildContext context) {
    final body = widget.body;
    if (body != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _measure();
      });
    }
    return Ticket(
      raised: true,
      notchFromTop: body == null ? null : _notch,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          KeyedSubtree(key: _headerKey, child: widget.header),
          if (body != null) body,
        ],
      ),
    );
  }
}

/// Rating and where the place is: the street address when the import has
/// one, otherwise the city. Never raw coordinates.
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
    final location = (address != null && address.isNotEmpty)
        ? address
        : PopularCity.byId(place.cityId)
            ?.nameFor(Localizations.localeOf(context).languageCode);
    final showRating = rating != null && rating > 0;
    if (!showRating && location == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: AppSizes.space8),
      child: Wrap(
        spacing: AppSizes.space12,
        runSpacing: AppSizes.space4,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          if (showRating)
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
          if (location != null)
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.place_outlined,
                    size: 16, color: scheme.onSurfaceVariant),
                const SizedBox(width: 4),
                Flexible(child: Text(location, style: style)),
              ],
            ),
        ],
      ),
    );
  }
}

Future<void> _openLink(BuildContext context, String url) async {
  final l10n = context.l10n;
  try {
    await LinkLauncher.open(url);
  } catch (e) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(userMessage(e, fallback: l10n.errorOpenLink, l10n: l10n)),
      ),
    );
  }
}

/// One row inside an info ticket: icon, small label, value.
class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.icon,
    required this.value,
    this.label,
    this.onTap,
  });

  final IconData icon;
  final String? label;
  final String value;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final content = Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSizes.space16,
        vertical: AppSizes.space12,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: scheme.onSurface),
          const SizedBox(width: AppSizes.space12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (label != null) ...[
                  Text(label!,
                      style: text.labelMedium
                          ?.copyWith(color: scheme.onSurfaceVariant)),
                  const SizedBox(height: 2),
                ],
                Text(
                  value,
                  style: text.bodyMedium?.copyWith(
                    color: scheme.onSurface,
                    decoration: onTap == null ? null : TextDecoration.underline,
                    decorationColor: scheme.onSurface,
                  ),
                ),
              ],
            ),
          ),
          if (onTap != null)
            Icon(Icons.north_east_rounded,
                size: 16, color: scheme.onSurfaceVariant),
        ],
      ),
    );
    return onTap == null ? content : InkWell(onTap: onTap, child: content);
  }
}

/// Rows separated by hairlines inside one ticket.
class _RowsTicket extends StatelessWidget {
  const _RowsTicket({required this.rows});

  final List<Widget> rows;

  @override
  Widget build(BuildContext context) {
    return Ticket(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final (i, row) in rows.indexed) ...[
            if (i > 0) const Divider(height: 1),
            row,
          ],
        ],
      ),
    );
  }
}

/// Opening hours and website from OpenStreetMap.
class _PlaceFacts extends StatelessWidget {
  const _PlaceFacts({required this.place});

  final PlaceModel place;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final hours = place.openingHours;
    final website = place.website;
    return _RowsTicket(
      rows: [
        if (hours != null)
          _InfoRow(
            icon: Icons.schedule_rounded,
            label: l10n.openingHoursLabel,
            value: formatOpeningHours(hours, l10n),
          ),
        if (website != null)
          _InfoRow(
            icon: Icons.language_rounded,
            label: l10n.websiteLabel,
            value:
                Uri.tryParse(website)?.host.replaceFirst('www.', '') ?? website,
            onTap: () => _openLink(context, website),
          ),
      ],
    );
  }
}

/// Where text, photos and facts come from (Wikipedia CC BY-SA, photo
/// licences, OpenStreetMap ODbL all require naming and linking them).
class _Sources extends StatelessWidget {
  const _Sources({required this.place, required this.wikipediaUrl});

  final PlaceModel place;
  final String? wikipediaUrl;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final wiki = wikipediaUrl;
    final osm = place.osmUrl;
    return _RowsTicket(
      rows: [
        if (place.photoCredits.isNotEmpty)
          _InfoRow(
            icon: Icons.photo_camera_outlined,
            value: l10n.photoCreditsTitle,
            onTap: () => showPhotoCredits(context, place.photoCredits),
          ),
        if (wiki != null)
          _InfoRow(
            icon: Icons.article_outlined,
            value: l10n.textSourceWikipedia,
            onTap: () => _openLink(context, wiki),
          ),
        if (osm != null)
          _InfoRow(
            icon: Icons.map_outlined,
            value: l10n.osmAttribution,
            onTap: () => _openLink(context, osm),
          ),
      ],
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
        color: Theme.of(context).scaffoldBackgroundColor,
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
              InkActionButton(
                icon: isFav
                    ? Icons.favorite_rounded
                    : Icons.favorite_border_rounded,
                size: 52,
                iconColor: isFav ? context.swipeColors.like : null,
                tooltip: isFav ? l10n.removeFromFavorites : l10n.addToFavorites,
                onPressed: onToggleFavorite,
              ),
              const SizedBox(width: AppSizes.space12),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: onOpenMaps,
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
