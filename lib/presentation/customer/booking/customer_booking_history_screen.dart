import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:assisthub/providers/core/constants/app_colors.dart';
import 'package:assisthub/providers/core/utils/helpers.dart';
import 'package:assisthub/providers/core/widgets/custom_button.dart';
import 'package:assisthub/providers/core/widgets/empty_state_widget.dart';
import 'package:assisthub/providers/core/widgets/loading_widget.dart';
import 'package:assisthub/data/models/booking_model.dart';
import 'package:assisthub/data/models/notification_model.dart';
import 'package:assisthub/data/models/review_model.dart';
import 'package:assisthub/data/repositories/employee_repository.dart';
import 'package:assisthub/data/repositories/notification_repository.dart';
import 'package:assisthub/data/repositories/review_repository.dart';
import 'package:assisthub/providers/auth_provider.dart';
import 'package:assisthub/providers/booking_provider.dart';
import 'package:assisthub/providers/chat_provider.dart';
import 'package:assisthub/presentation/customer/chat/chat_screen.dart';

enum CustomerBookingView { active, history }

class CustomerBookingHistoryScreen extends StatelessWidget {
  const CustomerBookingHistoryScreen({
    super.key,
    this.initialView = CustomerBookingView.history,
  });

  final CustomerBookingView initialView;

  @override
  Widget build(BuildContext context) {
    final initialIndex = initialView == CustomerBookingView.active ? 0 : 1;

    return DefaultTabController(
      length: 2,
      initialIndex: initialIndex,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('My Bookings'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Active'),
              Tab(text: 'History'),
            ],
          ),
        ),
        body: Consumer<BookingProvider>(
          builder: (context, provider, child) {
            if (provider.isLoading) {
              return const Center(child: LoadingWidget());
            }

            final activeBookings = provider.bookings
                .where(_isActiveBooking)
                .toList();
            final historyBookings = provider.bookings;

            return TabBarView(
              children: [
                _BookingList(
                  bookings: activeBookings,
                  emptyTitle: 'No active bookings',
                  emptyMessage: 'Your pending and ongoing bookings appear here.',
                ),
                _BookingList(
                  bookings: historyBookings,
                  emptyTitle: 'No booking history',
                  emptyMessage: 'Once you book an employee, the details appear here.',
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  static bool _isActiveBooking(BookingModel booking) {
    return {
      BookingStatus.pending,
      BookingStatus.accepted,
      BookingStatus.active,
      BookingStatus.onTheWay,
      BookingStatus.working,
    }.contains(booking.status);
  }
}

class _BookingList extends StatelessWidget {
  const _BookingList({
    required this.bookings,
    required this.emptyTitle,
    required this.emptyMessage,
  });

  final List<BookingModel> bookings;
  final String emptyTitle;
  final String emptyMessage;

  @override
  Widget build(BuildContext context) {
    if (bookings.isEmpty) {
      return EmptyStateWidget(
        title: emptyTitle,
        message: emptyMessage,
        icon: Icons.event_note_outlined,
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: bookings.length,
      itemBuilder: (context, index) {
        return _CustomerBookingCard(booking: bookings[index]);
      },
    );
  }
}

class _CustomerBookingCard extends StatelessWidget {
  const _CustomerBookingCard({required this.booking});

  final BookingModel booking;
  static final ReviewRepository _reviewRepository = ReviewRepository();
  static final EmployeeRepository _employeeRepository = EmployeeRepository();
  static final NotificationRepository _notificationRepository =
      NotificationRepository();

  @override
  Widget build(BuildContext context) {
    final statusColor = Helpers.getStatusColor(booking.status.name);

    return Card(
      margin: const EdgeInsets.only(bottom: 14),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: AppColors.primary.withOpacity(0.1),
                  child: Text(
                    booking.employeeName.isNotEmpty
                        ? booking.employeeName[0].toUpperCase()
                        : '?',
                    style: const TextStyle(
                      color: AppColors.primary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        booking.employeeName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        booking.serviceCategory,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: AppColors.primary,
                              fontWeight: FontWeight.w600,
                            ),
                      ),
                    ],
                  ),
                ),
                _StatusChip(
                  label: booking.statusDisplayName,
                  color: statusColor,
                ),
              ],
            ),
            const SizedBox(height: 16),
            _InfoRow(
              icon: Icons.schedule,
              text:
                  '${Helpers.formatDate(booking.scheduledDate)} at ${booking.scheduledTime}',
            ),
            const SizedBox(height: 8),
            _InfoRow(
              icon: Icons.phone_outlined,
              text: booking.employeePhone.isEmpty
                  ? 'No employee phone provided'
                  : booking.employeePhone,
            ),
            if (booking.serviceDetails.trim().isNotEmpty) ...[
              const SizedBox(height: 8),
              _InfoRow(
                icon: Icons.description_outlined,
                text: booking.serviceDetails,
              ),
            ],
            if (booking.cancellationReason != null &&
                booking.cancellationReason!.trim().isNotEmpty) ...[
              const SizedBox(height: 8),
              _InfoRow(
                icon: Icons.info_outline,
                text: 'Cancelled: ${booking.cancellationReason}',
              ),
            ],
            if (_canChat(booking.status)) ...[
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerRight,
                child: OutlinedButton.icon(
                  onPressed: () => _openChat(context, booking),
                  icon: const Icon(Icons.chat_bubble_outline, size: 18),
                  label: const Text('Chat'),
                ),
              ),
            ],
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: Text(
                    Helpers.formatCurrency(booking.amount),
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          color: AppColors.primary,
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                ),
                if (_canCancel(booking.status))
                  CustomButton(
                    text: 'Cancel',
                    height: 42,
                    isOutlined: true,
                    backgroundColor: AppColors.error,
                    textColor: AppColors.error,
                    onPressed: () => _confirmCancel(context),
                  ),
                if (booking.status == BookingStatus.completed)
                  _ReviewAction(
                    booking: booking,
                    reviewRepository: _reviewRepository,
                    employeeRepository: _employeeRepository,
                    notificationRepository: _notificationRepository,
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  bool _canCancel(BookingStatus status) {
    return {
      BookingStatus.pending,
      BookingStatus.accepted,
      BookingStatus.active,
      BookingStatus.onTheWay,
    }.contains(status);
  }

  bool _canChat(BookingStatus status) {
    return status != BookingStatus.pending &&
        status != BookingStatus.rejected &&
        status != BookingStatus.cancelled;
  }

  /// Ensures a chat room exists for this booking's customer/employee pair
  /// (creating it on first use) and opens the conversation.
  Future<void> _openChat(BuildContext context, BookingModel booking) async {
    final chatProvider = context.read<ChatProvider>();
    final currentUser = context.read<AuthProvider>().user;
    if (currentUser == null) return;

    final chatRoomId = await chatProvider.createOrGetChatRoom(
      customerId: currentUser.id,
      customerName: currentUser.name,
      customerImage: currentUser.profileImage,
      employeeId: booking.employeeId,
      employeeName: booking.employeeName,
    );

    if (!context.mounted) return;

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

  Future<void> _confirmCancel(BuildContext context) async {
    final reasonController = TextEditingController();
    final reason = await showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Cancel booking'),
          content: TextField(
            controller: reasonController,
            decoration: const InputDecoration(
              labelText: 'Reason',
              hintText: 'Tell the employee why you are cancelling',
            ),
            maxLines: 3,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Back'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(
                  context,
                  reasonController.text.trim().isEmpty
                      ? 'Cancelled by customer'
                      : reasonController.text.trim(),
                );
              },
              child: const Text('Cancel booking'),
            ),
          ],
        );
      },
    );
    reasonController.dispose();

    if (reason == null || !context.mounted) return;

    final provider = context.read<BookingProvider>();
    final success = await provider.cancelBooking(booking.id, reason);
    if (!context.mounted) return;

    Helpers.showSnackBar(
      context,
      success ? 'Booking cancelled.' : provider.error ?? 'Cancellation failed.',
      isError: !success,
    );
  }
}

class _ReviewAction extends StatefulWidget {
  const _ReviewAction({
    required this.booking,
    required this.reviewRepository,
    required this.employeeRepository,
    required this.notificationRepository,
  });

  final BookingModel booking;
  final ReviewRepository reviewRepository;
  final EmployeeRepository employeeRepository;
  final NotificationRepository notificationRepository;

  @override
  State<_ReviewAction> createState() => _ReviewActionState();
}

class _ReviewActionState extends State<_ReviewAction> {
  bool _submitted = false;

  @override
  Widget build(BuildContext context) {
    final customerId = context.read<AuthProvider>().user?.id;
    if (customerId == null) return const SizedBox.shrink();
    if (_submitted) return _reviewedLabel();

    return FutureBuilder<bool>(
      future: widget.reviewRepository.hasReviewed(customerId, widget.booking.id),
      builder: (context, snapshot) {
        final hasReviewed = snapshot.data ?? false;
        if (hasReviewed) {
          return _reviewedLabel();
        }

        return CustomButton(
          text: 'Review',
          height: 42,
          onPressed: snapshot.connectionState == ConnectionState.waiting
              ? null
              : () => _showReviewDialog(context),
        );
      },
    );
  }

  Future<void> _showReviewDialog(BuildContext context) async {
    final commentController = TextEditingController();
    double rating = 5;

    final submitted = await showDialog<bool>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: Text('Rate ${widget.booking.employeeName}'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(5, (index) {
                      final starValue = index + 1.0;
                      return IconButton(
                        tooltip: '$starValue star',
                        onPressed: () => setState(() => rating = starValue),
                        icon: Icon(
                          index < rating ? Icons.star : Icons.star_border,
                          color: AppColors.warning,
                        ),
                      );
                    }),
                  ),
                  TextField(
                    controller: commentController,
                    decoration: const InputDecoration(
                      labelText: 'Review',
                      hintText: 'How was the work?',
                    ),
                    maxLines: 3,
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('Later'),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: const Text('Submit'),
                ),
              ],
            );
          },
        );
      },
    );

    final comment = commentController.text.trim();
    commentController.dispose();

    if (submitted != true || !context.mounted) return;

    final user = context.read<AuthProvider>().user;
    if (user == null) return;

    try {
      await widget.reviewRepository.createReview(
        ReviewModel(
          id: '',
          bookingId: widget.booking.id,
          employeeId: widget.booking.employeeId,
          customerId: user.id,
          customerName: user.name,
          customerImage: user.profileImage,
          rating: rating,
          comment: comment.isEmpty ? 'No written review.' : comment,
          createdAt: DateTime.now(),
        ),
      );

      final stats =
          await widget.reviewRepository.calculateRatingStats(widget.booking.employeeId);
      await widget.employeeRepository.updateRating(
        widget.booking.employeeId,
        stats.averageRating,
        stats.totalReviews,
      );

      try {
        await widget.notificationRepository.createNotification(
          NotificationModel(
            id: '',
            userId: widget.booking.employeeId,
            title: 'New Review',
            body:
                '${user.name} rated your work ${rating.toStringAsFixed(1)} stars',
            type: NotificationType.review,
            data: {'bookingId': widget.booking.id},
            createdAt: DateTime.now(),
          ),
        );
      } catch (_) {
        // The review itself is saved; notification delivery can fail independently.
      }

      if (!context.mounted) return;
      setState(() => _submitted = true);
      Helpers.showSnackBar(context, 'Review submitted successfully.');
    } catch (e) {
      if (!context.mounted) return;
      Helpers.showSnackBar(context, 'Unable to submit review: $e', isError: true);
    }
  }

  Widget _reviewedLabel() {
    return const Text(
      'Reviewed',
      style: TextStyle(
        color: AppColors.success,
        fontWeight: FontWeight.w700,
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: AppColors.grey500),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppColors.grey700,
                ),
          ),
        ),
      ],
    );
  }
}