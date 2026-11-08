import 'dart:convert';
import 'dart:typed_data';

import 'package:firebase_ai/firebase_ai.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:meta/meta.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/config/app_config.dart';

/// One line read from a receipt; amounts are in hundredths of the receipt's
/// currency (cents for euros, so 1200 yen is 120000).
@immutable
class ScannedLine {
  final String name;
  final String? original;
  final int amount;

  const ScannedLine({required this.name, this.original, required this.amount});
}

/// What Gemini read from a receipt photo.
@immutable
class ScannedReceipt {
  final String merchant;

  /// ISO 4217 code, upper case ('EUR', 'JPY').
  final String currency;
  final List<ScannedLine> lines;

  /// Tax added on top of the line prices (US sales tax); 0 when included.
  final int tax;
  final int tip;
  final int total;

  const ScannedReceipt({
    required this.merchant,
    required this.currency,
    required this.lines,
    required this.tax,
    required this.tip,
    required this.total,
  });

  /// Parses the model's JSON answer; amounts come as decimal numbers.
  factory ScannedReceipt.fromJson(Map<String, dynamic> json) {
    int hundredths(Object? v) =>
        v is num && v.isFinite ? (v * 100).round().abs() : 0;
    final currency = '${json['currency'] ?? ''}'.trim().toUpperCase();
    return ScannedReceipt(
      merchant: '${json['merchant'] ?? ''}'.trim(),
      currency: RegExp(r'^[A-Z]{3}$').hasMatch(currency) ? currency : 'EUR',
      lines: [
        for (final line in json['items'] as List? ?? const [])
          if (line is Map && hundredths(line['amount']) > 0)
            ScannedLine(
              name: '${line['name'] ?? ''}'.trim(),
              original: switch ('${line['original'] ?? ''}'.trim()) {
                '' => null,
                final o => o,
              },
              amount: hundredths(line['amount']),
            ),
      ],
      tax: hundredths(json['tax']),
      tip: hundredths(json['tip']),
      total: hundredths(json['total']),
    );
  }
}

/// The user scanned [AppConfig.receiptScansPerDay] receipts today.
class ReceiptScanLimitException implements Exception {}

/// The photo shows no receipt the model could read.
class ReceiptNotReadableException implements Exception {}

/// Reads receipt photos with Gemini through Firebase AI Logic. No key is in
/// the app; App Check keeps other clients out.
class ReceiptScanRepository {
  static const _prompt = '''
Read this receipt. Return JSON:
- merchant: the shop or restaurant name.
- currency: ISO 4217 code of the amounts.
- items: every purchased line with its final price (quantity included, line
  discounts applied). name: translated into {language}, short. original: the
  printed name, only when it differs from name.
- tax: only tax added on top of the line prices (like US sales tax); 0 when
  the prices already include it (VAT).
- tip: tip or service charge printed on the receipt, else 0.
- total: the total to pay.
Amounts are plain decimal numbers in the receipt's currency. If the image is
not a receipt, return an empty items list.''';

  static final _schema = Schema.object(
    properties: {
      'merchant': Schema.string(),
      'currency': Schema.string(),
      'items': Schema.array(
        items: Schema.object(
          properties: {
            'name': Schema.string(),
            'original': Schema.string(),
            'amount': Schema.number(),
          },
          optionalProperties: ['original'],
        ),
      ),
      'tax': Schema.number(),
      'tip': Schema.number(),
      'total': Schema.number(),
    },
  );

  /// Reads [jpeg]; names are translated into [appLanguage] ('en', 'de').
  Future<ScannedReceipt> scan(Uint8List jpeg, String appLanguage) async {
    await _countScan();
    final model = FirebaseAI.googleAI(
      appCheck: FirebaseAppCheck.instance,
      auth: FirebaseAuth.instance,
    ).generativeModel(
      model: AppConfig.receiptScanModel,
      generationConfig: GenerationConfig(
        responseMimeType: 'application/json',
        responseSchema: _schema,
        temperature: 0,
        // Thinking tokens are billed and add nothing to reading a receipt.
        thinkingConfig: ThinkingConfig(thinkingBudget: 0),
      ),
    );
    final language = appLanguage == 'de' ? 'German' : 'English';
    final response = await model.generateContent([
      Content.multi([
        TextPart(_prompt.replaceAll('{language}', language)),
        InlineDataPart('image/jpeg', jpeg),
      ]),
    ]);
    final text = response.text;
    if (text == null) throw ReceiptNotReadableException();
    final Object? json;
    try {
      json = jsonDecode(text);
    } on FormatException {
      throw ReceiptNotReadableException();
    }
    if (json is! Map<String, dynamic>) throw ReceiptNotReadableException();
    final receipt = ScannedReceipt.fromJson(json);
    if (receipt.lines.isEmpty) throw ReceiptNotReadableException();
    return receipt;
  }

  /// shortcut: the daily limit is counted on the device, so reinstalling
  /// resets it; move it server side (AI Logic per-user limits or a
  /// function) if scans get abused.
  Future<void> _countScan() async {
    final prefs = await SharedPreferences.getInstance();
    final now = DateTime.now();
    final key = 'receipt_scans_${now.year}-${now.month}-${now.day}';
    final count = prefs.getInt(key) ?? 0;
    if (count >= AppConfig.receiptScansPerDay) {
      throw ReceiptScanLimitException();
    }
    await prefs.setInt(key, count + 1);
  }
}
