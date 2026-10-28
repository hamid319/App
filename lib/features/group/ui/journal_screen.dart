import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../common/models/group_model.dart';
import '../../../common/models/journal_entry.dart';
import '../../../common/utils/trip_days.dart';
import '../../../common/utils/trip_journal.dart';
import '../../../common/widgets/error_view.dart';
import '../../../common/widgets/member_avatar.dart';
import '../../../common/widgets/ticket.dart';
import '../../../core/errors/user_message.dart';
import '../../../l10n/l10n.dart';
import '../../auth/logic/auth_controller.dart';
import '../logic/trip_controller.dart';
import '../widgets/journal_entry_sheet.dart';
import '../widgets/journal_photos.dart';
import '../widgets/sync_badge.dart';
import '../widgets/trip_ui.dart';
import 'trip_detail_screen.dart';

/// The trip journal: everyone's notes and photos, grouped by trip day.
class JournalScreen extends ConsumerWidget {
  const JournalScreen({super.key, required this.groupId});

  final String groupId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final trip = ref.watch(tripProvider(groupId));
    final uid = ref.watch(authControllerProvider).value?.uid ?? '';

    Widget withBack(Widget child) =>
        WithBackButton(fallbackRoute: '/trip/$groupId', child: child);

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
          final journal = ref.watch(tripJournalProvider(groupId));
          final entries = journal.value ?? const <JournalEntry>[];
          final canRecap = entries.isNotEmpty ||
              isTripOver(group.tripStart, group.tripEnd, DateTime.now());
          final add = FloatingPrimaryButton(
            label: l10n.journalAddEntry,
            icon: Icons.add_rounded,
            onPressed: () => showJournalEntrySheet(context, group),
          );
          return Stack(
            children: [
              journal.when(
                loading: () =>
                    withBack(const Center(child: CircularProgressIndicator())),
                error: (e, _) => withBack(ErrorView(
                  message:
                      userMessage(e, fallback: l10n.errorGeneric, l10n: l10n),
                  onRetry: () => ref.invalidate(tripJournalProvider(groupId)),
                )),
                data: (list) =>
                    _JournalBody(group: group, uid: uid, entries: list),
              ),
              BottomFloat(
                button: canRecap
                    ? Row(
                        children: [
                          Expanded(
                            child: SizedBox(
                              height: 54,
                              child: OutlinedButton(
                                style: OutlinedButton.styleFrom(
                                  backgroundColor:
                                      Theme.of(context).colorScheme.surface,
                                  shape: const StadiumBorder(),
                                ),
                                onPressed: () =>
                                    context.push('/trip/$groupId/recap'),
                                child: Text(l10n.journalOpenRecap,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(child: add),
                        ],
                      )
                    : add,
              ),
            ],
          );
        },
      ),
    );
  }
}

class _JournalBody extends ConsumerWidget {
  const _JournalBody({
    required this.group,
    required this.uid,
    required this.entries,
  });

  final GroupModel group;
  final String uid;
  final List<JournalEntry> entries;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final locale = Localizations.localeOf(context).toLanguageTag();
    final days =
        groupJournalByDay(entries, tripDays(group.tripStart, group.tripEnd));
    final photos = entries.fold(0, (sum, e) => sum + e.photos.length);
    final authors = {for (final e in entries) e.authorUid}.length;

    return ListView(
      padding: EdgeInsets.fromLTRB(
          16, MediaQuery.paddingOf(context).top + 8, 16, 120),
      children: [
        Row(
          children: [
            GlassButton(
              icon: Icons.arrow_back_ios_new_rounded,
              tooltip: l10n.back,
              opacity: 1,
              onTap: () => context.canPop()
                  ? context.pop()
                  : context.go('/trip/${group.groupId}'),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                group.groupName ?? l10n.unnamedGroup,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style:
                    text.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
              ),
            ),
            TripSyncBadge(groupId: group.groupId),
          ],
        ),
        const SizedBox(height: 16),
        Text(l10n.tripTabJournal, style: text.displaySmall),
        const SizedBox(height: 16),
        TripSectionControl(
            groupId: group.groupId, selected: TripSection.journal),
        const SizedBox(height: 16),
        if (entries.isEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 32, 16, 0),
            child: Column(
              children: [
                const IconBadge(
                    icon: Icons.photo_camera_outlined, tone: ChipTone.sky),
                const SizedBox(height: 16),
                Text(l10n.journalEmptyTitle,
                    textAlign: TextAlign.center, style: text.titleLarge),
                const SizedBox(height: 6),
                Text(
                  l10n.journalEmptyBody,
                  textAlign: TextAlign.center,
                  style:
                      text.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
                ),
              ],
            ),
          )
        else ...[
          TripCard(
            radius: 18,
            child: Row(
              children: [
                _Stat(days.length, l10n.recapStatDays(days.length)),
                _Stat(photos, l10n.recapStatPhotos(photos)),
                _Stat(authors, l10n.recapStatMembers(authors)),
              ],
            ),
          ),
          for (final day in days) ...[
            const SizedBox(height: 20),
            Padding(
              padding: const EdgeInsets.only(left: 4, bottom: 8),
              child: Text(
                _dayLabel(l10n, day, locale).toUpperCase(),
                style: text.labelSmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.4,
                ),
              ),
            ),
            for (final entry in day.entries) ...[
              _EntryCard(group: group, uid: uid, entry: entry),
              const SizedBox(height: 10),
            ],
          ],
        ],
      ],
    );
  }

  String _dayLabel(AppLocalizations l10n, JournalDay day, String locale) {
    final date = DateFormat.MMMMEEEEd(locale).format(day.date);
    return day.tripDay == null
        ? date
        : l10n.journalDayHeader(day.tripDay!, date);
  }
}

class _Stat extends StatelessWidget {
  const _Stat(this.value, this.label);

  final int value;
  final String label;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('$value', style: text.headlineSmall),
          Text(label,
              style: text.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant)),
        ],
      ),
    );
  }
}

enum _EntryAction { edit, delete }

class _EntryCard extends ConsumerWidget {
  const _EntryCard({
    required this.group,
    required this.uid,
    required this.entry,
  });

  final GroupModel group;
  final String uid;
  final JournalEntry entry;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final locale = Localizations.localeOf(context).toLanguageTag();
    final mine = entry.authorUid == uid;
    final i = group.members.indexOf(entry.authorUid);
    final name = mine
        ? l10n.tripYou
        : memberName(ref, entry.authorUid,
            i < 0 ? l10n.userFallbackName : l10n.memberFallback(i + 1));
    final meta = [
      name,
      if (entry.createdAt != null)
        DateFormat.Hm(locale).format(entry.createdAt!),
    ].join(' · ');

    Future<void> onAction(_EntryAction action) async {
      switch (action) {
        case _EntryAction.edit:
          await showJournalEntrySheet(context, group, entry: entry);
        case _EntryAction.delete:
          if (!await confirmDeleteJournalEntry(context) || !context.mounted) {
            return;
          }
          final actions = ref.read(tripActionsProvider.notifier);
          runTripWrite(
              context, () => actions.deleteJournalEntry(group.groupId, entry));
      }
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: ColoredBox(
        color: scheme.surface,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(16, 12, mine ? 4 : 16, 10),
              child: Row(
                children: [
                  MemberAvatar(
                    id: entry.authorUid,
                    name: memberName(ref, entry.authorUid, name),
                    size: 36,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(meta,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: text.bodyMedium
                            ?.copyWith(color: scheme.onSurfaceVariant)),
                  ),
                  if (mine)
                    PopupMenuButton<_EntryAction>(
                      tooltip: l10n.journalEntryOptions,
                      icon: const Icon(Icons.more_horiz_rounded),
                      onSelected: onAction,
                      itemBuilder: (_) => [
                        PopupMenuItem(
                          value: _EntryAction.edit,
                          child: Text(l10n.journalEditText),
                        ),
                        PopupMenuItem(
                          value: _EntryAction.delete,
                          child: Text(l10n.delete,
                              style: TextStyle(color: scheme.error)),
                        ),
                      ],
                    ),
                ],
              ),
            ),
            if (entry.photos.isNotEmpty) JournalPhotoGrid(photos: entry.photos),
            if (entry.text.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
                child: Text(entry.text, style: text.bodyLarge),
              )
            else
              const SizedBox(height: 4),
          ],
        ),
      ),
    );
  }
}
