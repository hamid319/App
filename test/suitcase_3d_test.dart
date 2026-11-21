import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:swipetrip/common/utils/suitcase_progress.dart';
import 'package:swipetrip/common/widgets/suitcase_3d.dart';
import 'package:swipetrip/common/widgets/suitcase_view.dart';

void main() {
  testWidgets('3D suitcase paints from every side with all extras',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Center(
        child: Suitcase3D(
          stickers: [
            for (var i = 0; i < 8; i++)
              SuitcaseSticker(label: 'BER', seed: i * 37, faded: i.isOdd),
          ],
          extras: SuitcaseExtra.values.toSet(),
        ),
      ),
    ));
    // A full turn in steps; a paint error would fail the test.
    for (var i = 0; i < 12; i++) {
      await tester.drag(find.byType(Suitcase3D), const Offset(40, 0));
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
}
