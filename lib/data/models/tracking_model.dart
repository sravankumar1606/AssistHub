import 'package:cloud_firestore/cloud_firestore.dart';

/// Live location of an employee, scoped to a single active booking.
/// Stored at trackingCollection/{bookingId} and only kept updated while
/// the booking is in an "en route / working" state.
class TrackingData {
  final String bookingId;
  final String employeeId;
  final double latitude;
  final double longitude;
  final double? heading;
  final DateTime updatedAt;

  TrackingData({
    required this.bookingId,
    required this.employeeId,
    required this.latitude,
    required this.longitude,
    this.heading,
    required this.updatedAt,
  });

  factory TrackingData.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return TrackingData(
      bookingId: doc.id,
      employeeId: data['employeeId'] ?? '',
      latitude: (data['latitude'] ?? 0).toDouble(),
      longitude: (data['longitude'] ?? 0).toDouble(),
      heading: (data['heading'] as num?)?.toDouble(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'employeeId': employeeId,
      'latitude': latitude,
      'longitude': longitude,
      'heading': heading,
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }
}
