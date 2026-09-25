import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/booking_model.dart';

class BookingRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final String _collection = 'bookings';

  Future<String> createBooking(BookingModel booking) async {
    final docRef = _firestore.collection(_collection).doc();
    final bookingWithId = booking.copyWith(id: docRef.id);
    await docRef.set(bookingWithId.toFirestore());
    return docRef.id;
  }

  Future<BookingModel?> getBooking(String bookingId) async {
    final doc = await _firestore.collection(_collection).doc(bookingId).get();
    if (!doc.exists) return null;
    return BookingModel.fromFirestore(doc);
  }

  Stream<BookingModel?> bookingStream(String bookingId) {
    return _firestore
        .collection(_collection)
        .doc(bookingId)
        .snapshots()
        .map((doc) => doc.exists ? BookingModel.fromFirestore(doc) : null);
  }

  Stream<List<BookingModel>> customerBookingsStream(String customerId) {
    return _firestore
        .collection(_collection)
        .where('customerId', isEqualTo: customerId)
        .snapshots()
        .map((snapshot) => _sortNewestFirst(
              snapshot.docs
                  .map((doc) => BookingModel.fromFirestore(doc))
                  .toList(),
            ));
  }

  Stream<List<BookingModel>> employeeBookingsStream(String employeeId) {
    return _firestore
        .collection(_collection)
        .where('employeeId', isEqualTo: employeeId)
        .snapshots()
        .map((snapshot) => _sortNewestFirst(
              snapshot.docs
                  .map((doc) => BookingModel.fromFirestore(doc))
                  .toList(),
            ));
  }

  Stream<List<BookingModel>> pendingBookingsStream(String employeeId) {
    return _firestore
        .collection(_collection)
        .where('employeeId', isEqualTo: employeeId)
        .where('status', isEqualTo: BookingStatus.pending.name)
        .snapshots()
        .map((snapshot) => _sortNewestFirst(
              snapshot.docs
                  .map((doc) => BookingModel.fromFirestore(doc))
                  .toList(),
            ));
  }

  Stream<List<BookingModel>> activeBookingsStream(String employeeId) {
    return _firestore
        .collection(_collection)
        .where('employeeId', isEqualTo: employeeId)
        .where('status', whereIn: [
          BookingStatus.accepted.name,
          BookingStatus.active.name,
          BookingStatus.onTheWay.name,
          BookingStatus.working.name,
        ])
        .snapshots()
        .map((snapshot) => _sortNewestFirst(
              snapshot.docs
                  .map((doc) => BookingModel.fromFirestore(doc))
                  .toList(),
            ));
  }

  Future<void> updateBookingStatus(String bookingId, BookingStatus status) async {
    await _firestore.collection(_collection).doc(bookingId).update({
      'status': status.name,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> cancelBooking(String bookingId, String reason) async {
    await _firestore.collection(_collection).doc(bookingId).update({
      'status': BookingStatus.cancelled.name,
      'cancellationReason': reason,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<int> getCompletedBookingsCount(String employeeId) async {
    final query = await _firestore
        .collection(_collection)
        .where('employeeId', isEqualTo: employeeId)
        .where('status', isEqualTo: BookingStatus.completed.name)
        .count()
        .get();
    return query.count ?? 0;
  }

  // --- Instant booking (broadcast to all matching employees) ---

  /// Unclaimed instant requests in this category — every employee whose
  /// profile matches sees the same live list. The moment one employee
  /// claims a request (see claimInstantBooking), employeeId stops being
  /// empty, so this query automatically stops matching it for everyone
  /// else — no extra "hide it" logic needed.
  Stream<List<BookingModel>> instantBookingsStream(String serviceCategory) {
    return _firestore
        .collection(_collection)
        .where('isInstant', isEqualTo: true)
        .where('employeeId', isEqualTo: '')
        .where('status', isEqualTo: BookingStatus.pending.name)
        .where('serviceCategory', isEqualTo: serviceCategory)
        .snapshots()
        .map((snapshot) => _sortNewestFirst(
              snapshot.docs
                  .map((doc) => BookingModel.fromFirestore(doc))
                  .toList(),
            ));
  }

  /// Atomically claims an unclaimed instant booking. Whichever employee's
  /// transaction commits first wins — Firestore guarantees only one
  /// transaction succeeds when they race on the same document, so two
  /// employees can never both claim the same request.
  ///
  /// Throws a [StateError] if the request was already claimed (or
  /// cancelled) by the time this transaction runs, so the caller can
  /// show "Someone else already took this job."
  Future<void> claimInstantBooking({
    required String bookingId,
    required String employeeId,
    required String employeeName,
    required String employeePhone,
  }) async {
    final docRef = _firestore.collection(_collection).doc(bookingId);

    await _firestore.runTransaction((transaction) async {
      final snapshot = await transaction.get(docRef);
      if (!snapshot.exists) {
        throw StateError('This request no longer exists.');
      }

      final data = snapshot.data() as Map<String, dynamic>;
      final currentEmployeeId = data['employeeId'] as String? ?? '';
      final currentStatus = data['status'] as String?;

      if (currentEmployeeId.isNotEmpty ||
          currentStatus != BookingStatus.pending.name) {
        throw StateError('Someone else already accepted this request.');
      }

      transaction.update(docRef, {
        'employeeId': employeeId,
        'employeeName': employeeName,
        'employeePhone': employeePhone,
        'status': BookingStatus.accepted.name,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    });
  }

  /// Personal dismiss for one employee — hides this instant request from
  /// just that employee's list without affecting anyone else's, since
  /// the request itself is still open to everyone else in the category.
  Future<void> dismissInstantBookingForEmployee(
    String bookingId,
    String employeeId,
  ) async {
    await _firestore.collection(_collection).doc(bookingId).update({
      'dismissedBy': FieldValue.arrayUnion([employeeId]),
    });
  }

  Future<List<BookingModel>> getRecentBookings(String customerId, {int limit = 5}) async {
    final query = await _firestore
        .collection(_collection)
        .where('customerId', isEqualTo: customerId)
        .get();
    return _sortNewestFirst(
      query.docs.map((doc) => BookingModel.fromFirestore(doc)).toList(),
    ).take(limit).toList();
  }

  List<BookingModel> _sortNewestFirst(List<BookingModel> bookings) {
    bookings.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return bookings;
  }
}
