import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:assisthub/providers/core/constants/app_colors.dart';
import 'package:assisthub/providers/core/constants/app_routes.dart';
import 'package:assisthub/providers/auth_provider.dart';
import 'package:assisthub/providers/employee_provider.dart';
import 'package:assisthub/data/models/employee_model.dart';
import 'package:assisthub/presentation/employee/registration/employee_registration_screen.dart';

/// Shown instead of the employee dashboard while an employee's account is
/// still pending admin verification, or after rejection (with a path back
/// into the registration form to resubmit). Auto-advances to the
/// employee dashboard the moment an admin approves them, since
/// EmployeeProvider's currentEmployee is a live Firestore subscription.
class PendingApprovalScreen extends StatelessWidget {
  const PendingApprovalScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Consumer<EmployeeProvider>(
          builder: (context, provider, child) {
            final employee = provider.currentEmployee;

            // Live-listens via EmployeeProvider's Firestore subscription —
            // the moment an admin approves, this rebuilds and we jump
            // straight to the dashboard automatically.
            if (employee?.verificationStatus == VerificationStatus.approved) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                Navigator.pushReplacementNamed(context, AppRoutes.employeeMain);
              });
            }

            final isRejected = employee?.verificationStatus == VerificationStatus.rejected;

            return Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    isRejected ? Icons.cancel_outlined : Icons.hourglass_top_outlined,
                    size: 72,
                    color: isRejected ? AppColors.error : AppColors.warning,
                  ),
                  const SizedBox(height: 24),
                  Text(
                    isRejected ? 'Application not approved' : 'Verification in progress',
                    style: Theme.of(context).textTheme.headlineSmall,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    isRejected
                        ? (employee?.rejectionReason?.isNotEmpty == true
                            ? employee!.rejectionReason!
                            : 'Your submitted documents were not approved.')
                        : 'An admin is reviewing your documents/video. '
                            "This page will update automatically once you're approved.",
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: AppColors.grey600,
                        ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 32),
                  if (isRejected)
                    ElevatedButton(
                      onPressed: () {
                        Navigator.pushReplacement(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const EmployeeRegistrationScreen(),
                          ),
                        );
                      },
                      child: const Text('Resubmit documents'),
                    ),
                  const SizedBox(height: 12),
                  TextButton(
                    onPressed: () async {
                      await context.read<AuthProvider>().signOut();
                      if (context.mounted) {
                        Navigator.pushNamedAndRemoveUntil(
                          context,
                          AppRoutes.roleSelection,
                          (route) => false,
                        );
                      }
                    },
                    child: const Text('Sign out'),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
