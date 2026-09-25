import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:assisthub/providers/auth_provider.dart';
import 'package:assisthub/providers/core/constants/app_colors.dart';
import 'package:assisthub/providers/core/constants/app_routes.dart';
import 'package:assisthub/data/models/user_model.dart';
import 'package:assisthub/providers/employee_provider.dart';
import 'package:assisthub/data/models/employee_model.dart';
import 'package:assisthub/presentation/employee/pending_approval_screen.dart';

class RolePickerScreen extends StatelessWidget {
  const RolePickerScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final authProvider = context.read<AuthProvider>();

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header
              const Icon(
                Icons.switch_account_outlined,
                size: 72,
                color: AppColors.primary,
              ),
              const SizedBox(height: 24),
              Text(
                'Continue as',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.displaySmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 8),
              Text(
                'Your account has multiple roles.\nChoose how you want to continue.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: AppColors.grey600,
                    ),
              ),
              const SizedBox(height: 48),

              // Customer Card
              _buildRoleCard(
                context: context,
                icon: Icons.person_outline,
                title: 'Customer',
                subtitle: 'Book services, manage bookings',
                color: AppColors.primary,
                onTap: () async {
                  await authProvider.switchRole(UserRole.customer);
                  if (context.mounted) {
                    Navigator.pushReplacementNamed(
                      context,
                      AppRoutes.customerMain,
                    );
                  }
                },
              ),
              const SizedBox(height: 16),

              // Employee Card
              _buildRoleCard(
                context: context,
                icon: Icons.work_outline,
                title: 'Employee',
                subtitle: 'Manage bookings, provide services',
                color: AppColors.success,
                onTap: () async {
                  await authProvider.switchRole(UserRole.employee);
                  if (context.mounted) {
                    final employeeProvider = context.read<EmployeeProvider>();
                    await employeeProvider.loadCurrentEmployee(
                      authProvider.user!.id,
                    );
                    if (context.mounted) {
                      final employee = employeeProvider.currentEmployee;
                      if (employee == null) {
                        Navigator.pushReplacementNamed(
                          context,
                          AppRoutes.employeeRegistration,
                        );
                      } else if (employee.verificationStatus ==
                          VerificationStatus.approved) {
                        Navigator.pushReplacementNamed(
                          context,
                          AppRoutes.employeeMain,
                        );
                      } else {
                        // Pending or rejected — show the waiting/resubmit
                        // screen instead of the dashboard.
                        Navigator.pushReplacement(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const PendingApprovalScreen(),
                          ),
                        );
                      }
                    }
                  }
                },
              ),
              const SizedBox(height: 32),

              // Sign out option
              TextButton(
                onPressed: () async {
                  await authProvider.signOut();
                  if (context.mounted) {
                    Navigator.pushReplacementNamed(
                      context,
                      AppRoutes.roleSelection,
                    );
                  }
                },
                child: const Text('Sign out'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRoleCard({
    required BuildContext context,
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: color, size: 32),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    Text(
                      subtitle,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: AppColors.grey600,
                          ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.arrow_forward_ios, size: 16, color: AppColors.grey500),
            ],
          ),
        ),
      ),
    );
  }
}