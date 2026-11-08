import 'package:cloud_firestore/cloud_firestore.dart';

/// Tips from locals ("what is a real hidden gem in your city?"), stored
/// under the author: users/{uid}/cityTips/{id}. Only the author can read
/// them in the app; the team reviews them in the console (collection
/// group `cityTips`) before anything reaches the place data.
class CityTipRepository {
  CityTipRepository({FirebaseFirestore? firestore})
      : _db = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;

  static const maxPlaceLength = 80;
  static const maxNoteLength = 280;

  Future<void> submitTip({
    required String uid,
    required String cityId,
    required String place,
    required String note,
    required String language,
  }) {
    final trimmedPlace = place.trim();
    final trimmedNote = note.trim();
    if (trimmedPlace.isEmpty || trimmedPlace.length > maxPlaceLength) {
      throw ArgumentError.value(place, 'place');
    }
    if (trimmedNote.length > maxNoteLength) {
      throw ArgumentError.value(note, 'note');
    }
    return _db.collection('users').doc(uid).collection('cityTips').add({
      'cityId': cityId,
      'place': trimmedPlace,
      'note': trimmedNote,
      'language': language,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }
}
