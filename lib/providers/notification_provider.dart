import 'dart:async';
import 'package:flutter/material.dart';
import '../data/models/notification_model.dart';
import '../data/repositories/notification_repository.dart';
import 'auth_provider.dart';

class NotificationProvider extends ChangeNotifier {
  final NotificationRepository _notificationRepository = NotificationRepository();

  AuthProvider? _authProvider;
  List<NotificationModel> _notifications = [];
  int _unreadCount = 0;
  bool _isLoading = false;
  String? _error;

  StreamSubscription<List<NotificationModel>>? _notificationsSubscription;

  List<NotificationModel> get notifications => _notifications;
  int get unreadCount => _unreadCount;
  bool get isLoading => _isLoading;
  String? get error => _error;

  void updateAuth(AuthProvider authProvider) {
    _authProvider = authProvider;
    if (authProvider.user != null) {
      _subscribeToNotifications(authProvider.user!.id);
    }
  }

  void _subscribeToNotifications(String userId) {
    _notificationsSubscription?.cancel();
    _notificationsSubscription = _notificationRepository.userNotificationsStream(userId).listen(
      (notifications) {
        _notifications = notifications;
        _unreadCount = notifications.where((n) => !n.isRead).length;
        notifyListeners();
      },
      onError: (e) {
        _error = e.toString();
        notifyListeners();
      },
    );
  }

  Future<void> markAsRead(String notificationId) async {
    try {
      await _notificationRepository.markAsRead(notificationId);
    } catch (e) {
      _error = e.toString();
    }
  }

  Future<void> markAllAsRead() async {
    if (_authProvider?.user == null) return;
    try {
      await _notificationRepository.markAllAsRead(_authProvider!.user!.id);
    } catch (e) {
      _error = e.toString();
    }
  }

  Future<void> deleteNotification(String notificationId) async {
    try {
      await _notificationRepository.deleteNotification(notificationId);
    } catch (e) {
      _error = e.toString();
    }
  }

  @override
  void dispose() {
    _notificationsSubscription?.cancel();
    super.dispose();
  }
}
