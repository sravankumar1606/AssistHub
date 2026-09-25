import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:assisthub/providers/core/constants/app_colors.dart';
import 'package:assisthub/providers/auth_provider.dart';
import 'package:assisthub/providers/chat_provider.dart';
import 'package:assisthub/data/models/chat_model.dart';
import 'package:assisthub/presentation/shared/chat/chat_screen.dart';

/// Works for both roles — a customer sees their employee threads, an
/// employee sees their customer threads. ChatProvider already subscribes
/// to the right rooms via updateAuth() in main.dart, so this screen just
/// reads from it.
class ChatListScreen extends StatelessWidget {
  const ChatListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final currentUserId = context.watch<AuthProvider>().user?.id;
    final chatProvider = context.watch<ChatProvider>();

    if (currentUserId == null) {
      return const Scaffold(body: Center(child: Text('Please sign in')));
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Messages')),
      body: Builder(
        builder: (context) {
          if (chatProvider.isLoading && chatProvider.chatRooms.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          }
          if (chatProvider.error != null && chatProvider.chatRooms.isEmpty) {
            return Center(child: Text('Something went wrong: ${chatProvider.error}'));
          }

          final rooms = chatProvider.chatRooms;
          if (rooms.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text('No conversations yet'),
              ),
            );
          }

          return ListView.separated(
            itemCount: rooms.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final room = rooms[index];
              final isCustomerSide = currentUserId == room.customerId;
              final otherName = isCustomerSide ? room.employeeName : room.customerName;
              final otherImage = isCustomerSide ? room.employeeImage : room.customerImage;

              // Heuristic unread indicator: the other person sent the last
              // message and it hasn't been superseded by one of ours yet.
              // For an exact per-room count, add a small stream in
              // ChatRepository that counts unread docs for this room id.
              final looksUnread = room.lastMessageSenderId != null &&
                  room.lastMessageSenderId != currentUserId;

              return ListTile(
                leading: CircleAvatar(
                  radius: 24,
                  backgroundColor: AppColors.primary.withOpacity(0.1),
                  backgroundImage: otherImage != null ? NetworkImage(otherImage) : null,
                  child: otherImage == null
                      ? Text(
                          otherName.isNotEmpty ? otherName[0].toUpperCase() : '?',
                          style: const TextStyle(color: AppColors.primary),
                        )
                      : null,
                ),
                title: Text(
                  otherName,
                  style: TextStyle(
                    fontWeight: looksUnread ? FontWeight.w700 : FontWeight.w500,
                  ),
                ),
                subtitle: Text(
                  room.lastMessage?.isNotEmpty == true ? room.lastMessage! : 'Say hello 👋',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontWeight: looksUnread ? FontWeight.w600 : FontWeight.w400,
                    color: looksUnread
                        ? Theme.of(context).colorScheme.onSurface
                        : AppColors.grey600,
                  ),
                ),
                trailing: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (room.lastMessageTime != null)
                      Text(
                        _formatTime(room.lastMessageTime!),
                        style: TextStyle(
                          fontSize: 12,
                          color: looksUnread ? AppColors.primary : AppColors.grey600,
                        ),
                      ),
                    if (looksUnread) ...[
                      const SizedBox(height: 6),
                      Container(
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(
                          color: AppColors.primary,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ],
                  ],
                ),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => ChatScreen(chatRoom: room)),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }

  String _formatTime(DateTime time) {
    final now = DateTime.now();
    final isToday = now.year == time.year && now.month == time.month && now.day == time.day;
    return isToday ? DateFormat.jm().format(time) : DateFormat.MMMd().format(time);
  }
}