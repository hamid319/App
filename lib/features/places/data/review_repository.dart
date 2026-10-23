import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../common/models/place_review.dart';

/// Reviews of places at `places/{placeId}/reviews/{uid}`. firestore.rules
/// lets only signed-in (non-guest) users write their own review, and lets
/// others only hide a review by reporting it.
class ReviewRepository {
  final FirebaseFirestore _db;

  ReviewRepository({FirebaseFirestore? firestore})
      : _db = firestore ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> _reviews(String placeId) =>
      _db.collection('places').doc(placeId).collection('reviews');

  /// Visible reviews, newest first.
  Stream<List<PlaceReview>> watchReviews(String placeId, {int limit = 20}) =>
      _reviews(placeId)
          .where('hidden', isEqualTo: false)
          .orderBy('updatedAt', descending: true)
          .limit(limit)
          .snapshots()
          .map((snapshot) => snapshot.docs
              .map((doc) => PlaceReview.fromJson(doc.data()))
              .toList());

  /// Count and average stars of all reviews, hidden ones included: a
  /// report hides the text, not the rating. One aggregation query instead
  /// of reading every review.
  Future<ReviewSummary> summary(String placeId) async {
    final result = await _reviews(placeId)
        .aggregate(count(), average('rating'))
        .get();
    final total = result.count ?? 0;
    if (total == 0) return ReviewSummary.empty;
    return ReviewSummary(count: total, average: result.getAverage('rating'));
  }

  Future<PlaceReview?> myReview(String placeId, String uid) async {
    final doc = await _reviews(placeId).doc(uid).get();
    final data = doc.data();
    return data == null ? null : PlaceReview.fromJson(data);
  }

  /// Creates or replaces the user's review. A hidden review stays hidden
  /// when its author edits it.
  Future<void> saveReview({
    required String placeId,
    required String uid,
    required int rating,
    required String text,
    required String authorName,
    required String language,
  }) async {
    final ref = _reviews(placeId).doc(uid);
    final existing = (await ref.get()).data();
    await ref.set({
      'uid': uid,
      'placeId': placeId,
      'rating': rating,
      'text': text.trim(),
      'authorName': authorName.trim(),
      'language': language,
      'hidden': existing?['hidden'] as bool? ?? false,
      'createdAt': existing?['createdAt'] ?? FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> deleteReview(String placeId, String uid) =>
      _reviews(placeId).doc(uid).delete();

  /// Records the report and hides the review until a moderator checks it
  /// in the Firebase console.
  Future<void> reportReview({
    required String placeId,
    required String authorUid,
    required String reporterUid,
  }) async {
    final review = _reviews(placeId).doc(authorUid);
    final batch = _db.batch()
      ..set(review.collection('reports').doc(reporterUid), {
        'createdAt': FieldValue.serverTimestamp(),
      })
      ..update(review, {'hidden': true});
    await batch.commit();
  }
}
