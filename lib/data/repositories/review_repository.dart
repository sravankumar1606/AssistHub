import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:assisthub/data/models/review_model.dart';

class ReviewRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final String _collection = 'reviews';

  Future<void> createReview(ReviewModel review) async {
    await _firestore.collection(_collection).add(review.toFirestore());
  }

  Stream<List<ReviewModel>> employeeReviewsStream(String employeeId) {
    return _firestore
        .collection(_collection)
        .where('employeeId', isEqualTo: employeeId)
        .snapshots()
        .map((snapshot) => _sortNewestFirst(
              snapshot.docs.map((doc) => ReviewModel.fromFirestore(doc)).toList(),
            ));
  }

  Future<List<ReviewModel>> getEmployeeReviews(String employeeId, {int limit = 10}) async {
    final query = await _firestore
        .collection(_collection)
        .where('employeeId', isEqualTo: employeeId)
        .get();
    return _sortNewestFirst(
      query.docs.map((doc) => ReviewModel.fromFirestore(doc)).toList(),
    ).take(limit).toList();
  }

  Future<bool> hasReviewed(String customerId, String bookingId) async {
    final query = await _firestore
        .collection(_collection)
        .where('bookingId', isEqualTo: bookingId)
        .get();
    return query.docs.any((doc) {
      final data = doc.data();
      return data['customerId'] == customerId;
    });
  }

  Future<double> calculateAverageRating(String employeeId) async {
    final stats = await calculateRatingStats(employeeId);
    return stats.averageRating;
  }

  Future<ReviewStats> calculateRatingStats(String employeeId) async {
    final reviews = await _firestore
        .collection(_collection)
        .where('employeeId', isEqualTo: employeeId)
        .get();

    if (reviews.docs.isEmpty) return const ReviewStats(0.0, 0);

    double totalRating = 0;
    for (final doc in reviews.docs) {
      final review = ReviewModel.fromFirestore(doc);
      totalRating += review.rating;
    }

    return ReviewStats(totalRating / reviews.docs.length, reviews.docs.length);
  }

  List<ReviewModel> _sortNewestFirst(List<ReviewModel> reviews) {
    reviews.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return reviews;
  }
}

class ReviewStats {
  final double averageRating;
  final int totalReviews;

  const ReviewStats(this.averageRating, this.totalReviews);
}
