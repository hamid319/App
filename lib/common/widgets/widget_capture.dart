import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

/// Renders [card] off screen at [size] and returns it as PNG, for sharing
/// pictures such as the trip recap or a passport page. The card's network
/// images must already be in the image cache (precacheImage).
Future<Uint8List> captureWidget(
    BuildContext context, Widget card, Size size) async {
  final key = GlobalKey();
  final entry = OverlayEntry(
    builder: (_) => Positioned(
      // Laid out and painted, but outside the visible screen.
      left: -size.width - 100,
      top: 0,
      width: size.width,
      height: size.height,
      child: IgnorePointer(child: RepaintBoundary(key: key, child: card)),
    ),
  );
  Overlay.of(context).insert(entry);
  try {
    // Two frames: the first builds and resolves the cached images.
    await WidgetsBinding.instance.endOfFrame;
    await WidgetsBinding.instance.endOfFrame;
    final boundary =
        key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    final image = await boundary.toImage(pixelRatio: 1);
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    return data!.buffer.asUint8List();
  } finally {
    entry.remove();
  }
}
