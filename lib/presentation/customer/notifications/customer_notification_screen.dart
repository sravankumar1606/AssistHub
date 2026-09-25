import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:assisthub/providers/core/constants/app_colors.dart';
import 'package:assisthub/providers/core/constants/app_strings.dart';
import 'package:assisthub/providers/core/utils/helpers.dart';
import 'package:assisthub/providers/core/widgets/empty_state_widget.dart';
import 'package:assisthub/providers/core/widgets/loading_widget.dart';
import 'package:assisthub/data/models/notification_model.dart';
import 'package:assisthub/data/models/booking_model.dart';
import 'package:assisthub/providers/notification_provider.dart';
import 'package:assisthub/providers/booking_provider.dart';
import 'package:assisthub/providers/chat_provider.dart';
import 'package:assisthub/providers/auth_provider.dart';
import 'package:assisthub/providers/core/utils/maps_helper.dart';
import 'package:assisthub/presentation/customer/chat/chat_screen.dart';

class CustomerNotificationsScreen extends StatelessWidget {
  const CustomerNotificationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(AppStrings.notifications),
        actions: [
          Consumer<NotificationProvider>(
            builder: (context, provider, _) {
              if (provider.unreadCount > 0) {
                return TextButton(
                  onPressed: () => provider.markAllAsRead(),
                  child: const Text('Mark all read'),
                );
              }
              return const SizedBox.shrink();
            },
          ),
        ],
      ),
      body: Consumer<NotificationProvider>(
        builder: (context, provider, child) {
          if (provider.isLoading) {
            return const Center(child: LoadingWidget());
          }

          if (provider.notifications.isEmpty) {
            return const EmptyStateWidget(
              title: 'No notifications',
              message: 'You will see booking updates and messages here',
              icon: Icons.notifications_none,
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: provider.notifications.length,
            itemBuilder: (context, index) {
              final notification = provider.notifications[index];
              return _buildNotificationCard(context, notification, provider);
            },
          );
        },
      ),
    );
  }

  Widget _buildNotificationCard(
    BuildContext context,
    NotificationModel notification,
    NotificationProvider provider,
  ) {
    return Dismissible(
      key: Key(notification.id),
      direction: DismissDirection.endToStart,
      onDismissed: (_) => provider.deleteNotification(notification.id),
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        color: AppColors.error,
        child: const Icon(Icons.delete, color: AppColors.white),
      ),
      child: Card(
        margin: const EdgeInsets.only(bottom: 8),
        color: notification.isRead ? null : AppColors.primary.withOpacity(0.05),
        child: InkWell(
          onTap: () {
            if (!notification.isRead) {
              provider.markAsRead(notification.id);
            }
            _openBookingNotification(context, notification);
          },
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: _getNotificationColor(notification.type).withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    _getNotificationIcon(notification.type),
                    color: _getNotificationColor(notification.type),
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        notification.title,
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                              fontWeight: notification.isRead
                                  ? FontWeight.normal
                                  : FontWeight.bold,
                            ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        notification.body,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: AppColors.grey600,
                            ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        Helpers.timeAgo(notification.createdAt),
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: AppColors.grey500,
                              fontSize: 11,
                            ),
                      ),
                    ],
                  ),
                ),
                if (!notification.isRead)
                  Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                      color: AppColors.primary,
                      shape: BoxShape.circle,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  IconData _getNotificationIcon(NotificationType type) {
    switch (type) {
      case NotificationType.bookingRequest:
        return Icons.event_note;
      case NotificationType.bookingAccepted:
        return Icons.check_circle;
      case NotificationType.bookingRejected:
        return Icons.cancel;
      case NotificationType.bookingCancelled:
        return Icons.event_busy;
      case NotificationType.statusUpdate:
        return Icons.update;
      case NotificationType.newMessage:
        return Icons.message;
      case NotificationType.review:
        return Icons.star;
      case NotificationType.general:
        return Icons.notifications;
    }
  }

  Color _getNotificationColor(NotificationType type) {
    switch (type) {
      case NotificationType.bookingRequest:
        return AppColors.info;
      case NotificationType.bookingAccepted:
        return AppColors.success;
      case NotificationType.bookingRejected:
        return AppColors.error;
      case NotificationType.bookingCancelled:
        return AppColors.error;
      case NotificationType.statusUpdate:
        return AppColors.primary;
      case NotificationType.newMessage:
        return AppColors.secondary;
      case NotificationType.review:
        return AppColors.warning;
      case NotificationType.general:
        return AppColors.grey600;
    }
  }

  void _openBookingNotification(
    BuildContext context,
    NotificationModel notification,
  ) {
    final isBookingNotification = {
      NotificationType.bookingRequest,
      NotificationType.bookingAccepted,
      NotificationType.bookingRejected,
      NotificationType.bookingCancelled,
      NotificationType.statusUpdate,
    }.contains(notification.type);

    if (!isBookingNotification) return;

    final bookingId = notification.data?['bookingId'] as String?;
    if (bookingId == null || bookingId.isEmpty) return;

    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) => _BookingDetailSheet(bookingId: bookingId),
    );
  }
}

class _BookingDetailSheet extends StatelessWidget {
  const _BookingDetailSheet({required this.bookingId});

  final String bookingId;

  Future<void> _openChat(BuildContext context, BookingModel booking) async {
    final currentUser = context.read<AuthProvider>().user;
    if (currentUser == null) return;

    final chatRoomId = await context.read<ChatProvider>().createOrGetChatRoom(
          customerId: currentUser.id,
          customerName: currentUser.name,
          employeeId: booking.employeeId,
          employeeName: booking.employeeName,
        );

    if (!context.mounted) return;
    Navigator.pop(context); // close the sheet first
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ChatScreen(
          chatRoomId: chatRoomId,
          otherUserId: booking.employeeId,
          otherUserName: booking.employeeName,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.read<BookingProvider>();

    return SafeArea(
      child: StreamBuilder<BookingModel?>(
        stream: provider.bookingStream(bookingId),
        builder: (context, snapshot) {
          final booking = snapshot.data;
          if (booking == null) {
            return const Padding(
              padding: EdgeInsets.all(24),
              child: Center(child: LoadingWidget()),
            );
          }

          return DraggableScrollableSheet(
            expand: false,
            initialChildSize: 0.82,
            minChildSize: 0.45,
            maxChildSize: 0.95,
            builder: (context, scrollController) {
              return ListView(
                controller: scrollController,
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Booking Details',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                      ),
                      _StatusChip(status: booking.statusDisplayName),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _DetailTile(
                    icon: Icons.person_outline,
                    title: 'Provider',
                    value: booking.employeeName.isEmpty
                        ? 'Not yet assigned'
                        : booking.employeeName,
                  ),
                  if (booking.employeePhone.isNotEmpty)
                    _DetailTile(
                      icon: Icons.phone_outlined,
                      title: 'Phone',
                      value: booking.employeePhone,
                    ),
                  _DetailTile(
                    icon: Icons.home_repair_service_outlined,
                    title: 'Service',
                    value: booking.serviceCategory,
                  ),
                  _DetailTile(
                    icon: Icons.description_outlined,
                    title: 'Details',
                    value: booking.serviceDetails.isEmpty
                        ? 'No details provided'
                        : booking.serviceDetails,
                  ),
                  _DetailTile(
                    icon: Icons.schedule,
                    title: 'Scheduled',
                    value:
                        '${Helpers.formatDate(booking.scheduledDate)} at ${booking.scheduledTime}',
                  ),
                  InkWell(
                    onTap: () => booking.hasPreciseLocation
                        ? MapsHelper.openCoordinates(
                            booking.customerLatitude!, booking.customerLongitude!)
                        : MapsHelper.openAddress(booking.customerAddress),
                    child: _DetailTile(
                      icon: Icons.location_on_outlined,
                      title: 'Address',
                      value: booking.customerAddress,
                    ),
                  ),
                  _DetailTile(
                    icon: Icons.payments_outlined,
                    title: 'Amount',
                    value: Helpers.formatCurrency(booking.amount),
                  ),
                  if (booking.cancellationReason != null &&
                      booking.cancellationReason!.trim().isNotEmpty)
                    _DetailTile(
                      icon: Icons.info_outline,
                      title: 'Cancellation Reason',
                      value: booking.cancellationReason!,
                    ),
                  const SizedBox(height: 16),
                  if (booking.status != BookingStatus.pending &&
                      booking.status != BookingStatus.rejected &&
                      booking.status != BookingStatus.cancelled &&
                      booking.employeeId.isNotEmpty)
                    ElevatedButton.icon(
                      onPressed: () => _openChat(context, booking),
                      icon: const Icon(Icons.chat_bubble_outline),
                      label: const Text('Message Provider'),
                    ),
                ],
              );
            },
          );
        },
      ),
    );
  }
}

class _DetailTile extends StatelessWidget {
  const _DetailTile({
    required this.icon,
    required this.title,
    required this.value,
  });

  final IconData icon;
  final String title;
  final String value;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon, color: AppColors.primary),
      title: Text(title),
      subtitle: Text(value),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final color = Helpers.getStatusColor(status);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        status,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
