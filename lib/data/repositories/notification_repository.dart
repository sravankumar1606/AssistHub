import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/notification_model.dart';

class NotificationRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final String _collection = 'notifications';

  Future<void> createNotification(NotificationModel notification) async {
    await _firestore.collection(_collection).add(notification.toFirestore());
  }

  Stream<List<NotificationModel>> userNotificationsStream(String userId) {
    return _firestore
        .collection(_collection)
        .where('userId', isEqualTo: userId)
        .snapshots()
        .map((snapshot) => _sortNewestFirst(
              snapshot.docs
                  .map((doc) => NotificationModel.fromFirestore(doc))
                  .toList(),
            ).take(50).toList());
  }

  Future<void> markAsRead(String notificationId) async {
    await _firestore.collection(_collection).doc(notificationId).update({
      'isRead': true,
    });
  }

  Future<void> markAllAsRead(String userId) async {
    final batch = _firestore.batch();
    final notifications = await _firestore
        .collection(_collection)
        .where('userId', isEqualTo: userId)
        .where('isRead', isEqualTo: false)
        .get();

    for (final doc in notifications.docs) {
      batch.update(doc.reference, {'isRead': true});
    }

    await batch.commit();
  }

  Future<int> getUnreadCount(String userId) async {
    final query = await _firestore
        .collection(_collection)
        .where('userId', isEqualTo: userId)
        .where('isRead', isEqualTo: false)
        .count()
        .get();
    return query.count ?? 0;
  }

  Future<void> deleteNotification(String notificationId) async {
    await _firestore.collection(_collection).doc(notificationId).delete();
  }

  List<NotificationModel> _sortNewestFirst(List<NotificationModel> notifications) {
    notifications.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return notifications;
  }
}
