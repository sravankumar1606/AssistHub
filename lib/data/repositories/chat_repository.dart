import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/chat_model.dart';

class ChatRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final String _chatRoomsCollection = 'chatRooms';
  final String _messagesCollection = 'messages';

  Future<String> createOrGetChatRoom({
    required String customerId,
    required String customerName,
    String? customerImage,
    required String employeeId,
    required String employeeName,
    String? employeeImage,
  }) async {
    // Check if chat room already exists
    final existingRoom = await _firestore
        .collection(_chatRoomsCollection)
        .where('customerId', isEqualTo: customerId)
        .where('employeeId', isEqualTo: employeeId)
        .limit(1)
        .get();

    if (existingRoom.docs.isNotEmpty) {
      return existingRoom.docs.first.id;
    }

    // Create new chat room
    final chatRoom = ChatRoom(
      id: '',
      customerId: customerId,
      customerName: customerName,
      customerImage: customerImage,
      employeeId: employeeId,
      employeeName: employeeName,
      employeeImage: employeeImage,
      createdAt: DateTime.now(),
    );

    final docRef = await _firestore.collection(_chatRoomsCollection).add(chatRoom.toFirestore());
    return docRef.id;
  }

  Stream<List<ChatRoom>> userChatRoomsStream(String userId) {
    return _firestore
        .collection(_chatRoomsCollection)
        .where(Filter.or(
          Filter('customerId', isEqualTo: userId),
          Filter('employeeId', isEqualTo: userId),
        ))
        .orderBy('lastMessageTime', descending: true)
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map((doc) => ChatRoom.fromFirestore(doc)).toList());
  }

  Stream<List<ChatMessage>> messagesStream(String chatRoomId) {
    return _firestore
        .collection(_chatRoomsCollection)
        .doc(chatRoomId)
        .collection(_messagesCollection)
        .orderBy('createdAt', descending: false)
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map((doc) => ChatMessage.fromFirestore(doc)).toList());
  }

  Future<void> sendMessage({
    required String chatRoomId,
    required String senderId,
    required String message,
    MessageType type = MessageType.text,
  }) async {
    final chatMessage = ChatMessage(
      id: '',
      chatRoomId: chatRoomId,
      senderId: senderId,
      message: message,
      type: type,
      createdAt: DateTime.now(),
    );

    // Add message to subcollection
    await _firestore
        .collection(_chatRoomsCollection)
        .doc(chatRoomId)
        .collection(_messagesCollection)
        .add(chatMessage.toFirestore());

    // Update chat room with last message info
    await _firestore.collection(_chatRoomsCollection).doc(chatRoomId).update({
      'lastMessage': message,
      'lastMessageTime': FieldValue.serverTimestamp(),
      'lastMessageSenderId': senderId,
    });
  }

  Future<void> markMessagesAsRead(String chatRoomId, String readerId) async {
    final batch = _firestore.batch();
    
    final unreadMessages = await _firestore
        .collection(_chatRoomsCollection)
        .doc(chatRoomId)
        .collection(_messagesCollection)
        .where('isRead', isEqualTo: false)
        .where('senderId', isNotEqualTo: readerId)
        .get();

    for (final doc in unreadMessages.docs) {
      batch.update(doc.reference, {'isRead': true});
    }

    await batch.commit();
  }

  Future<int> getUnreadCount(String userId) async {
    final chatRooms = await _firestore
        .collection(_chatRoomsCollection)
        .where(Filter.or(
          Filter('customerId', isEqualTo: userId),
          Filter('employeeId', isEqualTo: userId),
        ))
        .get();

    int totalUnread = 0;
    for (final room in chatRooms.docs) {
      final unreadMessages = await _firestore
          .collection(_chatRoomsCollection)
          .doc(room.id)
          .collection(_messagesCollection)
          .where('isRead', isEqualTo: false)
          .where('senderId', isNotEqualTo: userId)
          .count()
          .get();
      totalUnread += unreadMessages.count ?? 0;
    }
    return totalUnread;
  }
}