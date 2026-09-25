import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:assisthub/firebase_options.dart';

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  if (Firebase.apps.isEmpty) {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  }
  debugPrint('Background FCM message: ${message.messageId}');
}

class FirebaseServices {
  FirebaseServices._();

  // Cleaned up Getters
  static FirebaseAuth get auth => FirebaseAuth.instance;
  static FirebaseFirestore get firestore => FirebaseFirestore.instance;
  static FirebaseStorage get storage => FirebaseStorage.instance;
  static FirebaseMessaging get messaging => FirebaseMessaging.instance;

  static bool _initialized = false;

  // Collection References
  static CollectionReference<Map<String, dynamic>> get users =>
      firestore.collection(FirebaseCollections.users);

  static CollectionReference<Map<String, dynamic>> get employees =>
      firestore.collection(FirebaseCollections.employees);

  static CollectionReference<Map<String, dynamic>> get bookings =>
      firestore.collection(FirebaseCollections.bookings);

  static CollectionReference<Map<String, dynamic>> get services =>
      firestore.collection(FirebaseCollections.services);

  static CollectionReference<Map<String, dynamic>> get reviews =>
      firestore.collection(FirebaseCollections.reviews);

  static CollectionReference<Map<String, dynamic>> get chats =>
      firestore.collection(FirebaseCollections.chats);

  static CollectionReference<Map<String, dynamic>> get notifications =>
      firestore.collection(FirebaseCollections.notifications);

  // Auth Helpers
  static User? get currentUser => auth.currentUser;
  static String? get currentUserId => auth.currentUser?.uid;
  static Stream<User?> get authStateChanges => auth.authStateChanges();

  // Safely Unified Initialization Routine
  static Future<void> initialize() async {
    if (_initialized) return;

    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
    }

    // Isolate web builds from background isolates
    if (!kIsWeb) {
      FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
    }

    firestore.settings = const Settings(
      persistenceEnabled: true,
      cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
    );

    await _configureMessaging();
    _initialized = true;
  }

  // Messaging Permission & Token Logic
  static Future<NotificationSettings> requestNotificationPermission() {
    return messaging.requestPermission(
      alert: true,
      announcement: false,
      badge: true,
      carPlay: false,
      criticalAlert: false,
      provisional: false,
      sound: true,
    );
  }

  static Future<String?> getFcmToken() async {
    try {
      return await messaging.getToken();
    } catch (e) {
      debugPrint('Unable to get FCM token: $e');
      return null;
    }
  }

  static Future<void> saveCurrentUserFcmToken() async {
    final userId = currentUserId;
    if (userId == null) return;

    final token = await getFcmToken();
    if (token == null || token.isEmpty) return;

    await users.doc(userId).set(
      {
        'fcmToken': token,
        'fcmTokens': FieldValue.arrayUnion([token]),
        'updatedAt': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );
  }

  static Future<void> removeCurrentUserFcmToken() async {
    final userId = currentUserId;
    if (userId == null) return;

    final token = await getFcmToken();
    if (token == null || token.isEmpty) return;

    await users.doc(userId).set(
      {
        'fcmTokens': FieldValue.arrayRemove([token]),
        'updatedAt': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );
  }

  // Streams & Remote Notifications
  static Stream<RemoteMessage> foregroundMessages() {
    return FirebaseMessaging.onMessage;
  }

  static Stream<RemoteMessage> notificationOpenedApp() {
    return FirebaseMessaging.onMessageOpenedApp;
  }

  static Future<RemoteMessage?> initialMessage() {
    return messaging.getInitialMessage();
  }

  static Future<void> subscribeToUserTopics({
    required String userId,
    required String role,
  }) async {
    try {
      await messaging.subscribeToTopic('user_$userId');
      await messaging.subscribeToTopic('role_$role');
    } catch (e) {
      debugPrint('Unable to subscribe to notification topics: $e');
    }
  }

  static Future<void> unsubscribeFromUserTopics({
    required String userId,
    required String role,
  }) async {
    try {
      await messaging.unsubscribeFromTopic('user_$userId');
      await messaging.unsubscribeFromTopic('role_$role');
    } catch (e) {
      debugPrint('Unable to unsubscribe from notification topics: $e');
    }
  }

  // Document Helpers
  static DocumentReference<Map<String, dynamic>> userDoc(String userId) => users.doc(userId);
  static DocumentReference<Map<String, dynamic>> employeeDoc(String employeeId) => employees.doc(employeeId);
  static DocumentReference<Map<String, dynamic>> bookingDoc(String bookingId) => bookings.doc(bookingId);
  static DocumentReference<Map<String, dynamic>> chatDoc(String chatId) => chats.doc(chatId);

  static CollectionReference<Map<String, dynamic>> chatMessages(String chatId) {
    return chatDoc(chatId).collection(FirebaseCollections.messages);
  }

  // Storage Bucket References
  static Reference profileImageRef(String userId, String fileName) {
    return storage.ref().child('profile_images/$userId/$fileName');
  }

  static Reference chatImageRef(String chatId, String fileName) {
    return storage.ref().child('chat_images/$chatId/$fileName');
  }

  static Reference serviceImageRef(String serviceId, String fileName) {
    return storage.ref().child('service_images/$serviceId/$fileName');
  }

  static Future<void> signOut() async {
    await removeCurrentUserFcmToken();
    await auth.signOut();
  }

  static Future<void> _configureMessaging() async {
    try {
      await requestNotificationPermission();
      await messaging.setAutoInitEnabled(true);
    } catch (e) {
      debugPrint('FCM configuration skipped: $e');
      return;
    }

    messaging.onTokenRefresh.listen((token) async {
      final userId = currentUserId;
      if (userId == null || token.isEmpty) return;

      await users.doc(userId).set(
        {
          'fcmToken': token,
          'fcmTokens': FieldValue.arrayUnion([token]),
          'updatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );
    });
  }
}

class FirebaseCollections {
  FirebaseCollections._();

  static const String users = 'users';
  static const String employees = 'employees';
  static const String bookings = 'bookings';
  static const String services = 'services';
  static const String reviews = 'reviews';
  static const String chats = 'chats';
  static const String messages = 'messages';
  static const String notifications = 'notifications';
}

class FirebaseFields {
  FirebaseFields._();

  static const String id = 'id';
  static const String userId = 'userId';
  static const String employeeId = 'employeeId';
  static const String customerId = 'customerId';
  static const String role = 'role';
  static const String status = 'status';
  static const String createdAt = 'createdAt';
  static const String updatedAt = 'updatedAt';
  static const String isRead = 'isRead';
  static const String isAvailable = 'isAvailable';
}
