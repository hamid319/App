import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';

import '../../../common/models/group_model.dart';
import '../../../common/models/journal_entry.dart';
import '../../../common/utils/money.dart';
import '../../../common/utils/trip_journal.dart';
import '../../../common/widgets/error_view.dart';
import '../../../common/widgets/places_map.dart';
import '../../../core/errors/user_message.dart';
import '../../../l10n/l10n.dart';
import '../logic/trip_controller.dart';
import '../widgets/journal_photos.dart';
import '../widgets/recap_share_card.dart';
import '../widgets/trip_ui.dart';

/// Looking back on a trip: numbers, a photo collage, the planned places
/// on a map, and a picture of it all to share.
class RecapScreen extends ConsumerWidget {
  const RecapScreen({super.key, required this.groupId});

  final String groupId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final trip = ref.watch(tripProvider(groupId));
    final journal = ref.watch(tripJournalProvider(groupId));
    Widget withBack(Widget child) =>
        WithBackButton(fallbackRoute: '/trip/$groupId/journal', child: child);

    return Scaffold(
      body: trip.when(
        loading: () =>
            withBack(const Center(child: CircularProgressIndicator())),
        error: (e, _) => withBack(ErrorView(
          message: userMessage(e, fallback: l10n.errorGeneric, l10n: l10n),
        )),
        data: (group) {
          if (group == null) {
            return ErrorView(
              message: l10n.groupNotFound,
              onRetry: () => context.go('/trips'),
            );
          }
          return journal.when(
            loading: () =>
                withBack(const Center(child: CircularProgressIndicator())),
            error: (e, _) => withBack(ErrorView(
              message: userMessage(e, fallback: l10n.errorGeneric, l10n: l10n),
              onRetry: () => ref.invalidate(tripJournalProvider(groupId)),
            )),
            data: (entries) => _RecapBody(group: group, entries: entries),
          );
        },
      ),
    );
  }
}

class _RecapBody extends ConsumerStatefulWidget {
  const _RecapBody({required this.group, required this.entries});

  final GroupModel group;
  final List<JournalEntry> entries;

  @override
  ConsumerState<_RecapBody> createState() => _RecapBodyState();
}

class _RecapBodyState extends ConsumerState<_RecapBody> {
  bool _sharing = false;

  Future<void> _share(
      String subtitle, TripRecapStats stats, List<JournalPhoto> photos) async {
    final l10n = context.l10n;
    final box = context.findRenderObject() as RenderBox?;
    final origin =
        box == null ? null : box.localToGlobal(Offset.zero) & box.size;
    final shown = photos.take(4).toList();
    setState(() => _sharing = true);
    try {
      // The capture must not catch empty placeholders.
      await Future.wait([
        for (final p in shown)
          precacheImage(CachedNetworkImageProvider(p.url), context),
      ]);
      if (!mounted) return;
      final png = await captureRecapCard(
        context,
        RecapShareCard(
          title: widget.group.groupName ?? l10n.unnamedGroup,
          subtitle: subtitle,
          photos: shown,
          stats: [
            (stats.days, l10n.recapStatDays(stats.days)),
            (stats.places, l10n.recapStatPlaces(stats.places)),
            (stats.photos, l10n.recapStatPhotos(stats.photos)),
            (stats.members, l10n.recapStatMembers(stats.members)),
          ],
        ),
      );
      await SharePlus.instance.share(ShareParams(
        files: [
          XFile.fromData(png, mimeType: 'image/png', name: 'tripfam-recap.png'),
        ],
        sharePositionOrigin: origin,
      ));
    } catch (e) {
      if (mounted) {
        showTripSnack(
            context, userMessage(e, fallback: l10n.recapShareError, l10n: l10n),
            error: true);
      }
    } finally {
      if (mounted) setState(() => _sharing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final group = widget.group;
    final entries = widget.entries;
    final l10n = context.l10n;
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final locale = Localizations.localeOf(context).toLanguageTag();
    final expenses =
        ref.watch(tripExpensesProvider(group.groupId)).value ?? const [];
    final ideas = ref.watch(tripIdeasProvider(group.groupId)).value ?? const [];
    final stats = tripRecapStats(group,
        entries: entries, expenses: expenses, ideaCount: ideas.length);
    final photos = recapPhotos(entries);
    final subtitle = [
      tripDatesLabel(context, group),
      group.location?.cityName,
    ].whereType<String>().where((s) => s.isNotEmpty).join(' · ');
    final planIds = group.tripPlan?.allPlaceIds ?? const <String>[];
    final places = planIds.isEmpty
        ? null
        : ref.watch(tripPlacesProvider(placesKey(planIds))).value;
    final mapsReady = ref.watch(mapsConfiguredProvider).value == true;

    Widget stat(int value, String label) => Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('$value', style: text.headlineSmall),
              Text(label,
                  style: text.bodyMedium
                      ?.copyWith(color: scheme.onSurfaceVariant)),
            ],
          ),
        );

    return ListView(
      padding: EdgeInsets.fromLTRB(
          16, MediaQuery.paddingOf(context).top + 8, 16, 40),
      children: [
        Row(
          children: [
            GlassButton(
              icon: Icons.arrow_back_ios_new_rounded,
              tooltip: l10n.back,
              opacity: 1,
              onTap: () => context.canPop()
                  ? context.pop()
                  : context.go('/trip/${group.groupId}/journal'),
            ),
            const Spacer(),
            _sharing
                ? const Padding(
                    padding: EdgeInsets.all(12),
                    child: SizedBox.square(
                        dimension: 20,
                        child: CircularProgressIndicator(strokeWidth: 2)),
                  )
                : GlassButton(
                    icon: Icons.ios_share_rounded,
                    tooltip: l10n.recapShare,
                    label: l10n.recapShare,
                    opacity: 1,
                    onTap: () => _share(subtitle, stats, photos),
                  ),
          ],
        ),
        const SizedBox(height: 16),
        Text(l10n.recapTitle, style: text.displaySmall),
        const SizedBox(height: 4),
        Text(group.groupName ?? l10n.unnamedGroup, style: text.headlineSmall),
        if (subtitle.isNotEmpty)
          Text(subtitle,
              style: text.bodyMedium?.copyWith(color: scheme.onSurfaceVariant)),
        const SizedBox(height: 16),
        TripCard(
          radius: 18,
          child: Column(
            children: [
              Row(children: [
                stat(stats.days, l10n.recapStatDays(stats.days)),
                stat(stats.members, l10n.recapStatMembers(stats.members)),
              ]),
              const SizedBox(height: 12),
              Row(children: [
                stat(stats.places, l10n.recapStatPlaces(stats.places)),
                stat(stats.photos, l10n.recapStatPhotos(stats.photos)),
              ]),
              const Divider(height: 28),
              Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Expanded(
                      child: Text(l10n.recapTotalCosts, style: text.bodyLarge)),
                  Text(formatCents(stats.totalCents, locale),
                      style: text.titleMedium),
                ],
              ),
              if (stats.members > 1)
                Align(
                  alignment: Alignment.centerRight,
                  child: Text(
                    l10n.recapPerPerson(
                        formatCents(stats.perPersonCents, locale)),
                    style: text.bodyMedium
                        ?.copyWith(color: scheme.onSurfaceVariant),
                  ),
                ),
            ],
          ),
        ),
        if (photos.isNotEmpty) ...[
          const SizedBox(height: 16),
          ClipRRect(
            borderRadius: BorderRadius.circular(18),
            child: GridView.count(
              crossAxisCount: photos.length == 1
                  ? 1
                  : (photos.length == 2 || photos.length == 4 ? 2 : 3),
              mainAxisSpacing: 2,
              crossAxisSpacing: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              children: [
                for (final (i, p) in photos.indexed)
                  GestureDetector(
                    onTap: () =>
                        showJournalPhotoViewer(context, photos, initial: i),
                    child: Semantics(
                      button: true,
                      label: l10n.journalPhotoOf(i + 1, photos.length),
                      child: JournalImage(photo: p),
                    ),
                  ),
              ],
            ),
          ),
        ],
        if (mapsReady && places != null && places.isNotEmpty) ...[
          const SizedBox(height: 24),
          TripSectionHeader(l10n.recapPlaces),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(18),
            child: SizedBox(
              height: 280,
              child: PlacesMap(
                places: places,
                onTapPlace: (place) => context.push('/place/${place.id}'),
              ),
            ),
          ),
        ],
      ],
    );
  }
}
