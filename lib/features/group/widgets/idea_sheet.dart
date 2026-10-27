import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../common/models/group_model.dart';
import '../../../common/models/place_model.dart';
import '../../../common/widgets/place_photo.dart';
import '../../../l10n/l10n.dart';
import '../logic/trip_controller.dart';
import 'trip_ui.dart';

/// Sheet to add an idea to the wishlist: free text or a link, or one of the
/// city's places (only those can go into the day plan).
Future<void> showIdeaSheet(BuildContext context, GroupModel group) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Theme.of(context).scaffoldBackgroundColor,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (_) => _IdeaSheet(group: group),
  );
}

class _IdeaSheet extends ConsumerStatefulWidget {
  const _IdeaSheet({required this.group});

  final GroupModel group;

  @override
  ConsumerState<_IdeaSheet> createState() => _IdeaSheetState();
}

class _IdeaSheetState extends ConsumerState<_IdeaSheet> {
  final _title = TextEditingController();

  @override
  void dispose() {
    _title.dispose();
    super.dispose();
  }

  void _add({PlaceModel? place}) {
    final lang = Localizations.localeOf(context).languageCode;
    final title = place?.nameFor(lang) ?? _title.text.trim();
    if (title.isEmpty) return;
    final actions = ref.read(tripActionsProvider.notifier);
    final groupId = widget.group.groupId;
    // Not awaited: the wishlist shows the idea at once, offline too.
    runTripWrite(
        context, () => actions.addIdea(groupId, title, placeId: place?.id));
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final lang = Localizations.localeOf(context).languageCode;
    final query = _title.text.trim().toLowerCase();
    final cityPlaces =
        ref.watch(tripCityPlacesProvider(tripCityKey(widget.group))).value ??
            const <PlaceModel>[];
    final suggestions = cityPlaces
        .where((p) =>
            query.isEmpty || p.nameFor(lang).toLowerCase().contains(query))
        .take(8)
        .toList();

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: ConstrainedBox(
        constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(context).height * 0.85),
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          children: [
            Text(l10n.tripAddIdeaTitle, style: text.headlineSmall),
            const SizedBox(height: 12),
            TextField(
              controller: _title,
              autofocus: true,
              maxLength: 120,
              textInputAction: TextInputAction.done,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(
                hintText: l10n.tripIdeaHint,
                counterText: '',
              ),
              onChanged: (_) => setState(() {}),
              onSubmitted: (_) => _add(),
            ),
            const SizedBox(height: 12),
            FloatingPrimaryButton(
              label: l10n.tripAddIdeaButton,
              icon: Icons.add_rounded,
              onPressed: query.isEmpty ? null : () => _add(),
            ),
            if (suggestions.isNotEmpty) ...[
              const SizedBox(height: 20),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Text(
                  l10n.tripIdeaSuggestions(widget.group.location?.cityName ?? ''),
                  style:
                      text.labelSmall?.copyWith(color: scheme.onSurfaceVariant),
                ),
              ),
              const SizedBox(height: 8),
              InsetGroup(
                separatorIndent: 14 + 40 + 12,
                children: [
                  for (final place in suggestions)
                    InkWell(
                      onTap: () => _add(place: place),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 8),
                        child: Row(
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: SizedBox.square(
                                  dimension: 40,
                                  child: PlacePhoto(place: place)),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(place.nameFor(lang),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: text.bodyLarge),
                            ),
                            Icon(Icons.add_circle_outline_rounded,
                                color: scheme.primary),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
