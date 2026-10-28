import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

import '../../../common/models/group_model.dart';
import '../../../common/models/journal_entry.dart';
import '../../../common/models/sync_status.dart';
import '../../../common/utils/trip_days.dart';
import '../../../common/utils/trip_journal.dart';
import '../../../core/errors/user_message.dart';
import '../../../l10n/l10n.dart';
import '../logic/trip_controller.dart';
import 'trip_ui.dart';

/// Sheet to add a journal entry: day, text and up to six photos. With
/// [entry] it edits that entry's text instead.
Future<void> showJournalEntrySheet(
  BuildContext context,
  GroupModel group, {
  JournalEntry? entry,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Theme.of(context).scaffoldBackgroundColor,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (_) => _JournalEntrySheet(group: group, entry: entry),
  );
}

/// Asks before deleting a journal entry; true when confirmed.
Future<bool> confirmDeleteJournalEntry(BuildContext context) async {
  final l10n = context.l10n;
  final ok = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text(l10n.journalDeleteTitle),
      content: Text(l10n.journalDeleteBody),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext, false),
          child: Text(l10n.cancel),
        ),
        TextButton(
          onPressed: () => Navigator.pop(dialogContext, true),
          style: TextButton.styleFrom(
              foregroundColor: Theme.of(dialogContext).colorScheme.error),
          child: Text(l10n.delete),
        ),
      ],
    ),
  );
  return ok == true;
}

class _JournalEntrySheet extends ConsumerStatefulWidget {
  const _JournalEntrySheet({required this.group, this.entry});

  final GroupModel group;
  final JournalEntry? entry;

  @override
  ConsumerState<_JournalEntrySheet> createState() => _JournalEntrySheetState();
}

class _JournalEntrySheetState extends ConsumerState<_JournalEntrySheet> {
  late final _text = TextEditingController(text: widget.entry?.text);
  late final List<DateTime> _days =
      tripDays(widget.group.tripStart, widget.group.tripEnd);
  late DateTime _day = defaultJournalDay(_days, DateTime.now());
  final List<XFile> _photos = [];
  final _picker = ImagePicker();
  bool _saving = false;
  ({int done, int total})? _progress;
  String? _error;

  bool get _editing => widget.entry != null;
  int get _room => JournalEntry.maxPhotos - _photos.length;

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  // Downscaled by the picker: no new dependency, small uploads.
  static const _maxSide = 2048.0;
  static const _quality = 80;

  Future<void> _pick(ImageSource source) async {
    final l10n = context.l10n;
    try {
      final List<XFile> picked;
      if (source == ImageSource.camera || _room == 1) {
        final one = await _picker.pickImage(
          source: source,
          maxWidth: _maxSide,
          maxHeight: _maxSide,
          imageQuality: _quality,
        );
        picked = one == null ? const [] : [one];
      } else {
        picked = await _picker.pickMultiImage(
          maxWidth: _maxSide,
          maxHeight: _maxSide,
          imageQuality: _quality,
          limit: _room,
        );
      }
      if (!mounted || picked.isEmpty) return;
      setState(() {
        _photos.addAll(picked.take(_room));
        _error = null;
      });
    } catch (e) {
      if (mounted) {
        setState(() => _error =
            userMessage(e, fallback: l10n.journalPickError, l10n: l10n));
      }
    }
  }

  Future<void> _save() async {
    final l10n = context.l10n;
    final actions = ref.read(tripActionsProvider.notifier);
    final groupId = widget.group.groupId;
    final text = _text.text.trim();
    final existing = widget.entry;

    if (existing != null) {
      if (text.isEmpty && existing.photos.isEmpty) {
        setState(() => _error = l10n.journalNeedsContent);
        return;
      }
      runTripWrite(
          context, () => actions.editJournalText(groupId, existing, text));
      Navigator.pop(context);
      return;
    }
    if (text.isEmpty && _photos.isEmpty) {
      setState(() => _error = l10n.journalNeedsContent);
      return;
    }
    if (_photos.isEmpty) {
      // Text only works offline too: Firestore queues the write.
      runTripWrite(context,
          () => actions.addJournalEntry(groupId, day: _day, text: text));
      Navigator.pop(context);
      return;
    }
    // Storage has no offline queue: say so instead of a long silent retry.
    if (ref.read(tripSyncStatusProvider(groupId)).value == SyncStatus.offline) {
      setState(() => _error = l10n.journalOfflinePhotos);
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
      _progress = (done: 0, total: _photos.length);
    });
    try {
      await actions.addJournalEntry(
        groupId,
        day: _day,
        text: text,
        photos: _photos,
        onProgress: (done, total) {
          if (mounted) setState(() => _progress = (done: done, total: total));
        },
      );
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        setState(() {
          _saving = false;
          _progress = null;
          _error = userMessage(e, fallback: l10n.journalSaveError, l10n: l10n);
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final locale = Localizations.localeOf(context).toLanguageTag();
    final progress = _progress;

    return PopScope(
      // Closing mid-upload would leave half an entry behind.
      canPop: !_saving,
      child: Padding(
        padding:
            EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SheetGrabber(),
              Text(_editing ? l10n.journalEditText : l10n.journalAddEntry,
                  style: text.headlineSmall),
              const SizedBox(height: 12),
              if (!_editing && _days.length > 1) ...[
                Padding(
                  padding: const EdgeInsets.only(left: 4, bottom: 8),
                  child: Text(l10n.journalDay,
                      style: text.labelSmall
                          ?.copyWith(color: scheme.onSurfaceVariant)),
                ),
                SizedBox(
                  height: 40,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: _days.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 8),
                    itemBuilder: (_, i) {
                      final d = _days[i];
                      return ChoiceChip(
                        label: Text(l10n.journalDayHeader(
                            i + 1, DateFormat.MMMd(locale).format(d))),
                        selected: journalDayKey(d) == journalDayKey(_day),
                        onSelected:
                            _saving ? null : (_) => setState(() => _day = d),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 16),
              ],
              InsetGroup(
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    child: TextField(
                      controller: _text,
                      autofocus: _editing,
                      enabled: !_saving,
                      minLines: 3,
                      maxLines: 8,
                      maxLength: JournalEntry.maxTextLength,
                      textCapitalization: TextCapitalization.sentences,
                      decoration: InputDecoration(
                        hintText: l10n.journalTextHint,
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        disabledBorder: InputBorder.none,
                        filled: false,
                      ),
                    ),
                  ),
                ],
              ),
              if (!_editing) ...[
                const SizedBox(height: 12),
                if (_photos.isNotEmpty)
                  SizedBox(
                    height: 76,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: _photos.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 8),
                      itemBuilder: (_, i) => _Thumb(
                        file: _photos[i],
                        tooltip: l10n.journalRemovePhoto,
                        onRemove: _saving
                            ? null
                            : () => setState(() => _photos.removeAt(i)),
                      ),
                    ),
                  ),
                Row(
                  children: [
                    TextButton.icon(
                      onPressed: _saving || _room == 0
                          ? null
                          : () => _pick(ImageSource.gallery),
                      icon: const Icon(Icons.photo_library_outlined, size: 20),
                      label: Text(l10n.journalAddPhotos),
                    ),
                    IconButton(
                      tooltip: l10n.journalCamera,
                      onPressed: _saving || _room == 0
                          ? null
                          : () => _pick(ImageSource.camera),
                      icon: const Icon(Icons.photo_camera_outlined),
                    ),
                    const Spacer(),
                    if (_room == 0)
                      Flexible(
                        child: Text(
                          l10n.journalPhotoLimit(JournalEntry.maxPhotos),
                          textAlign: TextAlign.end,
                          style: text.labelSmall
                              ?.copyWith(color: scheme.onSurfaceVariant),
                        ),
                      ),
                  ],
                ),
              ],
              if (progress != null) ...[
                const SizedBox(height: 8),
                LinearProgressIndicator(
                  value: progress.total == 0
                      ? null
                      : progress.done / progress.total,
                ),
                const SizedBox(height: 6),
                Text(
                  l10n.journalUploading(
                      (progress.done + 1).clamp(1, progress.total),
                      progress.total),
                  style:
                      text.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
                ),
              ],
              if (_error != null) ...[
                const SizedBox(height: 8),
                Text(_error!,
                    style: text.bodyMedium?.copyWith(color: scheme.error)),
              ],
              const SizedBox(height: 20),
              FloatingPrimaryButton(
                label: _editing ? l10n.save : l10n.journalAddEntry,
                icon: _editing ? Icons.check_rounded : Icons.add_rounded,
                loading: _saving,
                onPressed: _save,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Thumb extends StatelessWidget {
  const _Thumb(
      {required this.file, required this.tooltip, required this.onRemove});

  final XFile file;
  final String tooltip;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: 76,
      child: Stack(
        fit: StackFit.expand,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child:
                Image.file(File(file.path), fit: BoxFit.cover, cacheWidth: 228),
          ),
          if (onRemove != null)
            Positioned(
              top: 2,
              right: 2,
              child: Semantics(
                button: true,
                label: tooltip,
                child: GestureDetector(
                  onTap: onRemove,
                  child: Container(
                    padding: const EdgeInsets.all(3),
                    decoration: const BoxDecoration(
                      color: Colors.black54,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.close_rounded,
                        size: 16, color: Colors.white),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
