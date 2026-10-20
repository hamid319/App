// Renders the logo PNGs used for the app icons and the native splash screen.
//
//   flutter test tool/brand_assets_test.dart
//   dart run flutter_launcher_icons
//   dart run flutter_native_splash:create
//
// Lives outside test/ so the normal test run does not rewrite the assets.
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:swipetrip/common/widgets/swipe_pin_mark.dart';
import 'package:swipetrip/core/constants/colors.dart';

Future<void> _render(String name, int px, SwipePinPainter painter) async {
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  painter.paint(canvas, Size.square(px.toDouble()));
  final image = await recorder.endRecording().toImage(px, px);
  final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
  final file = File('assets/branding/$name');
  await file.parent.create(recursive: true);
  await file.writeAsBytes(bytes!.buffer.asUint8List());
}

void main() {
  test('render brand assets', () async {
    final accent = AppPalette.light.primary;

    // Full-bleed icon; iOS and Android round the corners themselves.
    await _render(
      'app_icon.png',
      1024,
      SwipePinPainter(accent: accent, background: accent),
    );
    // Android adaptive icon foreground: the mark inside the 66 % safe zone.
    await _render(
      'app_icon_foreground.png',
      1024,
      SwipePinPainter(accent: accent, contentScale: 0.6),
    );
    // Splash on the orange ground (iOS, Android < 12): shown at 1/4 size.
    await _render(
      'splash_mark.png',
      768,
      SwipePinPainter(accent: accent, contentScale: 0.9),
    );
    // Android 12+ splash icon: must fit the 768 px circle of a 1152 px image.
    await _render(
      'splash_android12.png',
      1152,
      SwipePinPainter(accent: accent, contentScale: 0.6),
    );
  });
}
