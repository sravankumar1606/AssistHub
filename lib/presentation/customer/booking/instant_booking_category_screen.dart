import 'package:flutter/material.dart';
import 'package:assisthub/providers/core/constants/app_colors.dart';
import 'package:assisthub/data/models/service_model.dart';
import 'package:assisthub/presentation/customer/booking/booking_screen.dart';

/// Entry point for Instant Booking from the customer home page — the
/// customer picks a profession/category first (no specific employee),
/// then the rest of the flow is the same booking form, just broadcast
/// to every provider in that category once submitted.
class InstantBookingCategoryScreen extends StatelessWidget {
  const InstantBookingCategoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final categories = ServiceCategories.all;

    return Scaffold(
      appBar: AppBar(title: const Text('Instant Booking')),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Card(
              color: AppColors.warning.withOpacity(0.08),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    const Icon(Icons.bolt, color: AppColors.warning, size: 28),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Choose what you need — your request goes out to every available provider in that category. Whoever accepts first gets the job.',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: categories.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final category = categories[index];
                return _CategoryRow(category: category);
              },
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}

class _CategoryRow extends StatelessWidget {
  const _CategoryRow({required this.category});

  final ServiceCategory category;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => BookingScreen(category: category.id),
          ),
        );
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: AppColors.grey300.withOpacity(0.3),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(category.iconData, color: AppColors.primary, size: 20),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                category.name,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
              ),
            ),
            const Icon(Icons.chevron_right, size: 20, color: AppColors.grey400),
          ],
        ),
      ),
    );
  }
}
