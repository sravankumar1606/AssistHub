import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:assisthub/data/models/notification_model.dart';
import 'package:assisthub/data/repositories/notification_repository.dart';

/// Lets an admin send a notification to everyone, everyone in one role,
/// or one specific person — using your real NotificationModel and
/// NotificationRepository, the same ones BookingProvider already writes
/// through for booking-related notifications.
class AdminBroadcastService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final NotificationRepository _notificationRepository = NotificationRepository();

  // Reuses an existing NotificationType value (seen in booking_provider.dart)
  // since a dedicated 'announcement' case isn't confirmed to exist yet.
  // Swap this once you add one to your enum.
  static const NotificationType _broadcastType = NotificationType.statusUpdate;

  Future<int> sendToAll({required String title, required String body}) async {
    final users = await _firestore.collection('users').get();
    return _sendToDocs(users.docs, title, body);
  }

  Future<int> sendToRole({
    required String role, // 'customer' or 'employee'
    required String title,
    required String body,
  }) async {
    final users =
        await _firestore.collection('users').where('role', isEqualTo: role).get();
    return _sendToDocs(users.docs, title, body);
  }

  Future<void> sendToUserId({
    required String userId,
    required String title,
    required String body,
  }) async {
    await _notificationRepository.createNotification(
      NotificationModel(
        id: '',
        userId: userId,
        title: title,
        body: body,
        type: _broadcastType,
        data: const {},
        createdAt: DateTime.now(),
      ),
    );
  }

  /// Search users by name or email substring, for picking a specific
  /// recipient from a list.
  Future<List<Map<String, dynamic>>> searchUsers(String query) async {
    final all = await _firestore.collection('users').get();
    final lower = query.toLowerCase();

    return all.docs
        .map((doc) => {'id': doc.id, ...doc.data()})
        .where((user) {
          final name = (user['name'] ?? '').toString().toLowerCase();
          final email = (user['email'] ?? '').toString().toLowerCase();
          return name.contains(lower) || email.contains(lower);
        })
        .toList();
  }

  Future<int> _sendToDocs(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
    String title,
    String body,
  ) async {
    // A real Firestore batch (one atomic network call per chunk) instead
    // of many concurrent individual writes — the latter can trigger a
    // known Firestore Web SDK bug ("INTERNAL ASSERTION FAILED: Unexpected
    // state") when too many simultaneous operations hit the SDK at once.
    const chunkSize = 400; // Firestore batches cap at 500 writes
    var sent = 0;
    final now = Timestamp.now();

    for (var i = 0; i < docs.length; i += chunkSize) {
      final chunk = docs.skip(i).take(chunkSize);
      final batch = _firestore.batch();

      for (final userDoc in chunk) {
        final ref = _firestore.collection('notifications').doc();
        batch.set(ref, {
          'userId': userDoc.id,
          'title': title,
          'body': body,
          'type': _broadcastType.name,
          'data': <String, dynamic>{},
          'isRead': false,
          'createdAt': now,
        });
        sent++;
      }

      await batch.commit();
    }

    return sent;
  }
}
