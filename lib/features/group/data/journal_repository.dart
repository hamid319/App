import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';

import '../../../common/models/journal_entry.dart';

/// A picked photo ready for upload: JPEG bytes and pixel size.
typedef JournalPhotoUpload = ({Uint8List bytes, int width, int height});

/// Where journal photos live; an interface so tests can fake Storage.
abstract class JournalPhotoStore {
  /// Uploads [bytes] as a JPEG to [path] and returns its download URL.
  Future<String> upload(String path, Uint8List bytes,
      {required String authorUid});

  /// Deletes [path]; a missing file is not an error.
  Future<void> delete(String path);
}

class FirebaseJournalPhotoStore implements JournalPhotoStore {
  FirebaseJournalPhotoStore([FirebaseStorage? storage]) : _storage = storage;

  final FirebaseStorage? _storage;

  // Resolved lazily, so tests that never upload need no Firebase app.
  FirebaseStorage get _s => _storage ?? FirebaseStorage.instance;

  @override
  Future<String> upload(String path, Uint8List bytes,
      {required String authorUid}) async {
    // A lost connection fails within a minute instead of the 10 min default.
    _s.setMaxUploadRetryTime(const Duration(seconds: 45));
    final ref = _s.ref(path);
    // storage.rules lets the uploader (this metadata) delete the file.
    await ref.putData(
      bytes,
      SettableMetadata(
        contentType: 'image/jpeg',
        customMetadata: {'authorUid': authorUid},
      ),
    );
    return ref.getDownloadURL();
  }

  @override
  Future<void> delete(String path) async {
    try {
      await _s.ref(path).delete();
    } on FirebaseException catch (e) {
      if (e.code != 'object-not-found') rethrow;
    }
  }
}

/// The trip journal: `groups/{groupId}/journal`, photos in Storage under
/// `trips/{groupId}/journal/{entryId}/{index}.jpg`.
class JournalRepository {
  JournalRepository({FirebaseFirestore? firestore, JournalPhotoStore? photos})
      : _db = firestore ?? FirebaseFirestore.instance,
        _photos = photos ?? FirebaseJournalPhotoStore();

  final FirebaseFirestore _db;
  final JournalPhotoStore _photos;

  CollectionReference<Map<String, dynamic>> _journal(String groupId) =>
      _db.collection('groups').doc(groupId).collection('journal');

  /// Entries by day, then by creation (pending writes last). Sorted here,
  /// not in the query, so no composite index is needed.
  Stream<List<JournalEntry>> streamEntries(String groupId) =>
      _journal(groupId).snapshots().map((snap) {
        final list = [
          for (final d in snap.docs) JournalEntry.fromJson(d.id, d.data()),
        ];
        final far = DateTime(9999);
        list.sort((a, b) {
          final byDay = a.day.compareTo(b.day);
          if (byDay != 0) return byDay;
          return (a.createdAt ?? far).compareTo(b.createdAt ?? far);
        });
        return list;
      });

  /// Uploads [photos], then writes the entry. If an upload fails, the
  /// files uploaded so far are deleted and the error is rethrown.
  Future<String> addEntry(
    String groupId, {
    required String authorUid,
    required String day,
    required String text,
    List<JournalPhotoUpload> photos = const [],
    void Function(int done, int total)? onProgress,
  }) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty && photos.isEmpty) {
      throw ArgumentError('An entry needs text or a photo');
    }
    if (trimmed.length > JournalEntry.maxTextLength) {
      throw ArgumentError('Text too long');
    }
    if (photos.length > JournalEntry.maxPhotos) {
      throw ArgumentError('Too many photos');
    }
    final ref = _journal(groupId).doc();
    final uploaded = <JournalPhoto>[];
    try {
      for (final (i, p) in photos.indexed) {
        final path = 'trips/$groupId/journal/${ref.id}/$i.jpg';
        final url = await _photos.upload(path, p.bytes, authorUid: authorUid);
        uploaded.add(JournalPhoto(
            path: path, url: url, width: p.width, height: p.height));
        onProgress?.call(i + 1, photos.length);
      }
    } catch (_) {
      await _deleteFiles(uploaded);
      rethrow;
    }
    await ref.set(JournalEntry(
      id: ref.id,
      authorUid: authorUid,
      day: day,
      text: trimmed,
      photos: uploaded,
    ).toJson());
    return ref.id;
  }

  /// Changes the text; an entry without photos keeps needing text.
  Future<void> editText(String groupId, JournalEntry entry, String text) {
    final trimmed = text.trim();
    if (trimmed.isEmpty && entry.photos.isEmpty) {
      throw ArgumentError('An entry needs text or a photo');
    }
    if (trimmed.length > JournalEntry.maxTextLength) {
      throw ArgumentError('Text too long');
    }
    return _journal(groupId).doc(entry.id).update({
      'text': trimmed,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Deletes the entry's photos, then the entry.
  Future<void> deleteEntry(String groupId, JournalEntry entry) async {
    for (final p in entry.photos) {
      await _photos.delete(p.path);
    }
    await _journal(groupId).doc(entry.id).delete();
  }

  Future<void> _deleteFiles(List<JournalPhoto> photos) async {
    for (final p in photos) {
      try {
        await _photos.delete(p.path);
      } catch (_) {
        // Best effort: the original upload error matters more.
      }
    }
  }
}
