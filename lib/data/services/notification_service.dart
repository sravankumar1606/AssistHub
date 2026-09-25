import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

class NotificationService {
  static final FirebaseMessaging _messaging = FirebaseMessaging.instance;

  static Future<void> initialize() async {
    try {
      await _messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );

      final token = await getToken();
      debugPrint('FCM Token: $token');
    } catch (e) {
      debugPrint('FCM initialization skipped: $e');
    }

    FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

    if (!kIsWeb) {
      FirebaseMessaging.onBackgroundMessage(_handleBackgroundMessage);
    }

    FirebaseMessaging.onMessageOpenedApp.listen(_handleNotificationTap);
  }

  static Future<String?> getToken() async {
    try {
      return await _messaging.getToken();
    } catch (e) {
      debugPrint('Unable to get FCM token: $e');
      return null;
    }
  }

  static void _handleForegroundMessage(RemoteMessage message) {
    debugPrint('Foreground message: ${message.notification?.title}');
    // Show local notification or update UI
  }

  @pragma('vm:entry-point')
  static Future<void> _handleBackgroundMessage(RemoteMessage message) async {
    debugPrint('Background message: ${message.notification?.title}');
  }

  static void _handleNotificationTap(RemoteMessage message) {
    debugPrint('Notification tapped: ${message.data}');
    // Navigate to appropriate screen based on message data
  }

  static Future<void> subscribeToTopic(String topic) async {
    try {
      await _messaging.subscribeToTopic(topic);
    } catch (e) {
      debugPrint('Unable to subscribe to topic $topic: $e');
    }
  }

  static Future<void> unsubscribeFromTopic(String topic) async {
    try {
      await _messaging.unsubscribeFromTopic(topic);
    } catch (e) {
      debugPrint('Unable to unsubscribe from topic $topic: $e');
    }
  }
}
