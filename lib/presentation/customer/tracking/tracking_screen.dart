import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:provider/provider.dart';
import 'package:assisthub/core/constants/app_colors.dart';
import 'package:assisthub/providers/core/utils/helpers.dart';
import 'package:assisthub/data/models/booking_model.dart';
import 'package:assisthub/data/models/chat_model.dart';
import 'package:assisthub/data/models/tracking_model.dart';
import 'package:assisthub/data/repositories/tracking_repository.dart';
import 'package:assithub/providers/auth_provider.dart';
import 'package:assisthub/providers/chat_provider.dart';
import 'package:assisthub/presentataion/customer/chat/chat_screen.dart';

/// Live map showing where the assigned employee currently is, for a
/// booking that's accepted / on-the-way / working. Falls back to a
/// friendly "not sharing location yet" state otherwise.
class TrackingScreen extends StatefulWidget {
  final BookingModel booking;

  const TrackingScreen({super.key, required this.booking});

  @override
  State<TrackingScreen> createState() => _TrackingScreenState();
}

class _TrackingScreenState extends State<TrackingScreen> {
  final TrackingRepository _trackingRepository = TrackingRepository();
  GoogleMapController? _mapController;

  @override
  Widget build(BuildContext context) {
    final booking = widget.booking;
    final isTrackable = [
      BookingStatus.accepted,
      BookingStatus.active,
      BookingStatus.onTheWay,
      BookingStatus.working,
    ].contains(booking.status);

    return Scaffold(
      appBar: AppBar(
        title: Text(booking.employeeName),
        actions: [
          if (isTrackable)
            IconButton(
              icon: const Icon(Icons.chat_bubble_outline),
              tooltip: 'Chat',
              onPressed: () => _openChat(context, booking),
            ),
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: Container(
              alignment: Alignment.center,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: Helpers.getStatusColor(booking.status.name).withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                booking.statusDisplayName,
                style: TextStyle(
                  color: Helpers.getStatusColor(booking.status.name),
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                ),
              ),
            ),
          ),
        ],
      ),
      body: !isTrackable
          ? _StatusMessage(booking: booking)
          : StreamBuilder<TrackingData?>(
              stream: _trackingRepository.trackingStream(booking.id),
              builder: (context, snapshot) {
                final tracking = snapshot.data;

                if (tracking == null) {
                  return const _StatusMessage.waitingForLocation();
                }

                final position = LatLng(tracking.latitude, tracking.longitude);

                return Stack(
                  children: [
                    GoogleMap(
                      initialCameraPosition: CameraPosition(target: position, zoom: 15),
                      onMapCreated: (controller) => _mapController = controller,
                      markers: {
                        Marker(
                          markerId: const MarkerId('employee'),
                          position: position,
                          infoWindow: InfoWindow(title: booking.employeeName),
                        ),
                      },
                      myLocationButtonEnabled: true,
                      myLocationEnabled: false,
                      onCameraMove: (_) {},
                    ),
                    Positioned(
                      left: 16,
                      right: 16,
                      bottom: 16,
                      child: _TrackingInfoCard(
                        booking: booking,
                        lastUpdated: tracking.updatedAt,
                      ),
                    ),
                  ],
                );
              },
            ),
    );
  }

  @override
  void dispose() {
    _mapController?.dispose();
    super.dispose();
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

  final chatRoom = ChatRoom(
    id: chatRoomId,
    customerId: booking.customerId,
    customerName: booking.customerName,
    employeeId: booking.employeeId,
    employeeName: booking.employeeName,
    createdAt: DateTime.now(),
  );

  final isCustomer = currentUserId == booking.customerId;
  final otherName = isCustomer ? booking.employeeName : booking.customerName;

  Navigator.push(
    context,
    MaterialPageRoute(
      builder: (_) => ChatScreen(chatRoom: chatRoom, otherUserName: otherName),
    ),
  );
}

class _TrackingInfoCard extends StatelessWidget {
  final BookingModel booking;
  final DateTime lastUpdated;

  const _TrackingInfoCard({required this.booking, required this.lastUpdated});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(booking.employeeName, style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 2),
                  Text(
                    'Updated ${Helpers.timeAgo(lastUpdated)}',
                    style: Theme.of(context)
                        .textTheme
                        .bodySmall
                        ?.copyWith(color: AppColors.grey500),
                  ),
                ],
              ),
            ),
            IconButton.filled(
              icon: const Icon(Icons.chat_bubble_outline),
              onPressed: () => _openChat(context, booking),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusMessage extends StatelessWidget {
  final BookingModel? booking;
  final bool waiting;

  const _StatusMessage({required this.booking}) : waiting = false;
  const _StatusMessage.waitingForLocation()
      : booking = null,
        waiting = true;

  @override
  Widget build(BuildContext context) {
    final message = waiting
        ? 'Waiting for the employee to start sharing their location...'
        : 'Live tracking is available once your booking is accepted.';

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.location_off_outlined, size: 64, color: AppColors.grey400),
            const SizedBox(height: 16),
            Text(message, textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}