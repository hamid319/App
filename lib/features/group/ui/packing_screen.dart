import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../common/models/group_model.dart';
import '../../../common/models/packing.dart';
import '../../../common/utils/packing_template.dart';
import '../../../common/widgets/error_view.dart';
import '../../../common/widgets/member_avatar.dart';
import '../../../common/widgets/suitcase_view.dart';
import '../../../core/constants/sizes.dart';
import '../../../core/errors/user_message.dart';
import '../../../l10n/l10n.dart';
import '../../auth/logic/auth_controller.dart';
import '../logic/packing_controller.dart';
import '../logic/trip_controller.dart';
import '../widgets/packing_done_celebration.dart';
import '../widgets/packing_labels.dart';
import '../widgets/trip_ui.dart';

/// The trip's packing list: the member's own (private) list with
/// suggestions, the shared list of things one person brings for all, and
/// how far everyone has packed.
class PackingScreen extends ConsumerWidget {
  const PackingScreen({super.key, required this.groupId});

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
        data: (group) => group == null
            ? ErrorView(
                message: l10n.groupNotFound,
                onRetry: () => context.go('/trips'),
              )
            : withBack(_PackingBody(group: group, uid: uid)),
      ),
    );
  }
}

class _PackingBody extends ConsumerStatefulWidget {
  const _PackingBody({required this.group, required this.uid});

  final GroupModel group;
  final String uid;

  @override
  ConsumerState<_PackingBody> createState() => _PackingBodyState();
}

class _PackingBodyState extends ConsumerState<_PackingBody> {
  int _tab = 0;
  final _own = TextEditingController();
  final _shared = TextEditingController();

  GroupModel get _trip => widget.group;
  PackingController get _ctrl => ref.read(packingControllerProvider.notifier);

  @override
  void dispose() {
    _own.dispose();
    _shared.dispose();
    super.dispose();
  }

  void _write(Future<void> save) => runTripWrite(context, () => save);

  void _maybeCelebrate(bool done) {
    if (!done) {
      HapticFeedback.selectionClick();
      return;
    }
    showPackingDoneCelebration(context,
        cityName: _trip.location?.cityName ?? _trip.groupName ?? '');
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final id = _trip.groupId;
    final saved = ref.watch(myPackingListProvider(id));
    final sharedAsync = ref.watch(sharedPackingProvider(id));
    final progressMap =
        ref.watch(packingProgressProvider(id)).value ?? const {};
    // Errors (offline, rules) fall back to the suggested list; a retry
    // keeps isLoading true, so only wait for a first answer.
    bool waiting(AsyncValue<Object?> v) => !v.hasValue && !v.hasError;
    if (waiting(saved) || waiting(sharedAsync)) {
      return const Center(child: CircularProgressIndicator());
    }
    final mine = _ctrl.listOf(_trip);
    final shared = sharedAsync.value ?? const <SharedPackingItem>[];
    final me = packingProgressOf(mine, shared, widget.uid);

    return ListView(
      padding: EdgeInsets.fromLTRB(AppSizes.screenEdge,
          MediaQuery.paddingOf(context).top + 64, AppSizes.screenEdge, 48),
      children: [
        Text(l10n.packingTitle, style: text.headlineMedium),
        if (_trip.location?.cityName case final city?)
          Text(city,
              style: text.bodyMedium?.copyWith(color: scheme.onSurfaceVariant)),
        const SizedBox(height: AppSizes.space16),
        _ProgressCard(
          me: me,
          group: _trip,
          uid: widget.uid,
          progress: progressMap,
        ),
        const SizedBox(height: AppSizes.space16),
        TripSegmentedControl(
          segments: [
            TripSegment(l10n.packingMine),
            TripSegment(l10n.packingShared),
          ],
          selected: _tab,
          onSelected: (i) => setState(() => _tab = i),
        ),
        const SizedBox(height: AppSizes.space16),
        if (_tab == 0) ..._mineSection(mine) else ..._sharedSection(shared),
      ],
    );
  }

  List<Widget> _mineSection(List<PackingItem> mine) {
    final l10n = context.l10n;
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    return [
      _Note(icon: Icons.lock_outline_rounded, text: l10n.packingPrivateNote),
      const SizedBox(height: AppSizes.space12),
      for (final c in PackingCategory.values)
        if (mine.where((i) => i.category == c).toList() case final items
            when items.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 8, 4, 6),
            child: Text(packingCategoryLabel(l10n, c).toUpperCase(),
                style: text.labelSmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                  letterSpacing: 1.1,
                  fontWeight: FontWeight.w800,
                )),
          ),
          InsetGroup(
            separatorIndent: 52,
            children: [
              for (final item in items)
                Dismissible(
                  key: ValueKey('own_${item.id}'),
                  direction: DismissDirection.endToStart,
                  background: _DeleteBackground(),
                  onDismissed: (_) => _ctrl.remove(_trip, item, _write),
                  child: _CheckRow(
                    title: packingItemTitle(l10n, item),
                    done: item.done,
                    onTap: () =>
                        _maybeCelebrate(_ctrl.toggle(_trip, item, _write)),
                  ),
                ),
            ],
          ),
          const SizedBox(height: AppSizes.space8),
        ],
      const SizedBox(height: AppSizes.space8),
      _AddField(
        controller: _own,
        label: l10n.packingAddOwn,
        hint: l10n.packingAddOwnHint,
        onAdd: (name) => _ctrl.addOwn(_trip, name, _write),
      ),
    ];
  }

  List<Widget> _sharedSection(List<SharedPackingItem> shared) {
    final l10n = context.l10n;
    final text = Theme.of(context).textTheme;
    final titles = {for (final s in shared) s.title.trim().toLowerCase()};
    final suggestions = [
      for (final key in sharedPackingSuggestions)
        if (!titles.contains(packingItemLabel(l10n, key).toLowerCase()))
          packingItemLabel(l10n, key),
    ];
    return [
      _Note(icon: Icons.groups_outlined, text: l10n.packingSharedNote),
      const SizedBox(height: AppSizes.space12),
      if (shared.isEmpty)
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
          child: Text(l10n.packingSharedEmpty, style: text.bodyMedium),
        )
      else
        InsetGroup(
          separatorIndent: 52,
          children: [
            for (final item in shared)
              _SharedRow(
                item: item,
                uid: widget.uid,
                bringerFallback: l10n.memberFallback(
                    _trip.members.indexOf(item.bringer ?? '') + 1),
                canDelete:
                    item.addedBy == widget.uid || _trip.ownerUid == widget.uid,
                onTake: () => _ctrl.take(_trip, item, _write),
                onHandBack: () => _ctrl.handBack(_trip, item, _write),
                onToggle: () =>
                    _maybeCelebrate(_ctrl.toggleShared(_trip, item, _write)),
                onDelete: () => _ctrl.deleteShared(_trip, item, _write),
              ),
          ],
        ),
      const SizedBox(height: AppSizes.space16),
      _AddField(
        controller: _shared,
        label: l10n.packingAddShared,
        hint: l10n.packingAddSharedHint,
        onAdd: (title) => _ctrl.addShared(_trip, title, _write),
      ),
      if (suggestions.isNotEmpty) ...[
        const SizedBox(height: AppSizes.space16),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Text(l10n.packingSuggestions, style: text.titleSmall),
        ),
        const SizedBox(height: AppSizes.space8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final s in suggestions)
              ActionChip(
                avatar: const Icon(Icons.add_rounded, size: 18),
                label: Text(s),
                onPressed: () => _ctrl.addShared(_trip, s, _write),
              ),
          ],
        ),
      ],
    ];
  }
}

/// The member's own progress with the suitcase, and the group's.
class _ProgressCard extends ConsumerWidget {
  const _ProgressCard({
    required this.me,
    required this.group,
    required this.uid,
    required this.progress,
  });

  final PackingProgress me;
  final GroupModel group;
  final String uid;
  final Map<String, PackingProgress> progress;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final value = me.total == 0 ? 0.0 : me.done / me.total;
    final others = group.members.where((m) => m != uid).toList();
    final allReady = group.members.every(
        (m) => m == uid ? me.complete : (progress[m]?.complete ?? false));

    return TripCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              SizedBox.square(
                dimension: 64,
                child: TweenAnimationBuilder<double>(
                  tween: Tween(end: value),
                  duration: const Duration(milliseconds: 500),
                  curve: Curves.easeOutCubic,
                  // The handle slides in as the suitcase fills up.
                  builder: (_, v, __) =>
                      CustomPaint(painter: SuitcasePainter(handleOut: 1 - v)),
                ),
              ),
              const SizedBox(width: AppSizes.space12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(l10n.packingYouProgress(me.percent),
                        style: text.titleMedium),
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: TweenAnimationBuilder<double>(
                        tween: Tween(end: value),
                        duration: const Duration(milliseconds: 500),
                        curve: Curves.easeOutCubic,
                        builder: (_, v, __) => LinearProgressIndicator(
                          value: v,
                          minHeight: 8,
                          backgroundColor: scheme.surfaceContainerHighest,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (others.isNotEmpty) ...[
            const SizedBox(height: AppSizes.space16),
            Text(allReady ? l10n.packingAllReady : l10n.packingGroup,
                style:
                    text.labelLarge?.copyWith(color: scheme.onSurfaceVariant)),
            const SizedBox(height: AppSizes.space8),
            for (final (i, m) in others.indexed)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    MemberAvatar(
                      id: m,
                      name: memberName(ref, m, ''),
                      size: 26,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        memberName(ref, m, l10n.memberFallback(i + 1)),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: text.bodyMedium,
                      ),
                    ),
                    SizedBox(
                      width: 70,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(3),
                        child: LinearProgressIndicator(
                          value: (progress[m]?.percent ?? 0) / 100,
                          minHeight: 6,
                          backgroundColor: scheme.surfaceContainerHighest,
                        ),
                      ),
                    ),
                    SizedBox(
                      width: 48,
                      child: (progress[m]?.complete ?? false)
                          ? Icon(Icons.check_circle_rounded,
                              size: 20, color: scheme.primary)
                          : Text(
                              l10n.packingPercent(progress[m]?.percent ?? 0),
                              textAlign: TextAlign.right,
                              style: text.labelMedium,
                            ),
                    ),
                  ],
                ),
              ),
          ],
        ],
      ),
    );
  }
}

class _Note extends StatelessWidget {
  const _Note({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: scheme.onSurfaceVariant),
        const SizedBox(width: 8),
        Expanded(
          child: Text(text,
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: scheme.onSurfaceVariant)),
        ),
      ],
    );
  }
}

/// A row with a round check on the left.
class _CheckRow extends StatelessWidget {
  const _CheckRow({
    required this.title,
    required this.done,
    required this.onTap,
    this.subtitle,
    this.trailing,
  });

  final String title;
  final String? subtitle;
  final bool done;
  final VoidCallback? onTap;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    return Semantics(
      checked: onTap == null ? null : done,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
          child: Row(
            children: [
              SizedBox(
                width: 26,
                child: onTap == null
                    ? null
                    : AnimatedSwitcher(
                        duration: const Duration(milliseconds: 180),
                        transitionBuilder: (c, a) =>
                            ScaleTransition(scale: a, child: c),
                        child: Icon(
                          done
                              ? Icons.check_circle_rounded
                              : Icons.radio_button_unchecked_rounded,
                          key: ValueKey(done),
                          color: done ? scheme.primary : scheme.outline,
                        ),
                      ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    AnimatedDefaultTextStyle(
                      duration: const Duration(milliseconds: 180),
                      style: (text.bodyLarge ?? const TextStyle()).copyWith(
                        color: done ? scheme.onSurfaceVariant : null,
                        decoration: done ? TextDecoration.lineThrough : null,
                      ),
                      child: Text(title),
                    ),
                    if (subtitle != null)
                      Text(subtitle!,
                          style: text.bodySmall
                              ?.copyWith(color: scheme.onSurfaceVariant)),
                  ],
                ),
              ),
              if (trailing != null) trailing!,
            ],
          ),
        ),
      ),
    );
  }
}

class _SharedRow extends ConsumerWidget {
  const _SharedRow({
    required this.item,
    required this.uid,
    required this.bringerFallback,
    required this.canDelete,
    required this.onTake,
    required this.onHandBack,
    required this.onToggle,
    required this.onDelete,
  });

  final SharedPackingItem item;
  final String uid;

  /// "Member 2" while the bringer's name loads.
  final String bringerFallback;
  final bool canDelete;
  final VoidCallback onTake, onHandBack, onToggle, onDelete;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final scheme = Theme.of(context).colorScheme;
    final bringer = item.bringer;
    final mine = bringer == uid;
    final subtitle = bringer == null
        ? l10n.packingNobody
        : mine
            ? l10n.packingYouBring
            : l10n.packingBringer(memberName(ref, bringer, bringerFallback));

    final menu = [
      if (mine) (l10n.packingHandBack, onHandBack),
      if (canDelete) (l10n.delete, onDelete),
    ];

    return _CheckRow(
      title: item.title,
      subtitle: subtitle,
      done: item.packed,
      // Only the bringer ticks it off.
      onTap: mine ? onToggle : null,
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (bringer == null)
            FilledButton.tonal(
              onPressed: onTake,
              style: FilledButton.styleFrom(
                // The theme's buttons are full width; this one sits in a row.
                minimumSize: const Size(0, 36),
                visualDensity: VisualDensity.compact,
                padding: const EdgeInsets.symmetric(horizontal: 12),
              ),
              child:
                  Text(l10n.packingBring, style: const TextStyle(fontSize: 14)),
            )
          else if (!mine)
            Stack(
              clipBehavior: Clip.none,
              children: [
                MemberAvatar(
                    id: bringer, name: memberName(ref, bringer, ''), size: 28),
                if (item.packed)
                  Positioned(
                    right: -4,
                    bottom: -4,
                    child: Icon(Icons.check_circle_rounded,
                        size: 16, color: scheme.primary),
                  ),
              ],
            ),
          if (menu.isNotEmpty)
            PopupMenuButton<VoidCallback>(
              icon:
                  Icon(Icons.more_vert_rounded, color: scheme.onSurfaceVariant),
              tooltip: l10n.moreOptions,
              onSelected: (action) => action(),
              itemBuilder: (_) => [
                for (final (label, action) in menu)
                  PopupMenuItem(value: action, child: Text(label)),
              ],
            ),
        ],
      ),
    );
  }
}

class _AddField extends StatelessWidget {
  const _AddField({
    required this.controller,
    required this.label,
    required this.hint,
    required this.onAdd,
  });

  final TextEditingController controller;
  final String label, hint;
  final ValueChanged<String> onAdd;

  void _submit() {
    if (controller.text.trim().isEmpty) return;
    onAdd(controller.text);
    controller.clear();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return InsetGroup(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 2, 4, 2),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: controller,
                  maxLength: 60,
                  textCapitalization: TextCapitalization.sentences,
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) => _submit(),
                  decoration: InputDecoration(
                    labelText: label,
                    hintText: hint,
                    counterText: '',
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    filled: false,
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.add_circle_rounded),
                color: Theme.of(context).colorScheme.primary,
                tooltip: l10n.packingAdd,
                onPressed: _submit,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _DeleteBackground extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      color: scheme.error,
      alignment: Alignment.centerRight,
      padding: const EdgeInsets.only(right: 20),
      child: Icon(Icons.delete_outline_rounded, color: scheme.onError),
    );
  }
}
