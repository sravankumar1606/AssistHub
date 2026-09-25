import 'package:cloud_firestore/cloud_firestore.dart';

class ChatRoom {
  final String id;
  final String customerId;
  final String customerName;
  final String? customerImage;
  final String employeeId;
  final String employeeName;
  final String? employeeImage;
  final String? lastMessage;
  final DateTime? lastMessageTime;
  final String? lastMessageSenderId;
  final int unreadCount;
  final DateTime createdAt;

  ChatRoom({
    required this.id,
    required this.customerId,
    required this.customerName,
    this.customerImage,
    required this.employeeId,
    required this.employeeName,
    this.employeeImage,
    this.lastMessage,
    this.lastMessageTime,
    this.lastMessageSenderId,
    this.unreadCount = 0,
    required this.createdAt,
  });

  factory ChatRoom.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return ChatRoom(
      id: doc.id,
      customerId: data['customerId'] ?? '',
      customerName: data['customerName'] ?? '',
      customerImage: data['customerImage'],
      employeeId: data['employeeId'] ?? '',
      employeeName: data['employeeName'] ?? '',
      employeeImage: data['employeeImage'],
      lastMessage: data['lastMessage'],
      lastMessageTime: (data['lastMessageTime'] as Timestamp?)?.toDate(),
      lastMessageSenderId: data['lastMessageSenderId'],
      unreadCount: data['unreadCount'] ?? 0,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'customerId': customerId,
      'customerName': customerName,
      'customerImage': customerImage,
      'employeeId': employeeId,
      'employeeName': employeeName,
      'employeeImage': employeeImage,
      'lastMessage': lastMessage,
      'lastMessageTime': lastMessageTime != null ? Timestamp.fromDate(lastMessageTime!) : null,
      'lastMessageSenderId': lastMessageSenderId,
      'unreadCount': unreadCount,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }
}

class ChatMessage {
  final String id;
  final String chatRoomId;
  final String senderId;
  final String message;
  final MessageType type;
  final bool isRead;
  final DateTime createdAt;

  ChatMessage({
    required this.id,
    required this.chatRoomId,
    required this.senderId,
    required this.message,
    this.type = MessageType.text,
    this.isRead = false,
    required this.createdAt,
  });

  factory ChatMessage.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return ChatMessage(
      id: doc.id,
      chatRoomId: data['chatRoomId'] ?? '',
      senderId: data['senderId'] ?? '',
      message: data['message'] ?? '',
      type: MessageType.values.firstWhere(
        (e) => e.name == data['type'],
        orElse: () => MessageType.text,
      ),
      isRead: data['isRead'] ?? false,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'chatRoomId': chatRoomId,
      'senderId': senderId,
      'message': message,
      'type': type.name,
      'isRead': isRead,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }
}

enum MessageType { text, image, file }