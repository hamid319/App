import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:swipetrip/common/widgets/swipe_pin_mark.dart';
import 'package:swipetrip/common/widgets/wordmark.dart';

void main() {
  testWidgets('wordmark shows the swipe-pin mark by default', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: Center(child: Wordmark()))),
    );
    expect(find.byType(SwipePinMark), findsOneWidget);
    expect(find.bySemanticsLabel('SwipeTrip'), findsOneWidget);
  });

  testWidgets('wordmark can show the logotype alone', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: Center(child: Wordmark(showMark: false))),
      ),
    );
    expect(find.byType(SwipePinMark), findsNothing);
  });

  test('painter repaints only when its look changes', () {
    const a = SwipePinPainter(accent: Colors.orange);
    expect(
        a.shouldRepaint(const SwipePinPainter(accent: Colors.orange)), isFalse);
    expect(a.shouldRepaint(const SwipePinPainter(accent: Colors.red)), isTrue);
  });
}
