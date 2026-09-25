import 'package:cloud_firestore/cloud_firestore.dart';

class ReviewModel {
  final String id;
  final String bookingId;
  final String employeeId;
  final String customerId;
  final String customerName;
  final String? customerImage;
  final double rating;
  final String comment;
  final DateTime createdAt;

  ReviewModel({
    required this.id,
    required this.bookingId,
    required this.employeeId,
    required this.customerId,
    required this.customerName,
    this.customerImage,
    required this.rating,
    required this.comment,
    required this.createdAt,
  });

  factory ReviewModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return ReviewModel(
      id: doc.id,
      bookingId: data['bookingId'] ?? '',
      employeeId: data['employeeId'] ?? '',
      customerId: data['customerId'] ?? '',
      customerName: data['customerName'] ?? '',
      customerImage: data['customerImage'],
      rating: (data['rating'] ?? 0).toDouble(),
      comment: data['comment'] ?? '',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'bookingId': bookingId,
      'employeeId': employeeId,
      'customerId': customerId,
      'customerName': customerName,
      'customerImage': customerImage,
      'rating': rating,
      'comment': comment,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }
}
