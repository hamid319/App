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

  static bool isPathForEntry(Object? path, String groupId, String entryId) {
    if (path is! String) return false;
    final prefix = 'trips/$groupId/journal/$entryId/';
    return path.startsWith(prefix) &&
        RegExp(r'^[0-5]\.jpg$').hasMatch(path.substring(prefix.length));
  }

  /// Only load media from this entry's own object in our Storage bucket.
  static JournalPhoto? fromStorage(
      Object? json, String groupId, String entryId, String bucket) {
    if (json is! Map) return null;
    final path = json['path'];
    final url = json['url'];
    final width = json['width'];
    final height = json['height'];
    if (path is! String ||
        !isPathForEntry(path, groupId, entryId) ||
        url is! String ||
        width is! int ||
        width <= 0 ||
        height is! int ||
        height <= 0) {
      return null;
    }
    final expected = 'https://firebasestorage.googleapis.com/v0/b/$bucket/o/'
        '${Uri.encodeComponent(path)}?alt=media&token=';
    if (!url.startsWith(expected) ||
        !RegExp(r'^[a-zA-Z0-9_-]{1,128}$')
            .hasMatch(url.substring(expected.length))) {
      return null;
    }
    return JournalPhoto(path: path, url: url, width: width, height: height);
  }

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

  factory JournalEntry.fromJson(String id, Map<String, dynamic> json,
          {required String groupId, required String storageBucket}) =>
      JournalEntry(
        id: id,
        authorUid: json['authorUid'] as String? ?? '',
        day: json['day'] as String? ?? '',
        text: json['text'] as String? ?? '',
        photos: [
          if (json['photos'] case final List photos)
            for (final p in photos.take(maxPhotos))
              if (JournalPhoto.fromStorage(p, groupId, id, storageBucket)
                  case final photo?)
                photo,
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
