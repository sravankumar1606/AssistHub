import 'package:flutter/material.dart';
import 'package:flutter_rating_bar/flutter_rating_bar.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:assisthub/providers/core/constants/app_colors.dart';
import 'package:assisthub/providers/core/utils/helpers.dart';
import 'package:assisthub/providers/core/widgets/custom_button.dart';
import 'package:assisthub/providers/core/widgets/loading_widget.dart';
import 'package:assisthub/data/models/employee_model.dart';
import 'package:assisthub/data/models/review_model.dart';
import 'package:assisthub/data/repositories/review_repository.dart';
import 'package:assisthub/presentation/customer/booking/booking_screen.dart';

class EmployeeDetailScreen extends StatefulWidget {
  final EmployeeModel employee;

  const EmployeeDetailScreen({super.key, required this.employee});

  @override
  State<EmployeeDetailScreen> createState() => _EmployeeDetailScreenState();
}

class _EmployeeDetailScreenState extends State<EmployeeDetailScreen> {
  final ReviewRepository _reviewRepository = ReviewRepository();
  List<ReviewModel> _reviews = [];
  bool _isLoadingReviews = true;

  @override
  void initState() {
    super.initState();
    _loadReviews();
  }

  Future<void> _loadReviews() async {
    try {
      final reviews = await _reviewRepository.getEmployeeReviews(widget.employee.id);
      if (mounted) {
        setState(() {
          _reviews = reviews;
          _isLoadingReviews = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingReviews = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final employee = widget.employee;

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 200,
            pinned: true,
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: BoxDecoration(
                  gradient: AppColors.primaryGradient,
                ),
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const SizedBox(height: 40),
                      CircleAvatar(
                        radius: 50,
                        backgroundColor: AppColors.white,
                        backgroundImage: employee.profileImage != null
                            ? NetworkImage(employee.profileImage!)
                            : null,
                        child: employee.profileImage == null
                            ? Text(
                                employee.name[0].toUpperCase(),
                                style: const TextStyle(
                                  fontSize: 40,
                                  color: AppColors.primary,
                                  fontWeight: FontWeight.bold,
                                ),
                              )
                            : null,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        employee.name,
                        style: const TextStyle(
                          color: AppColors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        employee.serviceCategory,
                        style: TextStyle(
                          color: AppColors.white.withOpacity(0.9),
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildStatsRow(employee),
                  const SizedBox(height: 24),
                  _buildInfoSection(employee),
                  const SizedBox(height: 24),
                  _buildAboutSection(employee),
                  const SizedBox(height: 24),
                  if (employee.workVideoUrls.isNotEmpty) ...[
                    _buildWorkVideosSection(employee),
                    const SizedBox(height: 24),
                  ],
                  _buildReviewsSection(),
                  const SizedBox(height: 100),
                ],
              ),
            ),
          ),
        ],
      ),
      bottomSheet: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
          boxShadow: [
            BoxShadow(
              color: AppColors.grey300.withOpacity(0.5),
              blurRadius: 10,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: SafeArea(
          child: Row(
            children: [
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Starting from',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: AppColors.grey600,
                          ),
                    ),
                    Text(
                      '${Helpers.formatCurrency(employee.hourlyRate)}/hr',
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                            color: AppColors.primary,
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: GradientButton(
                  text: 'Book Now',
                  onPressed: employee.isAvailable
                      ? () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => BookingScreen(employee: employee),
                            ),
                          );
                        }
                      : null,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatsRow(EmployeeModel employee) {
    return Row(
      children: [
        Expanded(
          child: _buildStatItem(
            icon: Icons.star,
            iconColor: AppColors.warning,
            value: employee.rating.toStringAsFixed(1),
            label: 'Rating',
          ),
        ),
        Expanded(
          child: _buildStatItem(
            icon: Icons.work_outline,
            iconColor: AppColors.info,
            value: '${employee.experienceYears}',
            label: 'Years Exp.',
          ),
        ),
        Expanded(
          child: _buildStatItem(
            icon: Icons.assignment_turned_in_outlined,
            iconColor: AppColors.success,
            value: '${employee.totalJobs}',
            label: 'Jobs Done',
          ),
        ),
        Expanded(
          child: _buildStatItem(
            icon: Icons.reviews_outlined,
            iconColor: AppColors.primary,
            value: '${employee.totalReviews}',
            label: 'Reviews',
          ),
        ),
      ],
    );
  }

  Widget _buildStatItem({
    required IconData icon,
    required Color iconColor,
    required String value,
    required String label,
  }) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: iconColor.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: iconColor, size: 24),
        ),
        const SizedBox(height: 8),
        Text(
          value,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: AppColors.grey600,
              ),
        ),
      ],
    );
  }

  Widget _buildInfoSection(EmployeeModel employee) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _buildInfoRow(Icons.email_outlined, employee.email),
            const Divider(height: 24),
            _buildInfoRow(Icons.phone_outlined, employee.phone),
            const Divider(height: 24),
            _buildInfoRow(Icons.location_on_outlined, employee.address),
            const Divider(height: 24),
            _buildInfoRow(
              Icons.circle,
              employee.isAvailable ? 'Available' : 'Not Available',
              valueColor: employee.isAvailable ? AppColors.success : AppColors.error,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String value, {Color? valueColor}) {
    return Row(
      children: [
        Icon(icon, color: AppColors.grey500, size: 20),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            value,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: valueColor,
                ),
          ),
        ),
      ],
    );
  }

  Widget _buildAboutSection(EmployeeModel employee) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'About',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 8),
        Text(
          employee.serviceDetails,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: AppColors.grey700,
                height: 1.5,
              ),
        ),
        if (employee.skills.isNotEmpty) ...[
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: employee.skills.map((skill) {
              return Chip(
                label: Text(skill),
                backgroundColor: AppColors.primary.withOpacity(0.1),
                labelStyle: const TextStyle(color: AppColors.primary),
              );
            }).toList(),
          ),
        ],
      ],
    );
  }

  Future<void> _openWorkVideo(String url) async {
    final uri = Uri.parse(url);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      if (mounted) {
        Helpers.showSnackBar(context, 'Could not open video', isError: true);
      }
    }
  }

  Widget _buildWorkVideosSection(EmployeeModel employee) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Work Samples',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 4),
        Text(
          'Videos ${employee.name.split(' ').first} shared of past work',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: AppColors.grey600,
              ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 120,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: employee.workVideoUrls.length,
            separatorBuilder: (_, __) => const SizedBox(width: 12),
            itemBuilder: (context, index) {
              final url = employee.workVideoUrls[index];
              return GestureDetector(
                onTap: () => _openWorkVideo(url),
                child: Container(
                  width: 160,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.primary.withOpacity(0.2)),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: const BoxDecoration(
                          color: AppColors.primary,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.play_arrow,
                          color: AppColors.white,
                          size: 28,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Video ${index + 1}',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: AppColors.primary,
                              fontWeight: FontWeight.w600,
                            ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildReviewsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Reviews',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 12),
        if (_isLoadingReviews)
          const Center(child: LoadingWidget())
        else if (_reviews.isEmpty)
          const Center(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Text('No reviews yet'),
            ),
          )
        else
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _reviews.length,
            itemBuilder: (context, index) {
              final review = _reviews[index];
              return _buildReviewCard(review);
            },
          ),
      ],
    );
  }

  Widget _buildReviewCard(ReviewModel review) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundColor: AppColors.primary.withOpacity(0.1),
                  backgroundImage: review.customerImage != null
                      ? NetworkImage(review.customerImage!)
                      : null,
                  child: review.customerImage == null
                      ? Text(
                          review.customerName[0].toUpperCase(),
                          style: const TextStyle(color: AppColors.primary),
                        )
                      : null,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        review.customerName,
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                      Text(
                        Helpers.timeAgo(review.createdAt),
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: AppColors.grey500,
                            ),
                      ),
                    ],
                  ),
                ),
                RatingBarIndicator(
                  rating: review.rating,
                  itemBuilder: (context, _) => const Icon(
                    Icons.star,
                    color: AppColors.warning,
                  ),
                  itemCount: 5,
                  itemSize: 16,
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              review.comment,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.grey700,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}
