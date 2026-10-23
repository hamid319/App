import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../common/models/place_review.dart';
import '../../../common/models/user_model.dart';
import '../../auth/logic/auth_controller.dart';
import '../data/review_repository.dart';

final reviewRepositoryProvider =
    Provider<ReviewRepository>((ref) => ReviewRepository());

/// Visible reviews of a place, newest first.
final placeReviewsProvider =
    StreamProvider.autoDispose.family<List<PlaceReview>, String>((ref, placeId) {
  return ref.watch(reviewRepositoryProvider).watchReviews(placeId);
});

final reviewSummaryProvider =
    FutureProvider.autoDispose.family<ReviewSummary, String>((ref, placeId) {
  return ref.watch(reviewRepositoryProvider).summary(placeId);
});

/// The signed-in user's own review of a place; null for guests.
final myReviewProvider =
    FutureProvider.autoDispose.family<PlaceReview?, String>((ref, placeId) async {
  final user = ref.watch(authControllerProvider).value;
  if (user == null || user.isAnonymous) return null;
  return ref.watch(reviewRepositoryProvider).myReview(placeId, user.uid);
});

/// Writes, deletes and reports reviews for the signed-in user. Guests
/// cannot review; the UI asks them to sign in first.
final reviewControllerProvider =
    NotifierProvider<ReviewController, void>(ReviewController.new);

class ReviewController extends Notifier<void> {
  ReviewRepository get _repo => ref.read(reviewRepositoryProvider);

  @override
  void build() {}

  bool get canReview {
    final user = ref.read(authControllerProvider).value;
    return user != null && !user.isAnonymous;
  }

  Future<void> save({
    required String placeId,
    required int rating,
    required String text,
    required String language,
  }) async {
    final user = _signedInUser();
    await _repo.saveReview(
      placeId: placeId,
      uid: user.uid,
      rating: rating.clamp(1, 5),
      text: text.length > PlaceReview.maxTextLength
          ? text.substring(0, PlaceReview.maxTextLength)
          : text,
      authorName: user.displayName ?? '',
      language: language,
    );
    _refresh(placeId);
  }

  Future<void> delete(String placeId) async {
    await _repo.deleteReview(placeId, _signedInUser().uid);
    _refresh(placeId);
  }

  Future<void> report(PlaceReview review) async {
    await _repo.reportReview(
      placeId: review.placeId,
      authorUid: review.uid,
      reporterUid: _signedInUser().uid,
    );
    _refresh(review.placeId);
  }

  UserModel _signedInUser() {
    final user = ref.read(authControllerProvider).value;
    if (user == null || user.isAnonymous) {
      throw StateError('Only signed-in users can review places.');
    }
    return user;
  }

  void _refresh(String placeId) {
    ref.invalidate(reviewSummaryProvider(placeId));
    ref.invalidate(myReviewProvider(placeId));
  }
}
