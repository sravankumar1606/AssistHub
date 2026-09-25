import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:assisthub/providers/core/constants/app_colors.dart';
import 'package:assisthub/providers/core/utils/helpers.dart';
import 'package:assisthub/providers/core/widgets/empty_state_widget.dart';
import 'package:assisthub/providers/core/widgets/loading_widget.dart';
import 'package:assisthub/data/models/chat_model.dart';
import 'package:assisthub/providers/auth_provider.dart';
import 'package:assisthub/providers/chat_provider.dart';

class ChatScreen extends StatefulWidget {
  final String chatRoomId;
  final String otherUserId;
  final String otherUserName;
  final String? otherUserImage;

  const ChatScreen({
    super.key,
    required this.chatRoomId,
    required this.otherUserId,
    required this.otherUserName,
    this.otherUserImage,
  });

  static ChatScreen fromRouteArgs(Object? arguments) {
    final args = arguments as Map<String, dynamic>? ?? {};

    return ChatScreen(
      chatRoomId: args['chatRoomId'] as String? ?? '',
      otherUserId: args['otherUserId'] as String? ?? '',
      otherUserName: args['otherUserName'] as String? ?? 'Chat',
      otherUserImage: args['otherUserImage'] as String?,
    );
  }

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final messageController = TextEditingController();
  final scrollController = ScrollController();
  bool isSending = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final chatProvider = context.read<ChatProvider>();
      chatProvider.subscribeToMessages(widget.chatRoomId);
      chatProvider.markMessagesAsRead(widget.chatRoomId);
    });
  }

  @override
  void dispose() {
    messageController.dispose();
    scrollController.dispose();
    context.read<ChatProvider>().leaveChatRoom();
    super.dispose();
  }

  Future<void> sendMessage() async {
    final text = messageController.text.trim();
    if (text.isEmpty || isSending) return;

    setState(() => isSending = true);
    messageController.clear();

    final chatProvider = context.read<ChatProvider>();
    await chatProvider.sendMessage(text);

    if (!mounted) return;
    setState(() => isSending = false);

    if (chatProvider.error != null) {
      Helpers.showSnackBar(context, chatProvider.error!, isError: true);
    }

    _scrollToBottom();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!scrollController.hasClients) return;
      scrollController.animateTo(
        scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: Row(
             children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: AppColors.primary.withOpacity(0.1),
              backgroundImage: widget.otherUserImage == null
                  ? null
                  : NetworkImage(widget.otherUserImage!),
              child: widget.otherUserImage == null
                  ? Text(
                      widget.otherUserName.isEmpty
                          ? '?'
                          : widget.otherUserName[0].toUpperCase(),
                      style: const TextStyle(
                        color: AppColors.primary,
                        fontWeight: FontWeight.bold,
                      ),
                    )
                  : null,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.otherUserName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  Text(
                    'Realtime chat',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppColors.grey500,
                        ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: Consumer2<AuthProvider, ChatProvider>(
                builder: (context, authProvider, chatProvider, child) {
                  final currentUserId = authProvider.user?.id;

                  if (currentUserId == null || chatProvider.isLoading) {
                    return const Center(child: LoadingWidget());
                  }

                  final messages = chatProvider.messages;

                  if (messages.isEmpty) {
                    return const EmptyStateWidget(
                      title: 'No messages yet',
                      message: 'Start the conversation with a quick message.',
                      icon: Icons.chat_bubble_outline,
                    );
                  }

                  _scrollToBottom();

                  return ListView.builder(
                    controller: scrollController,
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                    itemCount: messages.length,
                    itemBuilder: (context, index) {
                      final message = messages[index];
                      final previous =
                          index == 0 ? null : messages[index - 1];
                      final showDateHeader = previous == null ||
                          !message.createdAt.isSameDay(previous.createdAt);

                      return Column(
                        children: [
                          if (showDateHeader)
                            _DateHeader(date: message.createdAt),
                          _MessageBubble(
                            message: message,
                            isMe: message.senderId == currentUserId,
                          ),
                        ],
                      );
                    },
                  );
                },
              ),
            ),
            _MessageComposer(
              controller: messageController,
              isSending: isSending,
              onSend: sendMessage,
            ),
          ],
        ),
      ),
      );
  }
}

class _DateHeader extends StatelessWidget {
  final DateTime date;

  const _DateHeader({required this.date});

  @override
  Widget build(BuildContext context) {
    final label = date.isToday
        ? 'Today'
        : date.isYesterday
            ? 'Yesterday'
            : Helpers.formatDate(date);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: AppColors.grey200.withOpacity(0.7),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          label,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: AppColors.grey600,
                fontWeight: FontWeight.w600,
              ),
        ),
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  final ChatMessage message;
  final bool isMe;

  const _MessageBubble({
    required this.message,
    required this.isMe,
  });

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.78,
        ),
        child: Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.fromLTRB(14, 10, 14, 8),
          decoration: BoxDecoration(
            gradient: isMe ? AppColors.primaryGradient : null,
            color: isMe ? null : Theme.of(context).cardColor,
            borderRadius: BorderRadius.only(
              topLeft: const Radius.circular(16),
              topRight: const Radius.circular(16),
              bottomLeft: Radius.circular(isMe ? 16 : 4),
              bottomRight: Radius.circular(isMe ? 4 : 16),
            ),
            boxShadow: [
              BoxShadow(
                color: AppColors.grey400.withOpacity(0.12),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment:
                isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
            children: [
              _MessageContent(message: message, isMe: isMe),
              const SizedBox(height: 5),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    Helpers.formatTime(message.createdAt),
                    style: TextStyle(
                      color: isMe
                          ? AppColors.white.withOpacity(0.75)
                          : AppColors.grey500,
                      fontSize: 11,
                    ),
                  ),
                  if (isMe) ...[
                    const SizedBox(width: 5),
                    Icon(
                      message.isRead ? Icons.done_all : Icons.done,
                      size: 15,
                      color: message.isRead
                          ? AppColors.secondaryLight
                          : AppColors.white.withOpacity(0.75),
                    ),
],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MessageContent extends StatelessWidget {
  final ChatMessage message;
  final bool isMe;

  const _MessageContent({
    required this.message,
    required this.isMe,
  });

  @override
  Widget build(BuildContext context) {
    switch (message.type) {
      case MessageType.image:
        return ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: Image.network(
            message.message,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) {
              return _UnsupportedMessage(
                icon: Icons.broken_image_outlined,
                text: 'Image unavailable',
                isMe: isMe,
              );
            },
          ),
        );
      case MessageType.file:
        return _UnsupportedMessage(
          icon: Icons.insert_drive_file_outlined,
          text: 'File attachment',
          isMe: isMe,
        );
      case MessageType.text:
        return Text(
          message.message,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: isMe ? AppColors.white : null,
                height: 1.35,
              ),
        );
    }
  }
}

class _UnsupportedMessage extends StatelessWidget {
  final IconData icon;
  final String text;
  final bool isMe;

  const _UnsupportedMessage({
    required this.icon,
    required this.text,
    required this.isMe,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          icon,
          size: 18,
          color: isMe ? AppColors.white : AppColors.grey600,
        ),
        const SizedBox(width: 8),
        Text(
          text,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: isMe ? AppColors.white : AppColors.grey700,
              ),
        ),
      ],
    );
  }
}

class _MessageComposer extends StatelessWidget {
  final TextEditingController controller;
  final bool isSending;
  final VoidCallback onSend;

  const _MessageComposer({
    required this.controller,
    required this.isSending,
    required this.onSend,
  });
@override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        boxShadow: [
          BoxShadow(
            color: AppColors.grey400.withOpacity(0.16),
            blurRadius: 12,
            offset: const Offset(0, -3),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: TextField(
              controller: controller,
              minLines: 1,
              maxLines: 5,
              textInputAction: TextInputAction.newline,
              decoration: const InputDecoration(
                hintText: 'Type a message',
                prefixIcon: Icon(Icons.message_outlined),
              ),
            ),
          ),
          const SizedBox(width: 10),
          SizedBox(
            height: 52,
            width: 52,
            child: ElevatedButton(
              onPressed: isSending ? null : onSend,
              style: ElevatedButton.styleFrom(
                padding: EdgeInsets.zero,
                shape: const CircleBorder(),
              ),
              child: isSending
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppColors.white,
                      ),
                    )
                  : const Icon(Icons.send),
            ),
          ),
        ],
      ),
    );
  }
}

extension _ChatDateHelpers on DateTime {
  bool isSameDay(DateTime other) {
    return year == other.year && month == other.month && day == other.day;
  }

  bool get isToday => isSameDay(DateTime.now());

  bool get isYesterday {
    return isSameDay(DateTime.now().subtract(const Duration(days: 1)));
  }
}
