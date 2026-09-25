import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:assisthub/providers/core/constants/app_colors.dart';
import 'package:assisthub/providers/core/constants/app_routes.dart';
import 'package:assisthub/providers/core/constants/app_strings.dart';
import 'package:assisthub/providers/core/utils/helpers.dart';
import 'package:assisthub/providers/core/widgets/custom_button.dart';
import 'package:assisthub/providers/core/widgets/custom_text_field.dart';
import 'package:assisthub/providers/core/widgets/loading_widget.dart';
import 'package:assisthub/providers/core/theme/theme_provider.dart';
import 'package:assisthub/providers/auth_provider.dart';
import 'package:assisthub/providers/user_provider.dart';
import 'package:assisthub/providers/booking_provider.dart';
import 'package:assisthub/data/models/booking_model.dart';
import 'package:assisthub/data/models/user_model.dart';
import 'package:assisthub/presentation/customer/booking/customer_booking_history_screen.dart';
import 'package:assisthub/presentation/shared/submit_complaint_screen.dart';

class CustomerProfileScreen extends StatefulWidget {
  const CustomerProfileScreen({super.key});

  @override
  State<CustomerProfileScreen> createState() => _CustomerProfileScreenState();
}

class _CustomerProfileScreenState extends State<CustomerProfileScreen> {
  bool _isEditing = false;
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _addressController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  void _loadUserData() {
    final user = context.read<AuthProvider>().user;
    if (user != null) {
      _nameController.text = user.name;
      _phoneController.text = user.phone ?? '';
      _addressController.text = user.address ?? '';
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;

    final userProvider = context.read<UserProvider>();
    final success = await userProvider.updateProfile(
      name: _nameController.text,
      phone: _phoneController.text,
      address: _addressController.text,
    );

    if (success && mounted) {
      setState(() => _isEditing = false);
      final user = userProvider.user ?? context.read<AuthProvider>().user;
      if (user != null) {
        _nameController.text = user.name;
        _phoneController.text = user.phone ?? '';
        _addressController.text = user.address ?? '';
      }
      Helpers.showSnackBar(context, AppStrings.profileUpdated);
    } else if (mounted) {
      Helpers.showSnackBar(context, userProvider.error ?? 'Update failed', isError: true);
    }
  }

  Future<void> _updateProfileImage() async {
    final userProvider = context.read<UserProvider>();
    final imageFile = await userProvider.pickImage();
    if (imageFile != null) {
      await userProvider.updateProfileImage(imageFile);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(AppStrings.profile),
        actions: [
          if (!_isEditing)
            IconButton(
              icon: const Icon(Icons.edit),
              onPressed: () => setState(() => _isEditing = true),
            )
          else
            IconButton(
              icon: const Icon(Icons.close),
              onPressed: () {
                setState(() => _isEditing = false);
                _loadUserData();
              },
            ),
        ],
      ),
      body: Consumer2<AuthProvider, UserProvider>(
        builder: (context, authProvider, userProvider, child) {
          final user = userProvider.user ?? authProvider.user;
          if (user == null) {
            return const Center(child: LoadingWidget());
          }

          return LoadingOverlay(
            isLoading: userProvider.isLoading,
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: Column(
                  children: [
                    _buildProfileImage(user.profileImage, user.name),
                    const SizedBox(height: 24),
                    if (_isEditing) ...[
                      _buildEditForm(),
                      const SizedBox(height: 24),
                      GradientButton(
                        text: 'Save Changes',
                        onPressed: _saveProfile,
                        isLoading: userProvider.isLoading,
                      ),
                    ] else ...[
                      _buildProfileInfo(user.name, user.email, user.phone, user.address),
                      const SizedBox(height: 24),
                      _buildStatsCards(),
                      const SizedBox(height: 24),
                      _buildSettingsSection(authProvider),
                    ],
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildProfileImage(String? imageUrl, String name) {
    return Stack(
      children: [
        CircleAvatar(
          radius: 50,
          backgroundColor: AppColors.primary.withValues(alpha: 0.1),
          backgroundImage: imageUrl != null ? NetworkImage(imageUrl) : null,
          child: imageUrl == null
              ? Text(
                  name[0].toUpperCase(),
                  style: const TextStyle(
                    fontSize: 40,
                    color: AppColors.primary,
                    fontWeight: FontWeight.bold,
                  ),
                )
              : null,
        ),
        if (_isEditing)
          Positioned(
            bottom: 0,
            right: 0,
            child: GestureDetector(
              onTap: _updateProfileImage,
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: const BoxDecoration(
                  color: AppColors.primary,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.camera_alt,
                  color: AppColors.white,
                  size: 20,
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildEditForm() {
    return Column(
      children: [
        CustomTextField(
          label: AppStrings.name,
          controller: _nameController,
          prefixIcon: Icons.person_outline,
        ),
        const SizedBox(height: 16),
        CustomTextField(
          label: AppStrings.phone,
          controller: _phoneController,
          keyboardType: TextInputType.phone,
          prefixIcon: Icons.phone_outlined,
        ),
        const SizedBox(height: 16),
        CustomTextField(
          label: AppStrings.address,
          controller: _addressController,
          maxLines: 2,
          prefixIcon: Icons.location_on_outlined,
        ),
      ],
    );
  }

  Widget _buildProfileInfo(String name, String email, String? phone, String? address) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _buildInfoRow(Icons.person_outline, name),
            const Divider(height: 24),
            _buildInfoRow(Icons.email_outlined, email),
            if (phone != null && phone.isNotEmpty) ...[
              const Divider(height: 24),
              _buildInfoRow(Icons.phone_outlined, phone),
            ],
            if (address != null && address.isNotEmpty) ...[
              const Divider(height: 24),
              _buildInfoRow(Icons.location_on_outlined, address),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String value) {
    return Row(
      children: [
        Icon(icon, color: AppColors.grey500, size: 20),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            value,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ),
      ],
    );
  }

  Widget _buildStatsCards() {
    return Consumer<BookingProvider>(
      builder: (context, provider, _) {
        final totalBookings = provider.bookings.length;
        final completedBookings = provider.bookings
            .where((b) => b.status == BookingStatus.completed)
            .length;

        return Row(
          children: [
            Expanded(
              child: _buildStatCard(
                icon: Icons.calendar_today,
                value: '$totalBookings',
                label: 'Total Bookings',
                color: AppColors.primary,
                onTap: () => _openBookings(CustomerBookingView.active),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildStatCard(
                icon: Icons.check_circle,
                value: '$completedBookings',
                label: 'Completed',
                color: AppColors.success,
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildStatCard({
    required IconData icon,
    required String value,
    required String label,
    required Color color,
    VoidCallback? onTap,
  }) {
    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Icon(icon, color: color, size: 32),
              const SizedBox(height: 8),
              Text(
                value,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
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
          ),
        ),
      ),
    );
  }

  void _openBookings(CustomerBookingView view) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CustomerBookingHistoryScreen(initialView: view),
      ),
    );
  }

  Widget _buildSettingsSection(AuthProvider authProvider) {
    return Card(
      child: Column(
        children: [
          _buildSettingsTile(
            icon: Icons.history,
            title: AppStrings.bookingHistory,
            onTap: () => _openBookings(CustomerBookingView.history),
          ),
          const Divider(height: 0),
          _buildSettingsTile(
            icon: Icons.report_problem_outlined,
            title: 'Report a Problem',
            iconColor: AppColors.error,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const SubmitComplaintScreen()),
              );
            },
          ),
          const Divider(height: 0),

          // Switch to Employee (if already has employee role)
          if (authProvider.hasRole(UserRole.employee)) ...[
            _buildSettingsTile(
              icon: Icons.switch_account,
              title: 'Switch to Employee',
              iconColor: AppColors.success,
              textColor: AppColors.success,
              onTap: () async {
                await authProvider.switchRole(UserRole.employee);
                if (mounted) {
                  Navigator.pushReplacementNamed(context, AppRoutes.employeeMain);
                }
              },
            ),
            const Divider(height: 0),
          ],

          // Register as Employee (if not yet an employee)
          if (!authProvider.hasRole(UserRole.employee)) ...[
            _buildSettingsTile(
              icon: Icons.work_outline,
              title: 'Register as Employee',
              iconColor: AppColors.success,
              textColor: AppColors.success,
              onTap: () async {
                final confirm = await Helpers.showConfirmDialog(
                  context,
                  title: 'Register as Employee',
                  message:
                      'Do you want to also register as an employee? You can offer services to customers.',
                  confirmText: 'Register',
                );
                if (confirm == true && mounted) {
                  final success = await authProvider.registerAsRole(UserRole.employee);
                  if (success && mounted) {
                    Helpers.showSnackBar(
                      context,
                      'Successfully registered as Employee!',
                    );
                    Navigator.pushNamed(context, AppRoutes.employeeRegistration);
                  } else if (mounted) {
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
            builder: (context, themeProvider, _) {
              return SwitchListTile(
                secondary: const Icon(Icons.dark_mode_outlined),
                title: const Text('Dark Mode'),
                value: themeProvider.isDarkMode,
                onChanged: (_) => themeProvider.toggleTheme(),
              );
            },
          ),
          const Divider(height: 0),
          _buildSettingsTile(
            icon: Icons.logout,
            title: AppStrings.logout,
            iconColor: AppColors.error,
            textColor: AppColors.error,
            onTap: () async {
              final confirm = await Helpers.showConfirmDialog(
                context,
                title: 'Logout',
                message: 'Are you sure you want to logout?',
                confirmText: 'Logout',
              );
              if (confirm == true && mounted) {
                await context.read<AuthProvider>().signOut();
                Navigator.pushReplacementNamed(context, AppRoutes.roleSelection);
              }
            },
          ),
        ],
      ),
    );
  }

  Widget _buildSettingsTile({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
    Color? iconColor,
    Color? textColor,
  }) {
    return ListTile(
      leading: Icon(icon, color: iconColor),
      title: Text(
        title,
        style: TextStyle(color: textColor),
      ),
      trailing: const Icon(Icons.arrow_forward_ios, size: 16),
      onTap: onTap,
    );
  }
}