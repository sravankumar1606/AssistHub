import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:assisthub/providers/core/constants/app_colors.dart';
import 'package:assisthub/providers/core/utils/helpers.dart';
import 'package:assisthub/providers/core/widgets/custom_button.dart';
import 'package:assisthub/providers/core/widgets/empty_state_widget.dart';
import 'package:assisthub/providers/core/widgets/loading_widget.dart';
import 'package:assisthub/data/models/booking_model.dart';
import 'package:assisthub/providers/booking_provider.dart';
import 'package:assisthub/providers/auth_provider.dart';
import 'package:assisthub/providers/chat_provider.dart';
import 'package:assisthub/presentation/customer/chat/chat_screen.dart';
import 'package:assisthub/providers/core/utils/maps_helper.dart';
import 'package:assisthub/providers/employee_provider.dart';

class EmployeeBookingsScreen extends StatefulWidget {
  const EmployeeBookingsScreen({super.key});

  @override
  State<EmployeeBookingsScreen> createState() => _EmployeeBookingsScreenState();
}

class _EmployeeBookingsScreenState extends State<EmployeeBookingsScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  bool _subscribedToInstant = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Bookings'),
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          tabs: const [
            Tab(text: 'Pending'),
            Tab(text: 'Active'),
            Tab(text: 'All'),
            Tab(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.bolt, size: 16, color: AppColors.warning),
                  SizedBox(width: 4),
                  Text('Instant'),
                ],
              ),
            ),
          ],
        ),
      ),
      body: Consumer2<BookingProvider, EmployeeProvider>(
        builder: (context, bookingProvider, employeeProvider, child) {
          final category = employeeProvider.currentEmployee?.serviceCategory;
          if (category != null && !_subscribedToInstant) {
            _subscribedToInstant = true;
            WidgetsBinding.instance.addPostFrameCallback((_) {
              bookingProvider.subscribeToInstantBookings(category);
            });
          }

          return TabBarView(
            controller: _tabController,
            children: [
              _BookingList(bookings: bookingProvider.pendingBookings, showActions: true),
              _BookingList(bookings: bookingProvider.activeBookings, showStatusControls: true),
              _BookingList(bookings: bookingProvider.bookings),
              _InstantBookingList(bookings: bookingProvider.instantBookings),
            ],
          );
        },
      ),
    );
  }
}

class _BookingList extends StatelessWidget {
  final List<BookingModel> bookings;
  final bool showActions;
  final bool showStatusControls;

  const _BookingList({
    required this.bookings,
    this.showActions = false,
    this.showStatusControls = false,
  });

  @override
  Widget build(BuildContext context) {
    if (bookings.isEmpty) {
      return const EmptyStateWidget(
        title: 'Nothing here yet',
        message: 'New requests and jobs will show up here',
        icon: Icons.calendar_today_outlined,
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: bookings.length,
      itemBuilder: (context, index) {
        final booking = bookings[index];
        return _BookingCard(
          booking: booking,
          showActions: showActions,
          showStatusControls: showStatusControls,
        );
      },
    );
  }
}

class _BookingCard extends StatelessWidget {
  final BookingModel booking;
  final bool showActions;
  final bool showStatusControls;

  const _BookingCard({
    required this.booking,
    required this.showActions,
    required this.showStatusControls,
  });

  Future<void> _respond(BuildContext context, BookingStatus status) async {
    await context.read<BookingProvider>().updateBookingStatus(booking.id, status);
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(booking.customerName, style: Theme.of(context).textTheme.titleMedium),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Helpers.getStatusColor(booking.status.name).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    booking.statusDisplayName,
                    style: TextStyle(
                      color: Helpers.getStatusColor(booking.status.name),
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            _InfoRow(icon: Icons.build_outlined, text: booking.serviceCategory),
            _InfoRow(
              icon: Icons.location_on_outlined,
              text: booking.customerAddress +
                  (booking.hasPreciseLocation ? '  📍 Exact location shared' : ''),
              onTap: () => booking.hasPreciseLocation
                  ? MapsHelper.openCoordinates(
                      booking.customerLatitude!, booking.customerLongitude!)
                  : MapsHelper.openAddress(booking.customerAddress),
            ),
            _InfoRow(
              icon: Icons.calendar_today_outlined,
              text: '${Helpers.formatDate(booking.scheduledDate)} · ${booking.scheduledTime}',
            ),
            _InfoRow(icon: Icons.phone_outlined, text: booking.customerPhone),
            if (booking.status != BookingStatus.pending &&
                booking.status != BookingStatus.rejected &&
                booking.status != BookingStatus.cancelled) ...[
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
            if (showActions) ...[
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () => booking.hasPreciseLocation
                      ? MapsHelper.openCoordinates(
                          booking.customerLatitude!, booking.customerLongitude!)
                      : MapsHelper.openAddress(booking.customerAddress),
                  icon: const Icon(Icons.map_outlined, size: 18),
                  label: Text(
                    booking.hasPreciseLocation
                        ? 'View exact location before deciding'
                        : 'View location before deciding',
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => _respond(context, BookingStatus.rejected),
                      style: OutlinedButton.styleFrom(foregroundColor: AppColors.error),
                      child: const Text('Reject'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => _respond(context, BookingStatus.accepted),
                      child: const Text('Accept'),
                    ),
                  ),
                ],
              ),
            ],
            if (showStatusControls) ...[
              const SizedBox(height: 12),
              _StatusDropdown(booking: booking),
            ],
          ],
        ),
      ),
    );
  }
}

class _StatusDropdown extends StatelessWidget {
  final BookingModel booking;

  const _StatusDropdown({required this.booking});

  static const _progressStates = [
    BookingStatus.accepted,
    BookingStatus.onTheWay,
    BookingStatus.working,
    BookingStatus.completed,
  ];

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<BookingStatus>(
      value: _progressStates.contains(booking.status) ? booking.status : null,
      decoration: const InputDecoration(labelText: 'Update status'),
      items: _progressStates
          .map((status) => DropdownMenuItem(value: status, child: Text(_label(status))))
          .toList(),
      onChanged: (status) {
        if (status != null) {
          context.read<BookingProvider>().updateBookingStatus(booking.id, status);
        }
      },
    );
  }

  String _label(BookingStatus status) {
    switch (status) {
      case BookingStatus.accepted:
        return 'Accepted';
      case BookingStatus.onTheWay:
        return 'On the Way';
      case BookingStatus.working:
        return 'Working';
      case BookingStatus.completed:
        return 'Completed';
      default:
        return status.name;
    }
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String text;
  final VoidCallback? onTap;

  const _InfoRow({required this.icon, required this.text, this.onTap});

  @override
  Widget build(BuildContext context) {
    final row = Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Row(
        children: [
          Icon(icon, size: 16, color: onTap != null ? AppColors.primary : AppColors.grey500),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: onTap != null ? AppColors.primary : AppColors.grey700,
                    decoration: onTap != null ? TextDecoration.underline : null,
                  ),
            ),
          ),
          if (onTap != null)
            const Icon(Icons.open_in_new, size: 14, color: AppColors.primary),
        ],
      ),
    );

    if (onTap == null) return row;
    return InkWell(onTap: onTap, borderRadius: BorderRadius.circular(6), child: row);
  }
}

/// Ensures a chat room exists for this booking's customer/employee pair
/// (creating it on first use) and opens the conversation.
Future<void> _openChat(BuildContext context, BookingModel booking) async {
  final chatProvider = context.read<ChatProvider>();
  final currentUserId = context.read<AuthProvider>().user?.id;

  final chatRoomId = await chatProvider.createOrGetChatRoom(
    customerId: booking.customerId,
    customerName: booking.customerName,
    employeeId: booking.employeeId,
    employeeName: booking.employeeName,
  );

  if (!context.mounted) return;



  final isCustomer = currentUserId == booking.customerId;
  final otherName = isCustomer ? booking.employeeName : booking.customerName;

  final otherUserId = isCustomer ? booking.employeeId : booking.customerId;
final otherUserImage = isCustomer ? null : null;

Navigator.push(
    context,
    MaterialPageRoute(
      builder: (_) => ChatScreen(
        chatRoomId: chatRoomId,
        otherUserId: otherUserId,
        otherUserName: otherName,
        otherUserImage: otherUserImage,
      ),
    ),
  );
}

class _InstantBookingList extends StatelessWidget {
  final List<BookingModel> bookings;

  const _InstantBookingList({required this.bookings});

  @override
  Widget build(BuildContext context) {
    if (bookings.isEmpty) {
      return const EmptyStateWidget(
        title: 'No instant requests',
        message: 'Urgent requests from customers in your category show up here.',
        icon: Icons.bolt_outlined,
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: bookings.length,
      itemBuilder: (context, index) => _InstantBookingCard(booking: bookings[index]),
    );
  }
}

class _InstantBookingCard extends StatefulWidget {
  final BookingModel booking;

  const _InstantBookingCard({required this.booking});

  @override
  State<_InstantBookingCard> createState() => _InstantBookingCardState();
}

class _InstantBookingCardState extends State<_InstantBookingCard> {
  bool _isProcessing = false;

  Future<void> _accept(BuildContext context) async {
    setState(() => _isProcessing = true);
    final error =
        await context.read<BookingProvider>().acceptInstantBooking(widget.booking.id);
    if (!mounted) return;
    setState(() => _isProcessing = false);

    if (error != null) {
      Helpers.showSnackBar(context, error, isError: true);
    } else {
      Helpers.showSnackBar(context, 'Job accepted! Check your Active tab.');
    }
  }

  Future<void> _dismiss(BuildContext context) async {
    await context.read<BookingProvider>().dismissInstantBooking(widget.booking.id);
  }

  @override
  Widget build(BuildContext context) {
    final booking = widget.booking;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      color: AppColors.warning.withOpacity(0.05),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.bolt, color: AppColors.warning, size: 18),
                const SizedBox(width: 6),
                Text(
                  'INSTANT REQUEST',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: AppColors.warning,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5,
                      ),
                ),
                const Spacer(),
                Text(
                  Helpers.formatCurrency(booking.amount),
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: AppColors.primary,
                        fontWeight: FontWeight.bold,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            _InfoRow(icon: Icons.build_outlined, text: booking.serviceCategory),
            _InfoRow(
              icon: Icons.location_on_outlined,
              text: booking.customerAddress,
              onTap: () => booking.hasPreciseLocation
                  ? MapsHelper.openCoordinates(
                      booking.customerLatitude!, booking.customerLongitude!)
                  : MapsHelper.openAddress(booking.customerAddress),
            ),
            _InfoRow(
              icon: Icons.calendar_today_outlined,
              text: '${Helpers.formatDate(booking.scheduledDate)} · ${booking.scheduledTime}',
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _isProcessing ? null : () => _dismiss(context),
                    child: const Text('Not now'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _isProcessing ? null : () => _accept(context),
                    style: ElevatedButton.styleFrom(backgroundColor: AppColors.warning),
                    child: _isProcessing
                        ? const SizedBox(
                            height: 18,
                            width: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Accept Job'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}