import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:assisthub/providers/core/constants/app_colors.dart';
import 'package:assisthub/providers/core/utils/helpers.dart';
import 'package:assisthub/providers/employee_provider.dart';
import 'package:assisthub/data/models/employee_model.dart';
import 'package:assisthub/presentation/admin/admin_employee_review_screen.dart';

/// Past employee verification decisions — separate from the Verify tab,
/// which only shows what's currently awaiting review.
class AdminHistoryScreen extends StatefulWidget {
  const AdminHistoryScreen({super.key});

  @override
  State<AdminHistoryScreen> createState() => _AdminHistoryScreenState();
}

class _AdminHistoryScreenState extends State<AdminHistoryScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    // Reuses the same subscription as the Verify tab — both read from
    // the same all-employees stream, just filtered differently.
    context.read<EmployeeProvider>().subscribeToPendingEmployees();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Verification History'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Approved'),
            Tab(text: 'Rejected'),
          ],
        ),
      ),
      body: Consumer<EmployeeProvider>(
        builder: (context, provider, child) {
          return TabBarView(
            controller: _tabController,
            children: [
              _HistoryList(
                employees: provider.approvedEmployees,
                emptyText: 'No approved employees yet',
              ),
              _HistoryList(
                employees: provider.rejectedEmployees,
                emptyText: 'No rejected employees',
              ),
            ],
          );
        },
      ),
    );
  }
}

class _HistoryList extends StatelessWidget {
  const _HistoryList({required this.employees, required this.emptyText});

  final List<EmployeeModel> employees;
  final String emptyText;

  @override
  Widget build(BuildContext context) {
    if (employees.isEmpty) {
      return Center(child: Text(emptyText));
    }

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: employees.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, index) => _HistoryCard(employee: employees[index]),
    );
  }
}

class _HistoryCard extends StatelessWidget {
  const _HistoryCard({required this.employee});

  final EmployeeModel employee;

  @override
  Widget build(BuildContext context) {
    final isApproved = employee.verificationStatus == VerificationStatus.approved;
    final statusColor = isApproved ? AppColors.success : AppColors.error;

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
          isApproved
              ? '${employee.serviceCategory} · ${employee.experienceYears} yrs exp'
              : '${employee.serviceCategory}\n${employee.rejectionReason ?? "No reason given"}',
        ),
        isThreeLine: !isApproved,
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: statusColor.withOpacity(0.12),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            isApproved ? 'Approved' : 'Rejected',
            style: TextStyle(color: statusColor, fontSize: 12, fontWeight: FontWeight.w600),
          ),
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
