import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/errors/user_message.dart';
import '../../l10n/l10n.dart';
import '../../main_providers.dart';
import '../models/group_model.dart';
import '../models/place_model.dart';
import '../utils/trip_dates.dart';
import '../utils/trip_days.dart';

/// "Add to trip" for a place, from the place detail and the place tiles of
/// the home feed and favorites: lists the user's trips (upcoming first) and
/// puts the place on the chosen trip's wishlist. Trips that already have it
/// show a check mark instead of adding it twice.
///
/// Lives in common/ because the places and home features use it; it talks
/// to the trip data through the global providers in main_providers.dart,
/// not through the group feature.
Future<void> showAddToTripSheet(BuildContext context, PlaceModel place) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Theme.of(context).scaffoldBackgroundColor,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (_) => AddToTripSheet(place: place),
  );
}

class AddToTripSheet extends ConsumerWidget {
  const AddToTripSheet({super.key, required this.place});

  final PlaceModel place;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final lang = Localizations.localeOf(context).languageCode;
    final account = ref.watch(currentAccountProvider);
    final trips = ref.watch(myTripsProvider);

    final Widget body;
    if (!account.hasValue && !account.hasError ||
        !trips.hasValue && !trips.hasError) {
      body = const Padding(
        padding: EdgeInsets.all(32),
        child: Center(child: CircularProgressIndicator()),
      );
    } else if (trips.hasError) {
      body = Text(
        userMessage(trips.error!, fallback: l10n.errorLoadGroups, l10n: l10n),
        style: text.bodyMedium?.copyWith(color: scheme.error),
      );
    } else {
      final me = account.value;
      final all = trips.value ?? const <GroupModel>[];
      if (me == null || me.isGuest || all.isEmpty) {
        body = _NoTrips(onCreate: () {
          final router = GoRouter.of(context);
          Navigator.pop(context);
          // Guests land on the account prompt of the trips tab.
          router.go('/trips?create=1');
        });
      } else {
        final split = splitTrips(all, DateTime.now());
        body = Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _TripGroup(
              place: place,
              uid: me.uid,
              trips: split.upcoming,
            ),
            if (split.past.isNotEmpty) ...[
              const SizedBox(height: 16),
              Padding(
                padding: const EdgeInsets.only(left: 4, bottom: 6),
                child: Text(
                  l10n.tripsPast,
                  style:
                      text.labelSmall?.copyWith(color: scheme.onSurfaceVariant),
                ),
              ),
              _TripGroup(place: place, uid: me.uid, trips: split.past),
            ],
          ],
        );
      }
    }

    return ConstrainedBox(
      constraints:
          BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.8),
      child: ListView(
        shrinkWrap: true,
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        children: [
          Text(l10n.addToTrip, style: text.headlineSmall),
          const SizedBox(height: 2),
          Text(
            place.nameFor(lang),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: text.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
          ),
          const SizedBox(height: 16),
          body,
        ],
      ),
    );
  }
}

/// iOS-style inset group of trip rows.
class _TripGroup extends StatelessWidget {
  const _TripGroup({
    required this.place,
    required this.uid,
    required this.trips,
  });

  final PlaceModel place;
  final String uid;
  final List<GroupModel> trips;

  @override
  Widget build(BuildContext context) {
    if (trips.isEmpty) return const SizedBox.shrink();
    final scheme = Theme.of(context).colorScheme;
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: Material(
        color: scheme.surface,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final (i, trip) in trips.indexed) ...[
              if (i > 0)
                Padding(
                  padding: const EdgeInsets.only(left: 14 + 40 + 12),
                  child: Divider(
                      height: 0.5, thickness: 0.5, color: scheme.outlineVariant),
                ),
              _TripRow(place: place, uid: uid, trip: trip),
            ],
          ],
        ),
      ),
    );
  }
}

class _TripRow extends ConsumerWidget {
  const _TripRow({required this.place, required this.uid, required this.trip});

  final PlaceModel place;
  final String uid;
  final GroupModel trip;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final locale = Localizations.localeOf(context).toLanguageTag();
    final added = ref
        .watch(placeInTripProvider((groupId: trip.groupId, placeId: place.id)));
    final isAdded = added.value ?? false;
    final name = trip.groupName ?? l10n.unnamedGroup;
    final subtitle = trip.tripStart != null
        ? formatTripDates(trip.tripStart!, trip.tripEnd, locale)
        : trip.location?.cityName;

    void choose() {
      final messenger = ScaffoldMessenger.of(context);
      final router = GoRouter.of(context);
      final errorColor = scheme.error;
      final title = place.nameFor(Localizations.localeOf(context).languageCode);
      if (!isAdded) {
        // Not awaited: Firestore shows the idea at once and sends it when
        // online; the sheet does not wait for the server.
        ref
            .read(tripRepositoryProvider)
            .addPlaceIdea(trip.groupId,
                placeId: place.id, title: title, uid: uid)
            .catchError((Object e) {
          messenger.showSnackBar(SnackBar(
            content: Text(
                userMessage(e, fallback: l10n.errorGeneric, l10n: l10n)),
            backgroundColor: errorColor,
          ));
          return (id: '', added: false);
        });
      }
      Navigator.pop(context);
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(
          content: Text(isAdded
              ? l10n.addToTripAlready(name)
              : l10n.addToTripSaved(name)),
          action: SnackBarAction(
            label: l10n.addToTripOpen,
            onPressed: () => router.push('/trip/${trip.groupId}'),
          ),
        ));
    }

    return InkWell(
      onTap: added.hasValue ? choose : null,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: scheme.surfaceContainerHigh,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(Icons.luggage_rounded,
                  size: 20, color: scheme.onSurfaceVariant),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: text.titleMedium?.copyWith(fontSize: 16)),
                  if (subtitle != null && subtitle.isNotEmpty)
                    Text(subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: text.labelSmall
                            ?.copyWith(color: scheme.onSurfaceVariant)),
                ],
              ),
            ),
            const SizedBox(width: 8),
            isAdded
                ? Semantics(
                    label: l10n.addToTripAdded,
                    child: Icon(Icons.check_circle_rounded,
                        color: scheme.primary),
                  )
                : Icon(Icons.add_circle_outline_rounded,
                    color: scheme.primary),
          ],
        ),
      ),
    );
  }
}

class _NoTrips extends StatelessWidget {
  const _NoTrips({required this.onCreate});

  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          l10n.addToTripNoTrips,
          style: text.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
        ),
        const SizedBox(height: 16),
        ElevatedButton.icon(
          onPressed: onCreate,
          icon: const Icon(Icons.add_rounded),
          label: Text(l10n.addToTripCreate),
        ),
      ],
    );
  }
}
