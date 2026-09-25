import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:assisthub/providers/core/constants/app_colors.dart';
import 'package:assisthub/providers/core/constants/app_strings.dart';
import 'package:assisthub/providers/core/utils/helpers.dart';
import 'package:assisthub/providers/core/widgets/empty_state_widget.dart';
import 'package:assisthub/providers/core/widgets/loading_widget.dart';
import 'package:assisthub/data/models/booking_model.dart';
import 'package:assisthub/data/models/notification_model.dart';
import 'package:assisthub/data/repositories/tracking_repository.dart';
import 'package:assisthub/data/services/location_service.dart';
import 'package:assisthub/providers/booking_provider.dart';
import 'package:assisthub/providers/notification_provider.dart';

class EmployeeNotificationsScreen extends StatelessWidget {
  const EmployeeNotificationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(AppStrings.notifications),
        actions: [
          Consumer<NotificationProvider>(
            builder: (context, provider, child) {
              if (provider.unreadCount == 0) {
                return const SizedBox.shrink();
              }

              return TextButton(
                onPressed: provider.markAllAsRead,
                child: const Text('Mark all read'),
              );
            },
          ),
        ],
      ),
      body: Column(
        children: [
          const _LocationSharingBanner(),
          Expanded(
            child: Consumer<NotificationProvider>(
              builder: (context, provider, child) {
                if (provider.isLoading) {
                  return const Center(child: LoadingWidget());
                }

                if (provider.notifications.isEmpty) {
                  return const EmptyStateWidget(
                    title: 'No notifications',
                    message:
                        'Booking requests, chat alerts, and tracking updates appear here.',
                    icon: Icons.notifications_none,
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: provider.notifications.length,
                  itemBuilder: (context, index) {
                    final notification = provider.notifications[index];
                    return _NotificationCard(notification: notification);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

/// Self-contained banner: while the employee has a booking that's
/// "On the way" or "Working", offers a toggle to stream their device
/// location to Firestore (`tracking/{bookingId}`) so the customer can
/// see them live on the tracking screen. Stops automatically and clears
/// the tracking doc when toggled off or when this widget is disposed.
class _LocationSharingBanner extends StatefulWidget {
  const _LocationSharingBanner();

  @override
  State<_LocationSharingBanner> createState() => _LocationSharingBannerState();
}

class _LocationSharingBannerState extends State<_LocationSharingBanner> {
  final LocationService _locationService = LocationService();
  final TrackingRepository _trackingRepository = TrackingRepository();
  StreamSubscription? _positionSubscription;
  String? _trackedBookingId;
  bool _isStarting = false;

  @override
  void dispose() {
    _positionSubscription?.cancel();
    if (_trackedBookingId != null) {
      _trackingRepository.clearTracking(_trackedBookingId!);
    }
    super.dispose();
  }

  Future<void> _start(BookingModel booking) async {
    setState(() => _isStarting = true);

    final hasPermission = await _locationService.ensurePermission();
    if (!hasPermission) {
      if (mounted) {
        setState(() => _isStarting = false);
        Helpers.showSnackBar(
          context,
          'Location permission is needed to share your location with the customer.',
          isError: true,
        );
      }
      return;
    }

    await _positionSubscription?.cancel();
    _trackedBookingId = booking.id;

    _positionSubscription = _locationService.positionStream().listen((position) {
      _trackingRepository.updateLocation(
        bookingId: booking.id,
        employeeId: booking.employeeId,
        latitude: position.latitude,
        longitude: position.longitude,
        heading: position.heading,
      );
    });

    if (mounted) setState(() => _isStarting = false);
  }

  Future<void> _stop() async {
    await _positionSubscription?.cancel();
    _positionSubscription = null;
    if (_trackedBookingId != null) {
      await _trackingRepository.clearTracking(_trackedBookingId!);
    }
    _trackedBookingId = null;
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<BookingProvider>(
      builder: (context, provider, child) {
        final trackable = provider.activeBookings.where(
          (b) => b.status == BookingStatus.onTheWay || b.status == BookingStatus.working,
        );

        if (trackable.isEmpty) {
          if (_trackedBookingId != null) {
            // The job this booking was tracking is no longer eligible
            // (e.g. marked completed elsewhere) — stop silently.
            WidgetsBinding.instance.addPostFrameCallback((_) => _stop());
          }
          return const SizedBox.shrink();
        }

        final booking = trackable.first;
        final isTracking = _trackedBookingId == booking.id;

        return Container(
          width: double.infinity,
          margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isTracking
                ? AppColors.success.withOpacity(0.1)
                : AppColors.primary.withOpacity(0.08),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            children: [
              Icon(
                isTracking ? Icons.location_on : Icons.location_off_outlined,
                color: isTracking ? AppColors.success : AppColors.primary,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isTracking ? 'Sharing your location' : 'Job in progress',
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                    Text(
                      isTracking
                          ? '${booking.customerName} can see your live location'
                          : 'Let ${booking.customerName} track you to the job',
                      style: Theme.of(context)
                          .textTheme
                          .bodySmall
                          ?.copyWith(color: AppColors.grey600),
                    ),
                  ],
                ),
              ),
              _isStarting
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : TextButton(
                      onPressed: isTracking ? _stop : () => _start(booking),
                      child: Text(isTracking ? 'Stop' : 'Start'),
                    ),
            ],
          ),
        );
      },
    );
  }
}

class _NotificationCard extends StatelessWidget {
  const _NotificationCard({required this.notification});

  final NotificationModel notification;

  @override
  Widget build(BuildContext context) {
    final notificationProvider = context.read<NotificationProvider>();
    final color = _colorFor(notification.type);

    return Dismissible(
      key: ValueKey(notification.id),
      direction: DismissDirection.endToStart,
      onDismissed: (_) => notificationProvider.deleteNotification(notification.id),
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(
          color: AppColors.error,
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Icon(Icons.delete_outline, color: AppColors.white),
      ),
      child: Card(
        margin: const EdgeInsets.only(bottom: 10),
        color: notification.isRead ? null : color.withOpacity(0.07),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () {
            if (!notification.isRead) {
              notificationProvider.markAsRead(notification.id);
            }
            _showTrackingSheetIfNeeded(context, notification);
          },
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(_iconFor(notification.type), color: color, size: 20),
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
                                  ? FontWeight.w500
                                  : FontWeight.w800,
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

  void _showTrackingSheetIfNeeded(
    BuildContext context,
    NotificationModel notification,
  ) {
    if (notification.type == NotificationType.bookingCancelled) return;

    final bookingId = notification.data?['bookingId'] as String?;
    if (bookingId == null || bookingId.isEmpty) return;

    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) => _BookingDetailSheet(bookingId: bookingId),
    );
  }

  IconData _iconFor(NotificationType type) {
    switch (type) {
      case NotificationType.bookingRequest:
        return Icons.event_note;
      case NotificationType.bookingAccepted:
        return Icons.check_circle_outline;
      case NotificationType.bookingRejected:
        return Icons.cancel_outlined;
      case NotificationType.bookingCancelled:
        return Icons.event_busy_outlined;
      case NotificationType.statusUpdate:
        return Icons.route_outlined;
      case NotificationType.newMessage:
        return Icons.chat_bubble_outline;
      case NotificationType.review:
        return Icons.star_outline;
      case NotificationType.general:
        return Icons.notifications_outlined;
    }
  }

  Color _colorFor(NotificationType type) {
    switch (type) {
      case NotificationType.bookingRequest:
        return AppColors.warning;
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
}

class _BookingDetailSheet extends StatelessWidget {
  const _BookingDetailSheet({required this.bookingId});

  final String bookingId;

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
                          'Booking Request',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                      ),
                      _StatusChip(status: booking.statusDisplayName),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _DetailTile(
                    icon: Icons.person_outline,
                    title: 'Customer',
                    value: booking.customerName,
                  ),
                  _DetailTile(
                    icon: Icons.phone_outlined,
                    title: 'Phone',
                    value: booking.customerPhone.isEmpty
                        ? 'No phone provided'
                        : booking.customerPhone,
                  ),
                  _DetailTile(
                    icon: Icons.location_on_outlined,
                    title: 'Work Address',
                    value: booking.customerAddress.isEmpty
                        ? 'No address provided'
                        : booking.customerAddress,
                  ),
                  _DetailTile(
                    icon: Icons.schedule,
                    title: 'Work Time',
                    value:
                        '${Helpers.formatDate(booking.scheduledDate)} at ${booking.scheduledTime}',
                  ),
                  _DetailTile(
                    icon: Icons.home_repair_service_outlined,
                    title: 'Service',
                    value: booking.serviceCategory,
                  ),
                  _DetailTile(
                    icon: Icons.description_outlined,
                    title: 'Work Details',
                    value: booking.serviceDetails.isEmpty
                        ? 'No service details provided'
                        : booking.serviceDetails,
                  ),
                  if (booking.notes != null && booking.notes!.trim().isNotEmpty)
                    _DetailTile(
                      icon: Icons.note_outlined,
                      title: 'Customer Notes',
                      value: booking.notes!,
                    ),
                  _DetailTile(
                    icon: Icons.payments_outlined,
                    title: 'Amount',
                    value: Helpers.formatCurrency(booking.amount),
                  ),
                  const SizedBox(height: 16),
                  _ActionsForBooking(
                    booking: booking,
                    provider: provider,
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

class _ActionsForBooking extends StatelessWidget {
  const _ActionsForBooking({
    required this.booking,
    required this.provider,
  });

  final BookingModel booking;
  final BookingProvider provider;

  @override
  Widget build(BuildContext context) {
    if (booking.status == BookingStatus.pending) {
      return Row(
        children: [
          Expanded(
            child: OutlinedButton.icon(
              onPressed: () => _update(context, provider, BookingStatus.rejected),
              icon: const Icon(Icons.close),
              label: const Text('Reject'),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: ElevatedButton.icon(
              onPressed: () => _update(context, provider, BookingStatus.accepted),
              icon: const Icon(Icons.check),
              label: const Text('Accept'),
            ),
          ),
        ],
      );
    }

    if ({
      BookingStatus.accepted,
      BookingStatus.active,
      BookingStatus.onTheWay,
      BookingStatus.working,
    }.contains(booking.status)) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Update Tracking',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          _StatusTile(
            icon: Icons.navigation_outlined,
            label: 'On the way',
            onTap: () => _update(context, provider, BookingStatus.onTheWay),
          ),
          _StatusTile(
            icon: Icons.build_outlined,
            label: 'Working',
            onTap: () => _update(context, provider, BookingStatus.working),
          ),
          _StatusTile(
            icon: Icons.task_alt,
            label: 'Completed',
            onTap: () => _update(context, provider, BookingStatus.completed),
          ),
        ],
      );
    }

    return const SizedBox.shrink();
  }

  Future<void> _update(
    BuildContext context,
    BookingProvider provider,
    BookingStatus status,
  ) async {
    final success = await provider.updateBookingStatus(booking.id, status);
    if (!context.mounted) return;

    Navigator.pop(context);
    Helpers.showSnackBar(
      context,
      success ? 'Tracking updated' : provider.error ?? 'Update failed',
      isError: !success,
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

class _StatusTile extends StatelessWidget {
  const _StatusTile({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon, color: AppColors.primary),
      title: Text(label),
      trailing: const Icon(Icons.chevron_right),
      onTap: onTap,
    );
  }
}