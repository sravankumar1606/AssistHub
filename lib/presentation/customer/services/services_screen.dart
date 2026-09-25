import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:assisthub/providers/core/constants/app_colors.dart';
import 'package:assisthub/providers/core/constants/app_strings.dart';
import 'package:assisthub/providers/core/utils/helpers.dart';
import 'package:assisthub/providers/core/widgets/custom_text_field.dart';
import 'package:assisthub/providers/core/widgets/loading_widget.dart';
import 'package:assisthub/providers/core/widgets/empty_state_widget.dart';
import 'package:assisthub/data/models/service_model.dart';
import 'package:assisthub/data/models/employee_model.dart';
import 'package:assisthub/providers/employee_provider.dart';
import 'package:assisthub/presentation/customer/services/employee_detail_screen.dart';

class ServicesScreen extends StatefulWidget {
  final String? initialCategory;

  const ServicesScreen({super.key, this.initialCategory});

  @override
  State<ServicesScreen> createState() => _ServicesScreenState();
}

class _ServicesScreenState extends State<ServicesScreen> {
  String? _selectedCategory;
  final _searchController = TextEditingController();
  List<EmployeeModel>? _searchResults;

  @override
  void initState() {
    super.initState();
    _selectedCategory = widget.initialCategory;
    
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final employeeProvider = context.read<EmployeeProvider>();
      if (_selectedCategory != null) {
        employeeProvider.subscribeToEmployeesByCategory(_selectedCategory!);
      } else {
        employeeProvider.subscribeToEmployees();
      }
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _search(String query) async {
    if (query.isEmpty) {
      setState(() => _searchResults = null);
      return;
    }

    final results = await context.read<EmployeeProvider>().searchEmployees(query);
    setState(() => _searchResults = results);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(AppStrings.services),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: SearchTextField(
              controller: _searchController,
              hint: AppStrings.searchServices,
              onChanged: _search,
            ),
          ),
          _buildCategoryChips(),
          Expanded(
            child: _buildEmployeesList(),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryChips() {
    final categories = ServiceCategories.all;
    return SizedBox(
      height: 50,
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        scrollDirection: Axis.horizontal,
        itemCount: categories.length + 1,
        itemBuilder: (context, index) {
          if (index == 0) {
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: FilterChip(
                selected: _selectedCategory == null,
                label: const Text('All'),
                onSelected: (_) {
                  setState(() => _selectedCategory = null);
                  context.read<EmployeeProvider>().clearCategoryFilter();
                },
              ),
            );
          }

          final category = categories[index - 1];
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: FilterChip(
              selected: _selectedCategory == category.id,
              label: Text(category.name),
              onSelected: (_) {
                setState(() => _selectedCategory = category.id);
                context.read<EmployeeProvider>().subscribeToEmployeesByCategory(category.id);
              },
            ),
          );
        },
      ),
    );
  }

  Widget _buildEmployeesList() {
    return Consumer<EmployeeProvider>(
      builder: (context, provider, child) {
        final employees = _searchResults ?? provider.employees;

        if (provider.isLoading) {
          return const Center(child: LoadingWidget());
        }

        if (employees.isEmpty) {
          return EmptyStateWidget(
            title: 'No service providers found',
            message: _selectedCategory != null
                ? 'No providers available in this category'
                : 'No providers available at the moment',
            icon: Icons.search_off,
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: employees.length,
          itemBuilder: (context, index) {
            final employee = employees[index];
            return _buildEmployeeCard(employee);
          },
        );
      },
    );
  }

  Widget _buildEmployeeCard(EmployeeModel employee) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => EmployeeDetailScreen(employee: employee),
            ),
          );
        },
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              CircleAvatar(
                radius: 32,
                backgroundColor: AppColors.primary.withOpacity(0.1),
                backgroundImage: employee.profileImage != null
                    ? NetworkImage(employee.profileImage!)
                    : null,
                child: employee.profileImage == null
                    ? Text(
                        employee.name[0].toUpperCase(),
                        style: const TextStyle(
                          fontSize: 24,
                          color: AppColors.primary,
                          fontWeight: FontWeight.bold,
                        ),
                      )
                    : null,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            employee.name,
                            style: Theme.of(context).textTheme.titleMedium,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (employee.isAvailable)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.success.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Text(
                              'Available',
                              style: TextStyle(
                                color: AppColors.success,
                                fontSize: 10,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      employee.serviceCategory,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: AppColors.primary,
                          ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Icon(Icons.star, color: AppColors.warning, size: 16),
                        const SizedBox(width: 4),
                        Text(
                          '${employee.rating.toStringAsFixed(1)} (${employee.totalReviews})',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                        const SizedBox(width: 16),
                        const Icon(Icons.work_outline, size: 16, color: AppColors.grey500),
                        const SizedBox(width: 4),
                        Text(
                          '${employee.experienceYears} years',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.location_on_outlined,
                                size: 16, color: AppColors.grey500),
                            const SizedBox(width: 4),
                            Text(
                              employee.address,
                              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: AppColors.grey600,
                                  ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                        Text(
                          '${Helpers.formatCurrency(employee.hourlyRate)}/hr',
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                color: AppColors.primary,
                                fontWeight: FontWeight.bold,
                              ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
