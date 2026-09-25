import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:assisthub/providers/core/constants/app_colors.dart';
import 'package:assisthub/providers/core/constants/app_routes.dart';
import 'package:assisthub/providers/core/constants/app_strings.dart';
import 'package:assisthub/providers/core/utils/helpers.dart';
import 'package:assisthub/providers/core/widgets/empty_state_widget.dart';
import 'package:assisthub/providers/core/widgets/loading_widget.dart';
import 'package:assisthub/data/models/chat_model.dart';
import 'package:assisthub/data/models/user_model.dart';
import 'package:assisthub/providers/auth_provider.dart';
import 'package:assisthub/providers/chat_provider.dart';

class ChatListScreen extends StatefulWidget {
  const ChatListScreen({super.key});

  @override
  State<ChatListScreen> createState() => _ChatListScreenState();
}

class _ChatListScreenState extends State<ChatListScreen> {
  final searchController = TextEditingController();
  String query = '';

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(AppStrings.chat),
      ),
      body: Consumer2<AuthProvider, ChatProvider>(
        builder: (context, authProvider, chatProvider, child) {
          final user = authProvider.user;

          if (user == null || chatProvider.isLoading) {
            return const Center(child: LoadingWidget());
          }

          final rooms = _filteredRooms(chatProvider.chatRooms, user.role);

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                child: TextField(
                  controller: searchController,
                  onChanged: (value) {
                    setState(() => query = value.trim().toLowerCase());
                  },
                  decoration: InputDecoration(
                    hintText: 'Search conversations',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: query.isEmpty
                        ? null
                        : IconButton(
                            icon: const Icon(Icons.close),
                            onPressed: () {
                              searchController.clear();
                              setState(() => query = '');
                            },
                          ),
                  ),
                ),
              ),
              Expanded(
                child: rooms.isEmpty
                    ? const EmptyStateWidget(
                        title: 'No chats yet',
                        message:
                            'Your customer and employee conversations will appear here.',
                        icon: Icons.chat_bubble_outline,
                      )
                    : RefreshIndicator(
                        onRefresh: () async {
                          chatProvider.subscribeToChatRooms(user.id);
                          await chatProvider.loadUnreadCount(user.id);
                        },
                        child: ListView.separated(
                          padding: const EdgeInsets.all(16),
                          itemCount: rooms.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 8),
                          itemBuilder: (context, index) {
                            final room = rooms[index];
                            return _ChatRoomTile(
                              room: room,
                              currentUserId: user.id,
                              currentUserRole: user.role,
                              onTap: () async {
                                await chatProvider.markMessagesAsRead(room.id);
                                if (!context.mounted) return;

                                Navigator.pushNamed(
                                  context,
                                  AppRoutes.chat,
                                  arguments: {
                                    'chatRoomId': room.id,
                                    'otherUserId': _otherUserId(room, user.role),
                                    'otherUserName': _otherUserName(room, user.role),
                                    'otherUserImage': _otherUserImage(room, user.role),
                                  },
                                );
                              },
                            );
                          },
                        ),
                      ),
              ),
            ],
          );
        },
      ),
    );
  }

  List<ChatRoom> _filteredRooms(List<ChatRoom> rooms, UserRole role) {
    if (query.isEmpty) return rooms;

    return rooms.where((room) {
      final otherName = _otherUserName(room, role).toLowerCase();
      final lastMessage = room.lastMessage?.toLowerCase() ?? '';
      return otherName.contains(query) || lastMessage.contains(query);
    }).toList();
  }
}

class _ChatRoomTile extends StatelessWidget {
  final ChatRoom room;
  final String currentUserId;
  final UserRole currentUserRole;
  final VoidCallback onTap;

  const _ChatRoomTile({
    required this.room,
    required this.currentUserId,
    required this.currentUserRole,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final otherName = _otherUserName(room, currentUserRole);
    final otherImage = _otherUserImage(room, currentUserRole);
    final hasUnread = room.unreadCount > 0 &&
        room.lastMessageSenderId != null &&
        room.lastMessageSenderId != currentUserId;

    return Card(
      margin: EdgeInsets.zero,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Stack(
                children: [
                  CircleAvatar(
                    radius: 28,
                    backgroundColor: AppColors.primary.withOpacity(0.1),
                    backgroundImage:
                        otherImage == null ? null : NetworkImage(otherImage),
                    child: otherImage == null
                        ? Text(
                            otherName.isEmpty ? '?' : otherName[0].toUpperCase(),
                            style: const TextStyle(
                              color: AppColors.primary,
                              fontWeight: FontWeight.bold,
                              fontSize: 20,
                            ),
                          )
                        : null,
                  ),
                  if (hasUnread)
                    Positioned(
                      right: 0,
                      top: 0,
                      child: Container(
                        width: 12,
                        height: 12,
                        decoration: BoxDecoration(
                          color: AppColors.secondary,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: Theme.of(context).scaffoldBackgroundColor,
                            width: 2,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            otherName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context)
                                .textTheme
                                .titleMedium
                                ?.copyWith(
                                  fontWeight:
                                      hasUnread ? FontWeight.w800 : FontWeight.w600,
                                ),
                          ),
                        ),
                        if (room.lastMessageTime != null)
                          Text(
                            Helpers.timeAgo(room.lastMessageTime!),
                            style:
                                Theme.of(context).textTheme.bodySmall?.copyWith(
                                      color: hasUnread
                                          ? AppColors.primary
                                          : AppColors.grey500,
                                      fontWeight: hasUnread
                                          ? FontWeight.w700
                                          : FontWeight.w400,
                                    ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            _lastMessageText(room, currentUserId),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style:
                                Theme.of(context).textTheme.bodyMedium?.copyWith(
                                      color: hasUnread
                                          ? AppColors.grey900
                                          : AppColors.grey600,
                                      fontWeight: hasUnread
                                          ? FontWeight.w700
                                          : FontWeight.w400,
                                    ),
                          ),
                        ),
                        if (hasUnread) ...[
                          const SizedBox(width: 8),
                          Container(
                            constraints: const BoxConstraints(
                              minWidth: 22,
                              minHeight: 22,
                            ),
                            padding: const EdgeInsets.symmetric(horizontal: 7),
                            decoration: const BoxDecoration(
                              color: AppColors.primary,
                              shape: BoxShape.circle,
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              room.unreadCount > 99
                                  ? '99+'
                                  : room.unreadCount.toString(),
                              style: const TextStyle(
                                color: AppColors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _lastMessageText(ChatRoom room, String currentUserId) {
    final message = room.lastMessage;
    if (message == null || message.trim().isEmpty) {
      return 'No messages yet';
    }

    if (room.lastMessageSenderId == currentUserId) {
      return 'You: $message';
    }

    return message;
  }
}

String _otherUserId(ChatRoom room, UserRole currentUserRole) {
  return currentUserRole == UserRole.customer ? room.employeeId : room.customerId;
}

String _otherUserName(ChatRoom room, UserRole currentUserRole) {
  return currentUserRole == UserRole.customer
      ? room.employeeName
      : room.customerName;
}

String? _otherUserImage(ChatRoom room, UserRole currentUserRole) {
  return currentUserRole == UserRole.customer
      ? room.employeeImage
      : room.customerImage;
}