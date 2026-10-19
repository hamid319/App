import 'package:flutter_test/flutter_test.dart';
import 'package:swipetrip/common/models/group_session_model.dart';
import 'package:swipetrip/core/constants/colors.dart';
import 'package:swipetrip/features/group/widgets/session_progress_panel.dart';

GroupSessionModel _session({
  required Map<String, int> progress,
  int limit = 20,
  Map<String, int>? progressByUser,
}) =>
    GroupSessionModel(
      sessionId: 's1',
      destination: 'Lisbon',
      status: 'in_progress',
      totalPlacesToSwipe: limit,
      swipeLimit: limit,
      participants: const ['a', 'b', 'c'],
      swipeProgress: progress,
      progressByUser: progressByUser,
      createdAt: DateTime(2026),
    );

void main() {
  group('sessionProgressFor', () {
    test('is the share of the swipe limit', () {
      final s = _session(progress: {'a': 14, 'b': 20, 'c': 0});
      expect(sessionProgressFor(s, 'a'), closeTo(0.7, 1e-9));
      expect(sessionProgressFor(s, 'b'), 1.0);
      expect(sessionProgressFor(s, 'c'), 0.0);
    });

    test('a participant without progress yet counts as zero', () {
      expect(sessionProgressFor(_session(progress: {}), 'a'), 0.0);
    });

    test('never exceeds 100 %', () {
      expect(sessionProgressFor(_session(progress: {'a': 25}), 'a'), 1.0);
    });

    test('prefers progressByUser, which the swipe transaction writes', () {
      final s = _session(progress: {'a': 2}, progressByUser: {'a': 10});
      expect(sessionProgressFor(s, 'a'), 0.5);
    });
  });

  test('a member always gets the same avatar colour', () {
    expect(AvatarColors.forId('user-42'), AvatarColors.forId('user-42'));
  });
}
