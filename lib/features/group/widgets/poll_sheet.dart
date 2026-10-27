import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../common/models/trip_poll.dart';
import '../../../l10n/l10n.dart';
import '../logic/trip_controller.dart';
import 'trip_ui.dart';

/// Sheet to ask the group a question with two to six answers.
Future<void> showPollSheet(BuildContext context, String groupId) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Theme.of(context).scaffoldBackgroundColor,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (_) => _PollSheet(groupId: groupId),
  );
}

class _PollSheet extends ConsumerStatefulWidget {
  const _PollSheet({required this.groupId});

  final String groupId;

  @override
  ConsumerState<_PollSheet> createState() => _PollSheetState();
}

class _PollSheetState extends ConsumerState<_PollSheet> {
  final _question = TextEditingController();
  final _options = [TextEditingController(), TextEditingController()];

  @override
  void dispose() {
    _question.dispose();
    for (final c in _options) {
      c.dispose();
    }
    super.dispose();
  }

  bool get _valid =>
      _question.text.trim().isNotEmpty &&
      _options.where((c) => c.text.trim().isNotEmpty).length >= 2;

  void _create() {
    final actions = ref.read(tripActionsProvider.notifier);
    final groupId = widget.groupId;
    final question = _question.text;
    final options = [for (final c in _options) c.text];
    // Not awaited, so creating a poll also works offline.
    runTripWrite(context, () => actions.createPoll(groupId, question, options));
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final text = Theme.of(context).textTheme;
    InputDecoration plain(String hint) => InputDecoration(
          hintText: hint,
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
          filled: false,
          counterText: '',
        );

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(l10n.tripNewPoll, style: text.headlineSmall),
            const SizedBox(height: 12),
            InsetGroup(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  child: TextField(
                    controller: _question,
                    autofocus: true,
                    maxLength: 140,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: plain(l10n.tripPollQuestionHint),
                    onChanged: (_) => setState(() {}),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            InsetGroup(
              children: [
                for (final (i, c) in _options.indexed)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    child: TextField(
                      controller: c,
                      maxLength: 80,
                      textCapitalization: TextCapitalization.sentences,
                      decoration: plain(l10n.tripPollOptionHint(i + 1)),
                      onChanged: (_) => setState(() {}),
                    ),
                  ),
              ],
            ),
            if (_options.length < TripPoll.maxOptions)
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: () =>
                      setState(() => _options.add(TextEditingController())),
                  icon: const Icon(Icons.add_rounded),
                  label: Text(l10n.tripPollAddOption),
                ),
              ),
            const SizedBox(height: 12),
            FloatingPrimaryButton(
              label: l10n.tripPollCreate,
              onPressed: _valid ? _create : null,
            ),
          ],
        ),
      ),
    );
  }
}
