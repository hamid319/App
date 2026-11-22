import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:swipetrip/common/widgets/duck_3d_model.dart';
import 'package:swipetrip/core/constants/colors.dart';
import 'package:swipetrip/features/group/widgets/trip_joined_celebration.dart';

void main() {
  test('the running ducks paint with any mattress colour', () {
    final renderer = DuckRenderer();
    for (var phase = 0.0; phase < 2 * math.pi; phase += 0.3) {
      for (final colour in [BrandColors.orange, BrandColors.lime]) {
        renderer.paint(Canvas(ui.PictureRecorder()), const Size(150, 150),
            tripJoinedDuckPose(phase),
            level: 2, extras: const {}, stickers: const [], mattress: colour);
      }
    }
  });
}
