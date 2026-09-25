import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:assisthub/providers/core/constants/app_colors.dart';
import 'package:assisthub/providers/core/utils/helpers.dart';
import 'package:assisthub/providers/auth_provider.dart';
import 'package:assisthub/providers/employee_provider.dart';
import 'package:assisthub/data/models/employee_model.dart';
import 'package:assisthub/presentation/admin/admin_employee_review_screen.dart';
import 'package:assisthub/presentation/auth/role_selection_screen.dart';

/// Admin dashboard: employees currently awaiting verification.
/// See admin_history_screen.dart for past Approved/Rejected decisions.
class AdminPendingEmployeesScreen extends StatefulWidget {
  const AdminPendingEmployeesScreen({super.key});

  @override
  State<AdminPendingEmployeesScreen> createState() =>
      _AdminPendingEmployeesScreenState();
}

class _AdminPendingEmployeesScreenState
    extends State<AdminPendingEmployeesScreen> {
  @override
  void initState() {
    super.initState();
    context.read<EmployeeProvider>().subscribeToPendingEmployees();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Pending Verifications'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Sign out',
            onPressed: () async {
              await context.read<AuthProvider>().signOut();
              if (context.mounted) {
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (_) => const RoleSelectionScreen()),
                  (route) => false,
                );
              }
            },
          ),
        ],
      ),
      body: Consumer<EmployeeProvider>(
        builder: (context, provider, child) {
          final pending = provider.pendingEmployees;

          if (pending.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text('No employees waiting for review'),
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: pending.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              final employee = pending[index];
              return _PendingEmployeeCard(employee: employee);
            },
          );
        },
      ),
    );
  }
}

class _PendingEmployeeCard extends StatelessWidget {
  const _PendingEmployeeCard({required this.employee});

  final EmployeeModel employee;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        contentPadding: const EdgeInsets.all(12),
        leading: CircleAvatar(
          radius: 26,
          backgroundColor: AppColors.primary.withOpacity(0.1),
          backgroundImage:
              employee.profileImage != null ? NetworkImage(employee.profileImage!) : null,
          child: employee.profileImage == null
              ? Text(
                  employee.name.isEmpty ? '?' : employee.name[0].toUpperCase(),
                  style: const TextStyle(color: AppColors.primary),
                )
              : null,
        ),
        title: Text(employee.name, style: Theme.of(context).textTheme.titleMedium),
        subtitle: Text(
          '${employee.serviceCategory} · ${employee.experienceYears} yrs exp\n'
          'Submitted ${Helpers.formatDate(employee.createdAt)}',
        ),
        isThreeLine: true,
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (employee.documentUrls.isNotEmpty)
              const Padding(
                padding: EdgeInsets.only(right: 4),
                child: Icon(Icons.description_outlined, size: 18, color: AppColors.grey600),
              ),
            if (employee.videoUrl != null)
              const Padding(
                padding: EdgeInsets.only(right: 8),
                child: Icon(Icons.videocam_outlined, size: 18, color: AppColors.grey600),
              ),
            const Icon(Icons.chevron_right),
          ],
        ),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => AdminEmployeeReviewScreen(employee: employee),
            ),
          );
        },
      ),
    );
  }
}
