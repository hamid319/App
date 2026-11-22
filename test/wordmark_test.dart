import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:swipetrip/common/widgets/brand_mark.dart';
import 'package:swipetrip/common/widgets/wordmark.dart';

void main() {
  testWidgets('wordmark shows the duck mark by default', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: Center(child: Wordmark()))),
    );
    expect(find.byType(BrandMark), findsOneWidget);
    expect(find.bySemanticsLabel('Out We Go'), findsOneWidget);
  });

  testWidgets('wordmark can show the logotype alone', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: Center(child: Wordmark(showMark: false))),
      ),
    );
    expect(find.byType(BrandMark), findsNothing);
  });

  test('painter repaints only when its look changes', () {
    const a = BrandMarkPainter(background: Colors.blue);
    expect(a.shouldRepaint(const BrandMarkPainter(background: Colors.blue)),
        isFalse);
    expect(a.shouldRepaint(const BrandMarkPainter(contentScale: 0.6)), isTrue);
  });
}
