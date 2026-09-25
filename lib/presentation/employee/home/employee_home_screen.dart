import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:assisthub/providers/core/utils/helpers.dart';
import 'package:assisthub/providers/core/constants/app_colors.dart';
import 'package:assisthub/data/models/booking_model.dart';
import 'package:assisthub/providers/auth_provider.dart';
import 'package:assisthub/providers/booking_provider.dart';
import 'package:assisthub/providers/employee_provider.dart';
import 'package:assisthub/presentation/customer/chat/chat_list_screen.dart';
import 'package:assisthub/providers/core/widgets/animated_gradient_background.dart';
class EmployeeHomeScreen extends StatelessWidget {
  const EmployeeHomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().user;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: AnimatedGradientBackground(
        colors: [
          AppColors.primary.withOpacity(0.06),
          AppColors.primary.withOpacity(0.02),
          Colors.transparent,
        ],
        child: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async {
            final auth = context.read<AuthProvider>();
            final employeeProvider = context.read<EmployeeProvider>();
            if (auth.user != null) {
              await employeeProvider.loadCurrentEmployee(auth.user!.id);
            }
          },
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _Header(name: user?.name ?? 'Provider'),
              const SizedBox(height: 24),
              const _AvailabilityCard(),
              const SizedBox(height: 18),
              const _StatsGrid(),
              const SizedBox(height: 18),
              const _PendingRequestsPreview(),
              const SizedBox(height: 24),
              const _ActiveJobsPreview(),
            ],
          ),
        ),
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.name});

  final String name;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Hello, $name',
                style: Theme.of(context).textTheme.headlineMedium,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
              Text(
                'Manage requests, jobs, and availability.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppColors.grey600,
                    ),
              ),
            ],
          ),
        ),
        IconButton(
          icon: const Icon(Icons.chat_bubble_outline),
          tooltip: 'Messages',
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const ChatListScreen()),
            );
          },
        ),
        const SizedBox(width: 4),
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            gradient: AppColors.primaryGradient,
            borderRadius: BorderRadius.circular(14),
          ),
          child: const Icon(Icons.work, color: AppColors.white),
        ),
      ],
    );
  }
}

class _AvailabilityCard extends StatelessWidget {
  const _AvailabilityCard();

  @override
  Widget build(BuildContext context) {
    return Consumer<EmployeeProvider>(
      builder: (context, provider, child) {
        final isAvailable = provider.currentEmployee?.isAvailable ?? false;

        return Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: (isAvailable ? AppColors.success : AppColors.grey500)
                        .withOpacity(0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    isAvailable ? Icons.check_circle : Icons.pause_circle,
                    color: isAvailable ? AppColors.success : AppColors.grey500,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isAvailable ? 'Available for jobs' : 'Not accepting jobs',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 3),
                      Text(
                        isAvailable
                            ? 'Customers can find you in service listings.'
                            : 'Turn this on when you are ready for bookings.',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: AppColors.grey600,
                            ),
                      ),
                    ],
                  ),
                ),
                Switch(
                  value: isAvailable,
                  activeColor: AppColors.success,
                  onChanged: provider.currentEmployee == null
                      ? null
                      : (value) => provider.updateAvailability(value),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _StatsGrid extends StatelessWidget {
  const _StatsGrid();

  @override
  Widget build(BuildContext context) {
    return Consumer2<EmployeeProvider, BookingProvider>(
      builder: (context, employeeProvider, bookingProvider, child) {
        final employee = employeeProvider.currentEmployee;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Overview', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
              childAspectRatio: 2.25,
              children: [
                _StatCard(
                  icon: Icons.pending_actions,
                  value: '${bookingProvider.pendingBookings.length}',
                  label: 'Pending',
                  color: AppColors.warning,
                ),
                _StatCard(
                  icon: Icons.engineering,
                  value: '${bookingProvider.activeBookings.length}',
                  label: 'Active Jobs',
                  color: AppColors.info,
                ),
                _StatCard(
                  icon: Icons.task_alt,
                  value: '${employee?.totalJobs ?? 0}',
                  label: 'Completed',
                  color: AppColors.success,
                ),
                _StatCard(
                  icon: Icons.payments_outlined,
                  value: Helpers.formatCurrency(employee?.totalEarnings ?? 0),
                  label: 'Earnings',
                  color: AppColors.primary,
                ),
              ],
            ),
          ],
        );
      },
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.icon,
    required this.value,
    required this.label,
    required this.color,
  });

  final IconData icon;
  final String value;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: color.withOpacity(0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: color, size: 19),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    value,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 1),
                  Text(
                    label,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppColors.grey600,
                        ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PendingRequestsPreview extends StatelessWidget {
  const _PendingRequestsPreview();

  @override
  Widget build(BuildContext context) {
    return Consumer<BookingProvider>(
      builder: (context, provider, child) {
        final bookings = provider.pendingBookings.take(3).toList();

        return _BookingSection(
          title: 'Pending Requests',
          emptyText: 'No pending requests',
          bookings: bookings,
          trailingBuilder: (booking) => Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton.filledTonal(
                tooltip: 'Reject',
                onPressed: () => provider.updateBookingStatus(
                  booking.id,
                  BookingStatus.rejected,
                ),
                icon: const Icon(Icons.close),
              ),
              const SizedBox(width: 8),
              IconButton.filled(
                tooltip: 'Accept',
                onPressed: () => provider.updateBookingStatus(
                  booking.id,
                  BookingStatus.accepted,
                ),
                icon: const Icon(Icons.check),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _ActiveJobsPreview extends StatelessWidget {
  const _ActiveJobsPreview();

  @override
  Widget build(BuildContext context) {
    return Consumer<BookingProvider>(
      builder: (context, provider, child) {
        final bookings = provider.activeBookings.take(3).toList();

        return _BookingSection(
          title: 'Active Jobs',
          emptyText: 'No active jobs',
          bookings: bookings,
          trailingBuilder: (booking) => _StatusPill(status: booking.statusDisplayName),
        );
      },
    );
  }
}

class _BookingSection extends StatelessWidget {
  const _BookingSection({
    required this.title,
    required this.emptyText,
    required this.bookings,
    required this.trailingBuilder,
  });

  final String title;
  final String emptyText;
  final List<BookingModel> bookings;
  final Widget Function(BookingModel booking) trailingBuilder;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 12),
        if (bookings.isEmpty)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Center(
                child: Text(
                  emptyText,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppColors.grey500,
                      ),
                ),
              ),
            ),
          )
        else
          ...bookings.map(
            (booking) => Card(
              margin: const EdgeInsets.only(bottom: 10),
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: AppColors.primary.withOpacity(0.12),
                  child: const Icon(Icons.home_repair_service, color: AppColors.primary),
                ),
                title: Text(
                  booking.serviceCategory,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                subtitle: Text(
                  '${booking.customerName} - ${Helpers.formatDate(booking.scheduledDate)}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                trailing: trailingBuilder(booking),
              ),
            ),
          ),
      ],
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.status});

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
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
