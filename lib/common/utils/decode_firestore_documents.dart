import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

/// Keep valid records visible if a legacy document cannot be decoded.
List<T> decodeFirestoreDocuments<T>(
  Iterable<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
  T Function(QueryDocumentSnapshot<Map<String, dynamic>>) decode,
) {
  final records = <T>[];
  for (final doc in docs) {
    try {
      records.add(decode(doc));
    } on TypeError {
      debugPrint('Skipping invalid Firestore document ${doc.reference.path}');
    } on FormatException {
      debugPrint('Skipping invalid Firestore document ${doc.reference.path}');
    } on UnsupportedError {
      debugPrint('Skipping invalid Firestore document ${doc.reference.path}');
    }
  }
  return records;
}
