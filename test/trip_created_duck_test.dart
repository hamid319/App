import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:swipetrip/common/widgets/duck_3d_model.dart';
import 'package:swipetrip/common/widgets/suitcase_view.dart';
import 'package:swipetrip/features/group/widgets/trip_created_celebration.dart';

void main() {
  test('the trip-created duck scene paints every frame', () {
    final renderer = DuckRenderer();
    for (var t = 0.0; t <= 4.0; t += 0.05) {
      final p = tripCreatedDuckPose(t);
      for (final v in [p.hop, p.lean, p.squash, p.pack, p.footR, p.strideL]) {
        expect(v.isFinite, isTrue, reason: 't=$t');
      }
      expect(p.pack, inInclusiveRange(0, 1));
      expect(p.drop, inInclusiveRange(0, 1));
      renderer.paint(Canvas(ui.PictureRecorder()), const Size(250, 250), p,
          level: 2,
          extras: const {},
          stickers: const [SuitcaseSticker(label: 'BER', seed: 1)]);
    }
    // On the ground at the start, on the back when it runs off.
    expect(tripCreatedDuckPose(0.2).drop, 1);
    expect(tripCreatedDuckPose(3.5).drop, 0);
    expect(tripCreatedDuckPose(3.5).pack, 1);
  });
}
