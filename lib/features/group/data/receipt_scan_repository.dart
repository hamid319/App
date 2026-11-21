import 'package:flutter/services.dart';

import 'receipt_models.dart';
import 'receipt_parser.dart';

export 'receipt_models.dart';

/// The photo shows no receipt the scan could read.
class ReceiptNotReadableException implements Exception {}

/// Reads receipt photos on the device: Apple Vision on iOS, Google ML Kit
/// on Android (AppDelegate.swift, MainActivity.kt). Both run offline, so
/// the photo never leaves the phone and nothing is billed. The recognised
/// text goes through [parseReceipt].
class ReceiptScanRepository {
  ReceiptScanRepository({MethodChannel? channel})
      : _channel = channel ?? const MethodChannel('tripfam/text_recognition');

  final MethodChannel _channel;

  /// Reads the photo at [imagePath].
  Future<ScannedReceipt> scan(String imagePath) async {
    final raw = await _channel
        .invokeListMethod<Object?>('recognize', {'path': imagePath});
    final pieces = [
      for (final e in raw ?? const <Object?>[])
        if (e is Map)
          RecognizedText(
            '${e['text'] ?? ''}',
            _number(e['left']),
            _number(e['top']),
            _number(e['right']),
            _number(e['bottom']),
          ),
    ];
    final receipt = parseReceipt(pieces);
    if (receipt == null) throw ReceiptNotReadableException();
    return receipt;
  }

  static double _number(Object? v) => v is num ? v.toDouble() : 0;
}
