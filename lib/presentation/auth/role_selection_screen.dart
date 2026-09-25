import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:assisthub/providers/core/constants/app_colors.dart';
import 'package:assisthub/providers/core/constants/app_routes.dart';
import 'package:assisthub/providers/core/constants/app_strings.dart';
import 'package:assisthub/data/models/user_model.dart';
import 'package:assisthub/providers/auth_provider.dart';
import 'package:assisthub/presentation/admin/admin_login_screen.dart';
import 'package:assisthub/providers/core/widgets/animated_gradient_background.dart';

class RoleSelectionScreen extends StatelessWidget {
  const RoleSelectionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: AnimatedGradientBackground(
        colors: [
          AppColors.primary.withOpacity(0.12),
          AppColors.primary.withOpacity(0.04),
          Colors.transparent,
        ],
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Spacer(),
                _buildHeader(context),
                const SizedBox(height: 48),
                _buildRoleCard(
                  context,
                  title: AppStrings.continueAsCustomer,
                  description: 'Find and book trusted service providers',
                  icon: Icons.person,
                  role: UserRole.customer,
                ),
                const SizedBox(height: 16),
                _buildRoleCard(
                  context,
                  title: AppStrings.continueAsEmployee,
                  description: 'Offer your services and grow your business',
                  icon: Icons.work,
                  role: UserRole.employee,
                ),
                const SizedBox(height: 16),
                Center(
                  child: TextButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const AdminLoginScreen()),
                      );
                    },
                    child: const Text('Admin Login', style: TextStyle(fontSize: 12)),
                  ),
                ),
                const Spacer(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: AppColors.primaryGradient,
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.handyman,
            size: 56,
            color: AppColors.white,
          ),
        ),
        const SizedBox(height: 24),
        Text(
          'Welcome to ${AppStrings.appName}',
          style: Theme.of(context).textTheme.displaySmall,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        Text(
          'How would you like to use the app?',
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: AppColors.grey600,
              ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildRoleCard(
    BuildContext context, {
    required String title,
    required String description,
    required IconData icon,
    required UserRole role,
  }) {
    return Card(
      elevation: 2,
      child: InkWell(
        onTap: () {
          context.read<AuthProvider>().setSelectedRole(role);
          Navigator.pushNamed(context, AppRoutes.login);
        },
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(20),
         child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  icon,
                  size: 32,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      description,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: AppColors.grey600,
                          ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.arrow_forward_ios,
                size: 20,
                color: AppColors.grey400,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
