import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:assisthub/data/models/tracking_model.dart';

class TrackingRepository {
  final FirebaseFirestore firestore = FirebaseFirestore.instance;
  final String collection = 'tracking';

  /// Employee side: push a location update for an active booking.
  Future<void> updateLocation({
    required String bookingId,
    required String employeeId,
    required double latitude,
    required double longitude,
    double? heading,
  }) async {
    final tracking = TrackingData(
      bookingId: bookingId,
      employeeId: employeeId,
      latitude: latitude,
      longitude: longitude,
      heading: heading,
      updatedAt: DateTime.now(),
    );

    await firestore
        .collection(collection)
        .doc(bookingId)
        .set(tracking.toFirestore(), SetOptions(merge: true));
  }

  /// Customer side: real-time stream of the employee's location for a
  /// given booking. Null when no location has been shared yet.
  Stream<TrackingData?> trackingStream(String bookingId) {
    return firestore
        .collection(collection)
        .doc(bookingId)
        .snapshots()
        .map((doc) => doc.exists ? TrackingData.fromFirestore(doc) : null);
  }

  /// Call when a booking completes/cancels so stale locations don't linger.
  Future<void> clearTracking(String bookingId) async {
    await firestore.collection(collection).doc(bookingId).delete();
  }
}
