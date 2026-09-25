import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:assisthub/providers/core/constants/app_colors.dart';
import 'package:assisthub/providers/core/constants/app_strings.dart';
import 'package:assisthub/providers/core/widgets/loading_widget.dart';
import 'package:assisthub/data/models/service_model.dart';
import 'package:assisthub/data/models/employee_model.dart';
import 'package:assisthub/data/models/booking_model.dart';
import 'package:assisthub/providers/auth_provider.dart';
import 'package:assisthub/providers/employee_provider.dart';
import 'package:assisthub/providers/booking_provider.dart';
import 'package:assisthub/presentation/customer/services/services_screen.dart';
import 'package:assisthub/presentation/customer/services/employee_detail_screen.dart';
import 'package:assisthub/presentation/customer/chat/chat_list_screen.dart';
import 'package:assisthub/providers/chat_provider.dart';
import 'package:assisthub/providers/core/utils/helpers.dart';
import 'package:assisthub/providers/core/widgets/animated_gradient_background.dart';
import 'package:assisthub/presentation/customer/booking/instant_booking_category_screen.dart';
class CustomerHomeScreen extends StatefulWidget {
  const CustomerHomeScreen({super.key});

  @override
  State<CustomerHomeScreen> createState() => _CustomerHomeScreenState();
}

class _CustomerHomeScreenState extends State<CustomerHomeScreen> {
  List<EmployeeModel> _topRatedEmployees = [];
  List<BookingModel> _recentBookings = [];
  bool _isLoading = true;

  // Filter state (replaces search bar)
  String? _selectedCategory;
  RangeValues _priceRange = const RangeValues(0, 5000);
  double _minExperience = 0;
  double _minRating = 0;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final employeeProvider = context.read<EmployeeProvider>();
    final bookingProvider = context.read<BookingProvider>();

    try {
      final topRated = await employeeProvider.getTopRatedEmployees();
      final recentBookings = await bookingProvider.getRecentBookings();
      
      if (mounted) {
        setState(() {
          _topRatedEmployees = topRated;
          _recentBookings = recentBookings;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

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
          onRefresh: _loadData,
          child: CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildHeader(user?.name ?? 'Guest'),
                      const SizedBox(height: 24),
                      _buildFilterBar(),
                      const SizedBox(height: 16),
                      _buildInstantBookingBanner(),
                      const SizedBox(height: 24),
                      _buildSectionTitle(AppStrings.categories, onViewAll: () {}),
                      const SizedBox(height: 12),
                    ],
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: _buildCategoriesGrid(),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildSectionTitle(AppStrings.topRatedEmployees, onViewAll: () {}),
                      const SizedBox(height: 12),
                    ],
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: _isLoading
                    ? const Center(child: LoadingWidget())
                    : _buildTopRatedEmployees(),
              ),
              if (_recentBookings.isNotEmpty)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildSectionTitle(AppStrings.recentBookings, onViewAll: () {}),
                        const SizedBox(height: 12),
                        _buildRecentBookings(),
                      ],
                    ),
                  ),
                ),
              const SliverToBoxAdapter(
                child: SizedBox(height: 24),
              ),
            ],
          ),
        ),
        ),
      ),
    );
  }

  Widget _buildHeader(String name) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
            Text(
              'Hello, $name! 👋',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 4),
            Text(
              'What service do you need today?',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.grey600,
                  ),
            ),
          
          ],
          ),
        ),
        IconButton(
          icon: Badge(
            label: Text('${context.watch<ChatProvider>().unreadCount}'),
            isLabelVisible: context.watch<ChatProvider>().unreadCount > 0,
            child: const Icon(Icons.chat_bubble_outline),
          ),
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const ChatListScreen()),
            );
          },
        ),
        const SizedBox(width: 4),
        CircleAvatar(
          radius: 24,
          backgroundColor: AppColors.primary.withOpacity(0.1),
          child: const Icon(Icons.person, color: AppColors.primary),
        ),
      ],
    );
  }

  Widget _buildFilterBar() {
    return SizedBox(
      height: 44,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          _buildFilterChip(
            icon: Icons.category_outlined,
            label: _selectedCategory ?? 'Category',
            active: _selectedCategory != null,
            onTap: () => _showFilterSheet(),
          ),
          const SizedBox(width: 8),
          _buildFilterChip(
            icon: Icons.currency_rupee,
            label: 'Price',
            active: _priceRange.end < 5000,
            onTap: () => _showFilterSheet(),
          ),
          const SizedBox(width: 8),
          _buildFilterChip(
            icon: Icons.work_outline,
            label: 'Experience',
            active: _minExperience > 0,
            onTap: () => _showFilterSheet(),
          ),
          const SizedBox(width: 8),
          _buildFilterChip(
            icon: Icons.star_outline,
            label: 'Rating',
            active: _minRating > 0,
            onTap: () => _showFilterSheet(),
          ),
        ],
      ),
    );
  }

  Widget _buildInstantBookingBanner() {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const InstantBookingCategoryScreen()),
        );
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [AppColors.warning, AppColors.warning.withOpacity(0.7)],
          ),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.white.withOpacity(0.2),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.bolt, color: AppColors.white, size: 24),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Need it right now?',
                    style: TextStyle(
                      color: AppColors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
                  Text(
                    'Instant Booking — sent to every provider nearby',
                    style: TextStyle(color: AppColors.white.withOpacity(0.9), fontSize: 12),
                  ),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios, color: AppColors.white, size: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterChip({
    required IconData icon,
    required String label,
    required bool active,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: active
              ? AppColors.primary.withOpacity(0.1)
              : Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: active ? AppColors.primary : AppColors.grey300,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon,
                size: 16,
                color: active ? AppColors.primary : AppColors.grey600),
            const SizedBox(width: 6),
            Text(
              label,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: active ? AppColors.primary : AppColors.grey600,
                    fontWeight: FontWeight.w500,
                  ),
            ),
            const SizedBox(width: 2),
            Icon(Icons.keyboard_arrow_down,
                size: 16,
                color: active ? AppColors.primary : AppColors.grey600),
          ],
        ),
      ),
    );
  }

  void _showFilterSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _FilterSheetContent(
        selectedCategory: _selectedCategory,
        priceRange: _priceRange,
        minExperience: _minExperience,
        minRating: _minRating,
        onApply: (category, price, experience, rating) {
          setState(() {
            _selectedCategory = category;
            _priceRange = price;
            _minExperience = experience;
            _minRating = rating;
          });
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => ServicesScreen(initialCategory: _selectedCategory),
              // TODO: extend ServicesScreen to accept price/experience/rating
              // and pass them through to EmployeeProvider's Firestore query.
            ),
          );
        },
      ),
    );
  }
  Widget _buildSectionTitle(String title, {VoidCallback? onViewAll}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Text(
            title,
            style: Theme.of(context).textTheme.titleLarge,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        if (onViewAll != null)
          TextButton(
            onPressed: onViewAll,
            child: const Text(AppStrings.viewAll),
          ),
      ],
    );
  }

  Widget _buildCategoriesGrid() {
    final categories = ServiceCategories.all;
    return SizedBox(
      height: 120,
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        scrollDirection: Axis.horizontal,
        itemCount: categories.length,
        itemBuilder: (context, index) {
          final category = categories[index];
          return _buildCategoryCard(category);
        },
      ),
    );
  }

  Widget _buildCategoryCard(ServiceCategory category) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ServicesScreen(initialCategory: category.id),
          ),
        );
      },
      child: Container(
        width: 100,
        margin: const EdgeInsets.only(right: 12),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: AppColors.grey300.withOpacity(0.3),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                category.iconData,
                color: AppColors.primary,
                size: 28,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              category.name,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.w500,
                  ),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopRatedEmployees() {
    if (_topRatedEmployees.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text('No employees available'),
        ),
      );
    }

    return SizedBox(
      height: 200,
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        scrollDirection: Axis.horizontal,
        itemCount: _topRatedEmployees.length,
        itemBuilder: (context, index) {
          final employee = _topRatedEmployees[index];
          return _buildEmployeeCard(employee);
        },
      ),
    );
  }

  Widget _buildEmployeeCard(EmployeeModel employee) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => EmployeeDetailScreen(employee: employee),
          ),
        );
      },
      child: Container(
        width: 160,
        margin: const EdgeInsets.only(right: 12),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: AppColors.grey300.withOpacity(0.3),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: CircleAvatar(
                  radius: 36,
                  backgroundColor: AppColors.primary.withOpacity(0.1),
                  backgroundImage: employee.profileImage != null
                      ? NetworkImage(employee.profileImage!)
                      : null,
                  child: employee.profileImage == null
                      ? Text(
                          employee.name[0].toUpperCase(),
                          style: const TextStyle(
                            fontSize: 28,
                            color: AppColors.primary,
                          ),
                        )
                      : null,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                employee.name,
                style: Theme.of(context).textTheme.titleMedium,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
              Text(
                employee.serviceCategory,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppColors.grey600,
                    ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const Spacer(),
              Row(
                children: [
                  const Icon(Icons.star, color: AppColors.warning, size: 16),
                  const SizedBox(width: 4),
                  Text(
                    employee.rating.toStringAsFixed(1),
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                  const Spacer(),
                  Text(
                    '${Helpers.formatCurrency(employee.hourlyRate)}/hr',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppColors.primary,
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRecentBookings() {
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _recentBookings.length > 3 ? 3 : _recentBookings.length,
      itemBuilder: (context, index) {
        final booking = _recentBookings[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          child: ListTile(
            leading: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                Icons.home_repair_service,
                color: AppColors.primary,
              ),
            ),
            title: Text(booking.serviceCategory),
            subtitle: Text(booking.employeeName),
            trailing: Container(
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
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _FilterSheetContent extends StatefulWidget {
  final String? selectedCategory;
  final RangeValues priceRange;
  final double minExperience;
  final double minRating;
  final void Function(
    String? category,
    RangeValues price,
    double experience,
    double rating,
  ) onApply;

  const _FilterSheetContent({
    required this.selectedCategory,
    required this.priceRange,
    required this.minExperience,
    required this.minRating,
    required this.onApply,
  });

  @override
  State<_FilterSheetContent> createState() => _FilterSheetContentState();
}

class _FilterSheetContentState extends State<_FilterSheetContent> {
  String? _category;
  late RangeValues _price;
  late double _experience;
  late double _rating;

  @override
  void initState() {
    super.initState();
    _category = widget.selectedCategory;
    _price = widget.priceRange;
    _experience = widget.minExperience;
    _rating = widget.minRating;
  }

  @override
  Widget build(BuildContext context) {
    final categories = ServiceCategories.all;

    return Container(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: AppColors.grey300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Text('Filters', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 20),
            Text('Category', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: categories.map((c) {
                final isSelected = _category == c.id;
                return ChoiceChip(
                  label: Text(c.name),
                  selected: isSelected,
                  onSelected: (_) =>
                      setState(() => _category = isSelected ? null : c.id),
                  selectedColor: AppColors.primary.withOpacity(0.15),
                  labelStyle: TextStyle(
                    color: isSelected ? AppColors.primary : AppColors.grey600,
                    fontWeight: FontWeight.w500,
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 24),
            Text('Price range', style: Theme.of(context).textTheme.titleSmall),
            RangeSlider(
              min: 0,
              max: 5000,
              divisions: 20,
              values: _price,
              labels: RangeLabels(
                Helpers.formatCurrency(_price.start),
                Helpers.formatCurrency(_price.end),
              ),
              activeColor: AppColors.primary,
              onChanged: (v) => setState(() => _price = v),
            ),
            const SizedBox(height: 8),
            Text('Years of experience',
                style: Theme.of(context).textTheme.titleSmall),
            Slider(
              min: 0,
              max: 15,
              divisions: 15,
              value: _experience,
              label: _experience == 0 ? 'Any' : '${_experience.toInt()}+ yrs',
              activeColor: AppColors.primary,
              onChanged: (v) => setState(() => _experience = v),
            ),
            const SizedBox(height: 16),
            Text('Minimum rating', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 8),
            Row(
              children: List.generate(5, (index) {
                final starValue = index + 1;
                return IconButton(
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  onPressed: () => setState(
                    () => _rating =
                        _rating == starValue.toDouble() ? 0 : starValue.toDouble(),
                  ),
                  icon: Icon(
                    starValue <= _rating ? Icons.star : Icons.star_border,
                    color: AppColors.warning,
                    size: 28,
                  ),
                );
              }),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () {
                      setState(() {
                        _category = null;
                        _price = const RangeValues(0, 5000);
                        _experience = 0;
                        _rating = 0;
                      });
                    },
                    child: const Text('Clear all'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    style:
                        ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
                    onPressed: () {
                      Navigator.pop(context);
                      widget.onApply(_category, _price, _experience, _rating);
                    },
                    child: const Text('Apply filters'),
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
