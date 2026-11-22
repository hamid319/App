import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:swipetrip/common/utils/suitcase_progress.dart';
import 'package:swipetrip/common/widgets/duck_3d.dart';
import 'package:swipetrip/common/widgets/suitcase_view.dart';

void main() {
  for (final level in [0, 4]) {
    testWidgets('3D duck at level $level paints from every side',
        (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Center(
          child: Duck3D(
            level: level,
            stickers: [
              for (var i = 0; i < 8; i++)
                SuitcaseSticker(label: 'BER', seed: i * 37, faded: i.isOdd),
            ],
            extras: level == 0 ? const {} : SuitcaseExtra.values.toSet(),
          ),
        ),
      ));
      // A full turn in steps; a paint error would fail the test.
      for (var i = 0; i < 12; i++) {
        await tester.drag(find.byType(Duck3D), const Offset(40, 0));
        await tester.pump(const Duration(milliseconds: 100));
      }
      // Every tap plays the next action (hop, wave, spin, quack).
      for (var i = 0; i < 4; i++) {
        await tester.tap(find.byType(Duck3D));
        for (var f = 0; f < 20; f++) {
          await tester.pump(const Duration(milliseconds: 100));
        }
      }
      // A wild fling ends dizzy, then settles.
      await tester.fling(find.byType(Duck3D), const Offset(300, 0), 3000);
      for (var f = 0; f < 60; f++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    });
  }
}
