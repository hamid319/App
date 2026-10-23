import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../common/models/place_model.dart';
import '../../../common/utils/place_type_labels.dart';
import '../../../common/widgets/place_photo.dart';
import '../../../common/widgets/ticket.dart';
import '../../../core/constants/sizes.dart';
import '../../../l10n/l10n.dart';

/// Height of the ticket stub under the photo (name + type).
const double placeTicketStubHeight = 82;

/// Pastel per category, cycled so neighbouring tiles differ.
const placeTicketTones = [ChipTone.mint, ChipTone.sky, ChipTone.peach];

/// First readable type label of [place], for the tile chip.
String? placeCategoryLabel(BuildContext context, PlaceModel place) {
  final labels = placeTypeLabels(context.l10n, place.types);
  return labels.isEmpty ? null : labels.first;
}

/// Paper ticket with the place photo on top, a perforation and a stub with
/// name and category chip. Tapping opens the place detail. Used by the
/// favorites grid, the home sliders and the collection grids.
class PlaceTicketTile extends StatelessWidget {
  const PlaceTicketTile({
    super.key,
    required this.place,
    this.subtitle,
    this.tone = ChipTone.mint,
    this.overlay,
    this.hero = true,
  });

  final PlaceModel place;
  final String? subtitle;
  final ChipTone tone;

  /// Placed in the photo's top right corner (e.g. the favorite button).
  final Widget? overlay;

  /// Fly the photo into the detail page. Turn off where the same place can
  /// appear twice on one screen.
  final bool hero;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final name = place.nameFor(Localizations.localeOf(context).languageCode);
    final photo = PlacePhoto(place: place);
    return Ticket(
      onTap: () => context.push('/place/${place.id}'),
      notchFromBottom: placeTicketStubHeight,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: Stack(
              fit: StackFit.expand,
              children: [
                hero
                    ? Hero(tag: placePhotoHeroTag(place.id), child: photo)
                    : photo,
                if (overlay != null)
                  Positioned(
                    top: AppSizes.space8,
                    right: AppSizes.space8,
                    child: overlay!,
                  ),
              ],
            ),
          ),
          SizedBox(
            height: placeTicketStubHeight,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSizes.space12,
                AppSizes.space8 + 2,
                AppSizes.space12,
                AppSizes.space8,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style:
                        text.bodyMedium?.copyWith(fontWeight: FontWeight.w800),
                  ),
                  if (subtitle != null)
                    Flexible(child: TagChip(label: subtitle!, tone: tone)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
