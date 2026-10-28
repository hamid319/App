import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:meta/meta.dart';

/// One photo of a journal entry: its Storage path (for deleting) and
/// download URL (for showing), with the pixel size for the layout.
@immutable
class JournalPhoto {
  final String path;
  final String url;
  final int width;
  final int height;

  const JournalPhoto({
    required this.path,
    required this.url,
    required this.width,
    required this.height,
  });

  factory JournalPhoto.fromJson(Map<String, dynamic> json) => JournalPhoto(
        path: json['path'] as String? ?? '',
        url: json['url'] as String? ?? '',
        width: (json['width'] as num?)?.toInt() ?? 0,
        height: (json['height'] as num?)?.toInt() ?? 0,
      );

  Map<String, dynamic> toJson() =>
      {'path': path, 'url': url, 'width': width, 'height': height};
}

/// A memory of a trip: `groups/{groupId}/journal/{entryId}`. Text and/or
/// up to [maxPhotos] photos, filed under one trip day ([day], yyyy-MM-dd).
@immutable
class JournalEntry {
  final String id;
  final String authorUid;
  final String day;
  final String text;
  final List<JournalPhoto> photos;
  final DateTime? createdAt;

  static const maxTextLength = 500;
  static const maxPhotos = 6;

  const JournalEntry({
    required this.id,
    required this.authorUid,
    required this.day,
    this.text = '',
    this.photos = const [],
    this.createdAt,
  });

  factory JournalEntry.fromJson(String id, Map<String, dynamic> json) =>
      JournalEntry(
        id: id,
        authorUid: json['authorUid'] as String? ?? '',
        day: json['day'] as String? ?? '',
        text: json['text'] as String? ?? '',
        photos: [
          for (final p in json['photos'] as List? ?? const [])
            if (p is Map) JournalPhoto.fromJson(Map<String, dynamic>.from(p)),
        ],
        createdAt: json['createdAt'] is Timestamp
            ? (json['createdAt'] as Timestamp).toDate()
            : null,
      );

  /// For a new entry: both times are the server's.
  Map<String, dynamic> toJson() => {
        'authorUid': authorUid,
        'day': day,
        'text': text,
        'photos': [for (final p in photos) p.toJson()],
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      };
}

/// [date] as a journal day key, yyyy-MM-dd.
String journalDayKey(DateTime date) =>
    '${date.year.toString().padLeft(4, '0')}-'
    '${date.month.toString().padLeft(2, '0')}-'
    '${date.day.toString().padLeft(2, '0')}';
