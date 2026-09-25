import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:assisthub/providers/core/constants/app_colors.dart';
import 'package:assisthub/providers/core/utils/helpers.dart';
import 'package:assisthub/providers/core/widgets/empty_state_widget.dart';
import 'package:assisthub/providers/core/widgets/loading_widget.dart';
import 'package:assisthub/data/models/booking_model.dart';
import 'package:assisthub/data/models/review_model.dart';
import 'package:assisthub/data/repositories/review_repository.dart';
import 'package:assisthub/providers/booking_provider.dart';
import 'package:assisthub/presentation/shared/chat/chat_screen.dart';
import 'package:assisthub/providers/chat_provider.dart';
import 'package:assisthub/providers/auth_provider.dart';

enum EmployeeMetricType { rating, reviews, jobs, earnings }

enum _MetricPeriod { all, month, year }

class EmployeeMetricDetailScreen extends StatefulWidget {
  const EmployeeMetricDetailScreen({
    super.key,
    required this.type,
    required this.employeeId,
    required this.reviewRepository,
  });

  final EmployeeMetricType type;
  final String employeeId;
  final ReviewRepository reviewRepository;

  @override
  State<EmployeeMetricDetailScreen> createState() =>
      _EmployeeMetricDetailScreenState();
}

class _EmployeeMetricDetailScreenState
    extends State<EmployeeMetricDetailScreen> {
  _MetricPeriod _period = _MetricPeriod.all;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_title)),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: SegmentedButton<_MetricPeriod>(
              segments: const [
                ButtonSegment(value: _MetricPeriod.all, label: Text('All')),
                ButtonSegment(value: _MetricPeriod.month, label: Text('Month')),
                ButtonSegment(value: _MetricPeriod.year, label: Text('Year')),
              ],
              selected: {_period},
              onSelectionChanged: (value) {
                setState(() => _period = value.first);
              },
            ),
          ),
          Expanded(child: _buildBody(context)),
        ],
      ),
    );
  }

  Widget _buildBody(BuildContext context) {
    switch (widget.type) {
      case EmployeeMetricType.rating:
      case EmployeeMetricType.reviews:
        return FutureBuilder<List<ReviewModel>>(
          future: widget.reviewRepository.getEmployeeReviews(
            widget.employeeId,
            limit: 1000,
          ),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: LoadingWidget());
            }

            final reviews = (snapshot.data ?? [])
                .where((review) => _inSelectedPeriod(review.createdAt))
                .toList();
            return _ReviewMetricList(
              type: widget.type,
              reviews: reviews,
              periodLabel: _periodLabel,
            );
          },
        );
      case EmployeeMetricType.jobs:
      case EmployeeMetricType.earnings:
        return Consumer<BookingProvider>(
          builder: (context, provider, child) {
            final bookings = provider.bookings
                .where((booking) => booking.status == BookingStatus.completed)
                .where((booking) => _inSelectedPeriod(_bookingDate(booking)))
                .toList();

            return _BookingMetricList(
              type: widget.type,
              bookings: bookings,
              periodLabel: _periodLabel,
            );
          },
        );
    }
  }

  bool _inSelectedPeriod(DateTime date) {
    final now = DateTime.now();
    switch (_period) {
      case _MetricPeriod.all:
        return true;
      case _MetricPeriod.month:
        return date.year == now.year && date.month == now.month;
      case _MetricPeriod.year:
        return date.year == now.year;
    }
  }

  DateTime _bookingDate(BookingModel booking) {
    return booking.updatedAt;
  }

  String get _title {
    switch (widget.type) {
      case EmployeeMetricType.rating:
        return 'Rating Details';
      case EmployeeMetricType.reviews:
        return 'Review Details';
      case EmployeeMetricType.jobs:
        return 'Completed Jobs';
      case EmployeeMetricType.earnings:
        return 'Earnings Details';
    }
  }

  String get _periodLabel {
    switch (_period) {
      case _MetricPeriod.all:
        return 'all time';
      case _MetricPeriod.month:
        return 'this month';
      case _MetricPeriod.year:
        return 'this year';
    }
  }
}

class _ReviewMetricList extends StatelessWidget {
  const _ReviewMetricList({
    required this.type,
    required this.reviews,
    required this.periodLabel,
  });

  final EmployeeMetricType type;
  final List<ReviewModel> reviews;
  final String periodLabel;

  @override
  Widget build(BuildContext context) {
    if (reviews.isEmpty) {
      return EmptyStateWidget(
        title: 'No reviews',
        message: 'No customer reviews found for $periodLabel.',
        icon: Icons.reviews_outlined,
      );
    }

    final averageRating =
        reviews.fold<double>(0, (total, review) => total + review.rating) /
            reviews.length;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _SummaryCard(
          icon: type == EmployeeMetricType.rating
              ? Icons.star
              : Icons.reviews_outlined,
          title: type == EmployeeMetricType.rating
              ? 'Average Rating'
              : 'Total Reviews',
          value: type == EmployeeMetricType.rating
              ? averageRating.toStringAsFixed(1)
              : '${reviews.length}',
          subtitle: 'From ${reviews.length} customer review(s) for $periodLabel',
          color: type == EmployeeMetricType.rating
              ? AppColors.warning
              : AppColors.primary,
        ),
        const SizedBox(height: 12),
        ...reviews.map((review) => _ReviewTile(review: review)),
      ],
    );
  }
}

class _BookingMetricList extends StatelessWidget {
  const _BookingMetricList({
    required this.type,
    required this.bookings,
    required this.periodLabel,
  });

  final EmployeeMetricType type;
  final List<BookingModel> bookings;
  final String periodLabel;

  @override
  Widget build(BuildContext context) {
    if (bookings.isEmpty) {
      return EmptyStateWidget(
        title: type == EmployeeMetricType.earnings
            ? 'No earnings'
            : 'No completed jobs',
        message: 'No completed customer work found for $periodLabel.',
        icon: type == EmployeeMetricType.earnings
            ? Icons.payments_outlined
            : Icons.task_alt,
      );
    }

    final totalEarnings =
        bookings.fold<double>(0, (total, booking) => total + booking.amount);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _SummaryCard(
          icon: type == EmployeeMetricType.earnings
              ? Icons.payments_outlined
              : Icons.task_alt,
          title: type == EmployeeMetricType.earnings
              ? 'Total Earnings'
              : 'Completed Jobs',
          value: type == EmployeeMetricType.earnings
              ? Helpers.formatCurrency(totalEarnings)
              : '${bookings.length}',
          subtitle: 'From ${bookings.length} customer job(s) for $periodLabel',
          color: type == EmployeeMetricType.earnings
              ? AppColors.info
              : AppColors.success,
        ),
        const SizedBox(height: 12),
        ...bookings.map((booking) => _BookingTile(booking: booking)),
      ],
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.icon,
    required this.title,
    required this.value,
    required this.subtitle,
    required this.color,
  });

  final IconData icon;
  final String title;
  final String value;
  final String subtitle;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: color.withOpacity(0.12),
              child: Icon(icon, color: color),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppColors.grey600,
                        ),
                  ),
                ],
              ),
            ),
            Text(
              value,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: color,
                    fontWeight: FontWeight.bold,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ReviewTile extends StatelessWidget {
  const _ReviewTile({required this.review});

  final ReviewModel review;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: AppColors.primary.withOpacity(0.12),
          backgroundImage: review.customerImage == null
              ? null
              : NetworkImage(review.customerImage!),
          child: review.customerImage == null
              ? Text(
                  review.customerName.isEmpty
                      ? '?'
                      : review.customerName[0].toUpperCase(),
                  style: const TextStyle(
                    color: AppColors.primary,
                    fontWeight: FontWeight.bold,
                  ),
                )
              : null,
        ),
        title: Text(review.customerName),
        subtitle: Text(
          '${Helpers.formatDate(review.createdAt)}\n${review.comment}',
        ),
        isThreeLine: true,
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.star, color: AppColors.warning, size: 18),
            const SizedBox(width: 4),
            Text(review.rating.toStringAsFixed(1)),
          ],
        ),
      ),
    );
  }
}

class _BookingTile extends StatelessWidget {
  const _BookingTile({required this.booking});

  final BookingModel booking;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: AppColors.success.withOpacity(0.12),
          child: const Icon(Icons.person_outline, color: AppColors.success),
        ),
        title: Text(booking.customerName),
        subtitle: Text(
          '${booking.serviceCategory}\n${Helpers.formatDate(booking.updatedAt)}',
        ),
        isThreeLine: true,
        trailing: Text(
          Helpers.formatCurrency(booking.amount),
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                color: AppColors.primary,
                fontWeight: FontWeight.bold,
              ),
        ),
      ),
    );
  }
}
