import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:swipetrip/common/widgets/tripfam_mark.dart';
import 'package:swipetrip/common/widgets/wordmark.dart';

void main() {
  testWidgets('wordmark shows the suitcase mark by default', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: Center(child: Wordmark()))),
    );
    expect(find.byType(TripFamMark), findsOneWidget);
    expect(find.bySemanticsLabel('TripFam'), findsOneWidget);
  });

  testWidgets('wordmark can show the logotype alone', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: Center(child: Wordmark(showMark: false))),
      ),
    );
    expect(find.byType(TripFamMark), findsNothing);
  });

  test('painter repaints only when its look changes', () {
    const a = TripFamPainter(background: Colors.blue);
    expect(a.shouldRepaint(const TripFamPainter(background: Colors.blue)),
        isFalse);
    expect(a.shouldRepaint(const TripFamPainter(contentScale: 0.6)), isTrue);
  });
}
