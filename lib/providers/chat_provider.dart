import 'dart:async';
import 'package:flutter/material.dart';
import 'package:assisthub/data/models/chat_model.dart';
import 'package:assisthub/data/repositories/chat_repository.dart';
import 'package:assisthub/providers/auth_provider.dart';
import 'package:assisthub/providers/complaint_provider.dart';

class ChatProvider extends ChangeNotifier {
  final ChatRepository _chatRepository = ChatRepository();

  AuthProvider? _authProvider;
  List<ChatRoom> _chatRooms = [];
  List<ChatMessage> _messages = [];
  bool _isLoading = false;
  String? _error;
  String? _currentChatRoomId;
  int _unreadCount = 0;

  StreamSubscription<List<ChatRoom>>? _chatRoomsSubscription;
  StreamSubscription<List<ChatMessage>>? _messagesSubscription;

  List<ChatRoom> get chatRooms => _chatRooms;
  List<ChatMessage> get messages => _messages;
  bool get isLoading => _isLoading;
  String? get error => _error;
  int get unreadCount => _unreadCount;

  void updateAuth(AuthProvider authProvider) {
    _authProvider = authProvider;
    if (authProvider.user != null) {
      _subscribeToChatRooms(authProvider.user!.id);
      _loadUnreadCount(authProvider.user!.id);
    }
  }
  

  void _subscribeToChatRooms(String userId) {
    _chatRoomsSubscription?.cancel();
    _chatRoomsSubscription = _chatRepository.userChatRoomsStream(userId).listen(
      (chatRooms) {
        _chatRooms = chatRooms;
        notifyListeners();
      },
      onError: (e) {
        _error = e.toString();
        notifyListeners();
      },
    );
  }

  Future<void> _loadUnreadCount(String userId) async {
    _unreadCount = await _chatRepository.getUnreadCount(userId);
    notifyListeners();
  }

  void subscribeToChatRooms(String userId) => _subscribeToChatRooms(userId);
  Future<void> loadUnreadCount(String userId) async => await _loadUnreadCount(userId);

  Future<String> createOrGetChatRoom({
    required String customerId,
    required String customerName,
    String? customerImage,
    required String employeeId,
    required String employeeName,
    String? employeeImage,
  }) async {
    return await _chatRepository.createOrGetChatRoom(
      customerId: customerId,
      customerName: customerName,
      customerImage: customerImage,
      employeeId: employeeId,
      employeeName: employeeName,
      employeeImage: employeeImage,
    );
  }

  void subscribeToMessages(String chatRoomId) {
    _currentChatRoomId = chatRoomId;
    _messagesSubscription?.cancel();
    _messagesSubscription = _chatRepository.messagesStream(chatRoomId).listen(
      (messages) {
        _messages = messages;
        notifyListeners();
      },
      onError: (e) {
        _error = e.toString();
        notifyListeners();
      },
    );
  }

  Future<void> sendMessage(String message) async {
    if (_currentChatRoomId == null || _authProvider?.user == null) return;

    try {
      await _chatRepository.sendMessage(
        chatRoomId: _currentChatRoomId!,
        senderId: _authProvider!.user!.id,
        message: message,
      );
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }

  Future<void> markMessagesAsRead(String chatRoomId) async {
    if (_authProvider?.user == null) return;
    await _chatRepository.markMessagesAsRead(chatRoomId, _authProvider!.user!.id);
    await _loadUnreadCount(_authProvider!.user!.id);
  }

  void leaveChatRoom() {
    _messagesSubscription?.cancel();
    _currentChatRoomId = null;
    _messages = [];
  }

  @override
  void dispose() {
    _chatRoomsSubscription?.cancel();
    _messagesSubscription?.cancel();
    super.dispose();
  }
}