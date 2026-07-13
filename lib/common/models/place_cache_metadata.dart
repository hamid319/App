import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:meta/meta.dart';

@immutable
class PlaceCacheMetadata {
  const PlaceCacheMetadata({
    required this.cityId,
    required this.fetchedCount,
    required this.requestedLimit,
    required this.isExhausted,
    required this.lastSyncedAt,
    this.schemaVersion = 1,
  });

  final String cityId;
  final int fetchedCount;
  final int requestedLimit;
  final bool isExhausted;
  final DateTime lastSyncedAt;
  final int schemaVersion;

  static PlaceCacheMetadata? tryFromJson(
    Map<String, dynamic>? json, {
    required String expectedCityId,
  }) {
    if (json == null ||
        json['cityId'] != expectedCityId ||
        json['fetchedCount'] is! int ||
        json['requestedLimit'] is! int ||
        json['isExhausted'] is! bool ||
        json['schemaVersion'] != 1) {
      return null;
    }

    final rawLastSyncedAt = json['lastSyncedAt'];
    final lastSyncedAt = switch (rawLastSyncedAt) {
      Timestamp value => value.toDate(),
      DateTime value => value,
      _ => null,
    };
    final fetchedCount = json['fetchedCount'] as int;
    final requestedLimit = json['requestedLimit'] as int;
    if (lastSyncedAt == null || fetchedCount < 0 || requestedLimit < 1) {
      return null;
    }

    return PlaceCacheMetadata(
      cityId: expectedCityId,
      fetchedCount: fetchedCount,
      requestedLimit: requestedLimit,
      isExhausted: json['isExhausted'] as bool,
      lastSyncedAt: lastSyncedAt,
    );
  }

  bool isConsistentWithCache(int cachedCount) => fetchedCount == cachedCount;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'cityId': cityId,
        'fetchedCount': fetchedCount,
        'requestedLimit': requestedLimit,
        'isExhausted': isExhausted,
        'lastSyncedAt': Timestamp.fromDate(lastSyncedAt),
        'schemaVersion': schemaVersion,
      };
}
