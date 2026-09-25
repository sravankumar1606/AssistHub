import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:assisthub/providers/core/constants/app_colors.dart';
import 'package:assisthub/providers/core/constants/app_routes.dart';
import 'package:assisthub/providers/core/constants/app_strings.dart';
import 'package:assisthub/providers/core/theme/theme_provider.dart';
import 'package:assisthub/providers/core/utils/validators.dart';
import 'package:assisthub/providers/core/widgets/custom_button.dart';
import 'package:assisthub/providers/core/widgets/custom_text_field.dart';
import 'package:assisthub/providers/core/widgets/loading_widget.dart';
import 'package:assisthub/data/models/review_model.dart';
import 'package:assisthub/data/models/user_model.dart';
import 'package:assisthub/data/repositories/review_repository.dart';
import 'package:assisthub/providers/auth_provider.dart';
import 'package:assisthub/providers/employee_provider.dart';
import 'package:assisthub/presentation/employee/profile/employee_metric_detail_screen.dart';
import 'package:assisthub/providers/core/utils/helpers.dart';
import 'package:assisthub/data/services/storage_service.dart';
import 'package:assisthub/presentation/employee/employee_work_videos_screen.dart';
import 'package:assisthub/presentation/shared/submit_complaint_screen.dart';

class EmployeeProfileScreen extends StatefulWidget {
  const EmployeeProfileScreen({super.key});

  @override
  State<EmployeeProfileScreen> createState() => _EmployeeProfileScreenState();
}

class _EmployeeProfileScreenState extends State<EmployeeProfileScreen> {
  final StorageService storageService = StorageService();
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _addressController = TextEditingController();
  final _serviceDetailsController = TextEditingController();
  final _experienceController = TextEditingController();
  final _hourlyRateController = TextEditingController();
  final _reviewRepository = ReviewRepository();

  bool _isEditing = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _fillForm();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    _serviceDetailsController.dispose();
    _experienceController.dispose();
    _hourlyRateController.dispose();
    super.dispose();
  }

  void _fillForm() {
    final employee = context.read<EmployeeProvider>().currentEmployee;
    if (employee == null) return;

    _nameController.text = employee.name;
    _phoneController.text = employee.phone;
    _addressController.text = employee.address;
    _serviceDetailsController.text = employee.serviceDetails;
    _experienceController.text = employee.experienceYears.toString();
    _hourlyRateController.text = employee.hourlyRate.toStringAsFixed(0);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    final provider = context.read<EmployeeProvider>();
    final success = await provider.updateEmployee({
      'name': _nameController.text.trim(),
      'phone': _phoneController.text.trim(),
      'address': _addressController.text.trim(),
      'serviceDetails': _serviceDetailsController.text.trim(),
      'experienceYears': int.tryParse(_experienceController.text.trim()) ?? 0,
      'hourlyRate': double.tryParse(_hourlyRateController.text.trim()) ?? 0,
    });

    if (!mounted) return;

    if (success) {
      setState(() => _isEditing = false);
      Helpers.showSnackBar(context, AppStrings.profileUpdated);
    } else {
      Helpers.showSnackBar(
        context,
        provider.error ?? 'Unable to update profile',
        isError: true,
      );
    }
  }

  Future<void> _changePhoto() async {
    final provider = context.read<EmployeeProvider>();
    final image = await provider.pickImage();
    if (image == null) return;

    final imageUrl = await storageService.uploadProfileImage(
      provider.currentEmployee!.userId,
      image,
    );
    await provider.updateEmployee({'profileImage': imageUrl});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(AppStrings.profile),
        actions: [
          IconButton(
            tooltip: _isEditing ? 'Cancel' : 'Edit profile',
            icon: Icon(_isEditing ? Icons.close : Icons.edit_outlined),
            onPressed: () {
              setState(() => _isEditing = !_isEditing);
              if (!_isEditing) _fillForm();
            },
          ),
        ],
      ),
      body: Consumer<EmployeeProvider>(
        builder: (context, provider, child) {
          final employee = provider.currentEmployee;
          if (employee == null) {
            return const Center(child: LoadingWidget());
          }

          return LoadingOverlay(
            isLoading: provider.isLoading,
            child: Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _ProfileHeader(
                    name: employee.name,
                    category: employee.serviceCategory,
                    imageUrl: employee.profileImage,
                    isEditing: _isEditing,
                    onChangePhoto: _changePhoto,
                  ),
                  const SizedBox(height: 20),
                  _StatsRow(
                    employeeId: employee.id,
                    rating: employee.rating,
                    totalReviews: employee.totalReviews,
                    totalJobs: employee.totalJobs,
                    totalEarnings: employee.totalEarnings,
                    reviewRepository: _reviewRepository,
                  ),
                  const SizedBox(height: 20),
                  if (_isEditing) ...[
                    _EditForm(
                      nameController: _nameController,
                      phoneController: _phoneController,
                      addressController: _addressController,
                      serviceDetailsController: _serviceDetailsController,
                      experienceController: _experienceController,
                      hourlyRateController: _hourlyRateController,
                    ),
                    const SizedBox(height: 18),
                    GradientButton(text: 'Save Changes', onPressed: _save),
                  ] else ...[
                    _DetailsCard(employeeProvider: provider),
                    const SizedBox(height: 18),
                    _SettingsCard(onLogout: () => _logout(context)),
                    const SizedBox(height: 18),
                    _ReviewsSection(
                      employeeId: employee.id,
                      reviewRepository: _reviewRepository,
                    ),
                  ],
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Future<void> _logout(BuildContext context) async {
    final confirmed = await Helpers.showConfirmDialog(
      context,
      title: 'Logout',
      message: 'Are you sure you want to logout?',
      confirmText: 'Logout',
    );

    if (confirmed != true || !context.mounted) return;

    await context.read<AuthProvider>().signOut();
    if (!context.mounted) return;
    Navigator.pushReplacementNamed(context, AppRoutes.roleSelection);
  }
}

class _ProfileHeader extends StatelessWidget {
  const _ProfileHeader({
    required this.name,
    required this.category,
    required this.imageUrl,
    required this.isEditing,
    required this.onChangePhoto,
  });

  final String name;
  final String category;
  final String? imageUrl;
  final bool isEditing;
  final VoidCallback onChangePhoto;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Stack(
          children: [
            CircleAvatar(
              radius: 54,
              backgroundColor: AppColors.primary.withValues(alpha: 0.12),
              backgroundImage: imageUrl == null ? null : NetworkImage(imageUrl!),
              child: imageUrl == null
                  ? Text(
                      name.isEmpty ? '?' : name[0].toUpperCase(),
                      style: const TextStyle(
                        color: AppColors.primary,
                        fontSize: 38,
                        fontWeight: FontWeight.bold,
                      ),
                    )
                  : null,
            ),
            if (isEditing)
              Positioned(
                right: 0,
                bottom: 0,
                child: IconButton.filled(
                  tooltip: 'Change photo',
                  onPressed: onChangePhoto,
                  icon: const Icon(Icons.camera_alt_outlined),
                ),
              ),
          ],
        ),
        const SizedBox(height: 14),
        Text(
          name,
          style: Theme.of(context).textTheme.titleLarge,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 4),
        Text(
          category,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: AppColors.primary,
                fontWeight: FontWeight.w600,
              ),
        ),
      ],
    );
  }
}

class _StatsRow extends StatelessWidget {
  const _StatsRow({
    required this.employeeId,
    required this.rating,
    required this.totalReviews,
    required this.totalJobs,
    required this.totalEarnings,
    required this.reviewRepository,
  });

  final String employeeId;
  final double rating;
  final int totalReviews;
  final int totalJobs;
  final double totalEarnings;
  final ReviewRepository reviewRepository;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _MiniStat(
          icon: Icons.star,
          label: 'Rating',
          value: rating.toStringAsFixed(1),
          color: AppColors.warning,
          onTap: () => _openMetric(context, EmployeeMetricType.rating),
        ),
        _MiniStat(
          icon: Icons.reviews_outlined,
          label: 'Reviews',
          value: '$totalReviews',
          color: AppColors.primary,
          onTap: () => _openMetric(context, EmployeeMetricType.reviews),
        ),
        _MiniStat(
          icon: Icons.task_alt,
          label: 'Jobs',
          value: '$totalJobs',
          color: AppColors.success,
          onTap: () => _openMetric(context, EmployeeMetricType.jobs),
        ),
        _MiniStat(
          icon: Icons.payments_outlined,
          label: 'Earned',
          value: Helpers.formatCurrency(totalEarnings),
          color: AppColors.info,
          onTap: () => _openMetric(context, EmployeeMetricType.earnings),
        ),
      ],
    );
  }

  void _openMetric(BuildContext context, EmployeeMetricType type) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => EmployeeMetricDetailScreen(
          type: type,
          employeeId: employeeId,
          reviewRepository: reviewRepository,
        ),
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  const _MiniStat({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Card(
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
            child: Column(
              children: [
                Icon(icon, color: color, size: 22),
                const SizedBox(height: 6),
                Text(
                  value,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  label,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.grey600,
                      ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _EditForm extends StatelessWidget {
  const _EditForm({
    required this.nameController,
    required this.phoneController,
    required this.addressController,
    required this.serviceDetailsController,
    required this.experienceController,
    required this.hourlyRateController,
  });

  final TextEditingController nameController;
  final TextEditingController phoneController;
  final TextEditingController addressController;
  final TextEditingController serviceDetailsController;
  final TextEditingController experienceController;
  final TextEditingController hourlyRateController;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        CustomTextField(
          label: 'Name',
          controller: nameController,
          prefixIcon: Icons.person_outline,
          validator: (value) => Validators.required(value, 'Name'),
        ),
        const SizedBox(height: 14),
        CustomTextField(
          label: 'Phone',
          controller: phoneController,
          keyboardType: TextInputType.phone,
          prefixIcon: Icons.phone_outlined,
          validator: Validators.phone,
        ),
        const SizedBox(height: 14),
        CustomTextField(
          label: 'Address',
          controller: addressController,
          maxLines: 2,
          prefixIcon: Icons.location_on_outlined,
          validator: (value) => Validators.required(value, 'Address'),
        ),
        const SizedBox(height: 14),
        CustomTextField(
          label: 'Service Details',
          controller: serviceDetailsController,
          maxLines: 3,
          prefixIcon: Icons.description_outlined,
          validator: (value) => Validators.required(value, 'Service details'),
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(
              child: CustomTextField(
                label: 'Experience',
                controller: experienceController,
                keyboardType: TextInputType.number,
                prefixIcon: Icons.work_outline,
                validator: (value) => Validators.required(value, 'Experience'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: CustomTextField(
                label: 'Hourly Rate',
                controller: hourlyRateController,
                keyboardType: TextInputType.number,
                prefixIcon: Icons.currency_rupee,
                validator: (value) => Validators.required(value, 'Hourly rate'),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _DetailsCard extends StatelessWidget {
  const _DetailsCard({required this.employeeProvider});

  final EmployeeProvider employeeProvider;

  @override
  Widget build(BuildContext context) {
    final employee = employeeProvider.currentEmployee!;

    return Card(
      child: Column(
        children: [
          _DetailTile(icon: Icons.email_outlined, text: employee.email),
          const Divider(height: 0),
          _DetailTile(icon: Icons.phone_outlined, text: employee.phone),
          const Divider(height: 0),
          _DetailTile(icon: Icons.location_on_outlined, text: employee.address),
          const Divider(height: 0),
          _DetailTile(
            icon: Icons.work_outline,
            text: '${employee.experienceYears} years experience',
          ),
          const Divider(height: 0),
          _DetailTile(
            icon: Icons.payments_outlined,
            text: '${Helpers.formatCurrency(employee.hourlyRate)} per hour',
          ),
          const Divider(height: 0),
          SwitchListTile(
            secondary: const Icon(Icons.event_available_outlined),
            title: const Text('Availability'),
            subtitle: Text(
              employee.isAvailable
                  ? 'Customers can book your services'
                  : 'Hidden from active service listings',
            ),
            value: employee.isAvailable,
            activeColor: AppColors.success,
            onChanged: employeeProvider.updateAvailability,
          ),
          const Divider(height: 0),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                employee.serviceDetails,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppColors.grey700,
                      height: 1.45,
                    ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DetailTile extends StatelessWidget {
  const _DetailTile({
    required this.icon,
    required this.text,
  });

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, color: AppColors.grey500),
      title: Text(text.isEmpty ? 'Not provided' : text),
    );
  }
}

class _SettingsCard extends StatelessWidget {
  const _SettingsCard({required this.onLogout});

  final VoidCallback onLogout;

  @override
  Widget build(BuildContext context) {
    final authProvider = context.read<AuthProvider>();

    return Card(
      child: Column(
        children: [
          ListTile(
            leading: const Icon(Icons.videocam_outlined, color: AppColors.primary),
            title: const Text(
              'My Work Videos',
              style: TextStyle(color: AppColors.primary),
            ),
            subtitle: const Text('Show customers samples of your past work'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const EmployeeWorkVideosScreen()),
              );
            },
          ),
          const Divider(height: 0),
          ListTile(
            leading: const Icon(Icons.report_problem_outlined, color: AppColors.error),
            title: const Text('Report a Problem'),
            subtitle: const Text('Issues with a customer, payment, or the app'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const SubmitComplaintScreen()),
              );
            },
          ),
          const Divider(height: 0),

          // Switch to Customer (if already has customer role)
          if (authProvider.hasRole(UserRole.customer)) ...[
            ListTile(
              leading: const Icon(Icons.person_outline, color: AppColors.primary),
              title: const Text(
                'Switch to Customer',
                style: TextStyle(color: AppColors.primary),
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () async {
                await authProvider.switchRole(UserRole.customer);
                if (context.mounted) {
                  Navigator.pushReplacementNamed(context, AppRoutes.customerMain);
                }
              },
            ),
            const Divider(height: 0),
          ],

          // Register as Customer (if not yet a customer)
          if (!authProvider.hasRole(UserRole.customer)) ...[
            ListTile(
              leading: const Icon(Icons.person_add_outlined, color: AppColors.primary),
              title: const Text(
                'Register as Customer',
                style: TextStyle(color: AppColors.primary),
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () async {
                final confirm = await Helpers.showConfirmDialog(
                  context,
                  title: 'Register as Customer',
                  message:
                      'Do you want to also register as a customer? You can book services from other employees.',
                  confirmText: 'Register',
                );
                if (confirm == true && context.mounted) {
                  final success = await authProvider.registerAsRole(UserRole.customer);
                  if (success && context.mounted) {
                    Helpers.showSnackBar(
                      context,
                      'Successfully registered as Customer!',
                    );
                    Navigator.pushReplacementNamed(context, AppRoutes.customerMain);
                  } else if (context.mounted) {
                    Helpers.showSnackBar(
                      context,
                      authProvider.error ?? 'Registration failed',
                      isError: true,
                    );
                  }
                }
              },
            ),
            const Divider(height: 0),
          ],

          Consumer<ThemeProvider>(
            builder: (context, themeProvider, child) {
              return SwitchListTile(
                secondary: const Icon(Icons.dark_mode_outlined),
                title: const Text('Dark Mode'),
                value: themeProvider.isDarkMode,
                onChanged: (_) => themeProvider.toggleTheme(),
              );
            },
          ),
          const Divider(height: 0),
          ListTile(
            leading: const Icon(Icons.logout, color: AppColors.error),
            title: const Text(
              AppStrings.logout,
              style: TextStyle(color: AppColors.error),
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: onLogout,
          ),
        ],
      ),
    );
  }
}

class _ReviewsSection extends StatelessWidget {
  final String employeeId;
  final ReviewRepository reviewRepository;
  const _ReviewsSection({
    Key? key,
    required this.employeeId,
    required this.reviewRepository,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Reviews', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 12),
        FutureBuilder<List<ReviewModel>>(
          future: reviewRepository.getEmployeeReviews(employeeId),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Card(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: Center(child: CircularProgressIndicator()),
                ),
              );
            }

            final reviews = snapshot.data ?? [];
            if (reviews.isEmpty) {
              return Card(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Text(
                    'No reviews yet',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: AppColors.grey600,
                        ),
                  ),
                ),
              );
            }

            return Column(
              children: reviews.map((review) {
                return Card(
                  margin: const EdgeInsets.only(bottom: 10),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: AppColors.primary.withValues(alpha: 0.12),
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
                    title: Row(
                      children: [
                        Expanded(
                          child: Text(
                            review.customerName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const Icon(Icons.star, color: AppColors.warning, size: 18),
                        const SizedBox(width: 4),
                        Text(review.rating.toStringAsFixed(1)),
                      ],
                    ),
                    subtitle: Text(review.comment),
                  ),
                );
              }).toList(),
            );
          },
        ),
      ],
    );
  }
}