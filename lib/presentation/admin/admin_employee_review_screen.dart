import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:assisthub/providers/core/constants/app_colors.dart';
import 'package:assisthub/providers/core/utils/helpers.dart';
import 'package:assisthub/providers/employee_provider.dart';
import 'package:assisthub/data/models/employee_model.dart';

class AdminEmployeeReviewScreen extends StatefulWidget {
  const AdminEmployeeReviewScreen({super.key, required this.employee});

  final EmployeeModel employee;

  @override
  State<AdminEmployeeReviewScreen> createState() =>
      _AdminEmployeeReviewScreenState();
}

class _AdminEmployeeReviewScreenState
    extends State<AdminEmployeeReviewScreen> {
  bool _isProcessing = false;

  Future<void> _openUrl(String url) async {
    final uri = Uri.parse(url);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      if (mounted) {
        Helpers.showSnackBar(context, 'Could not open link', isError: true);
      }
    }
  }

  Future<void> _approve() async {
    setState(() => _isProcessing = true);
    final success = await context
        .read<EmployeeProvider>()
        .approveEmployee(widget.employee.id);
    if (!mounted) return;
    setState(() => _isProcessing = false);

    if (success) {
      Helpers.showSnackBar(context, '${widget.employee.name} approved');
      Navigator.pop(context);
    } else {
      Helpers.showSnackBar(context, 'Failed to approve', isError: true);
    }
  }

  Future<void> _reject() async {
    final reasonController = TextEditingController();
    final reason = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Reject employee'),
        content: TextField(
          controller: reasonController,
          maxLines: 3,
          decoration: const InputDecoration(
            hintText: 'Reason (shown to the employee)',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, reasonController.text.trim()),
            child: const Text('Reject'),
          ),
        ],
      ),
    );

    if (reason == null || reason.isEmpty) return;

    setState(() => _isProcessing = true);
    final success = await context
        .read<EmployeeProvider>()
        .rejectEmployee(widget.employee.id, reason);
    if (!mounted) return;
    setState(() => _isProcessing = false);

    if (success) {
      Helpers.showSnackBar(context, '${widget.employee.name} rejected');
      Navigator.pop(context);
    } else {
      Helpers.showSnackBar(context, 'Failed to reject', isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final employee = widget.employee;

    return Scaffold(
      appBar: AppBar(title: Text(employee.name)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _DetailRow(label: 'Email', value: employee.email),
                  _DetailRow(label: 'Phone', value: employee.phone),
                  _DetailRow(label: 'Address', value: employee.address),
                  _DetailRow(label: 'Category', value: employee.serviceCategory),
                  _DetailRow(
                    label: 'Experience',
                    value: '${employee.experienceYears} years',
                  ),
                  _DetailRow(
                    label: 'Rate',
                    value: Helpers.formatCurrency(employee.hourlyRate),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    employee.serviceDetails,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text('Certificates', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          if (employee.documentUrls.isEmpty)
            const Text('No documents submitted')
          else
            ...employee.documentUrls.asMap().entries.map((entry) {
              return Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  leading: const Icon(Icons.description_outlined, color: AppColors.primary),
                  title: Text('Certificate ${entry.key + 1}'),
                  trailing: const Icon(Icons.open_in_new, size: 18),
                  onTap: () => _openUrl(entry.value),
                ),
              );
            }),
          const SizedBox(height: 16),
          Text('Introduction video', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          if (employee.videoUrl == null)
            const Text('No video submitted')
          else
            Card(
              child: ListTile(
                leading: const Icon(Icons.videocam_outlined, color: AppColors.primary),
                title: const Text('View submitted video'),
                trailing: const Icon(Icons.open_in_new, size: 18),
                onTap: () => _openUrl(employee.videoUrl!),
              ),
            ),
          const SizedBox(height: 32),
          if (employee.verificationStatus == VerificationStatus.pending)
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _isProcessing ? null : _reject,
                    style: OutlinedButton.styleFrom(foregroundColor: AppColors.error),
                    child: const Text('Reject'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _isProcessing ? null : _approve,
                    child: _isProcessing
                        ? const SizedBox(
                            height: 18,
                            width: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Approve'),
                  ),
                ),
              ],
            )
          else
            Card(
              color: (employee.verificationStatus == VerificationStatus.approved
                      ? AppColors.success
                      : AppColors.error)
                  .withOpacity(0.1),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Icon(
                      employee.verificationStatus == VerificationStatus.approved
                          ? Icons.check_circle_outline
                          : Icons.cancel_outlined,
                      color: employee.verificationStatus == VerificationStatus.approved
                          ? AppColors.success
                          : AppColors.error,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        employee.verificationStatus == VerificationStatus.approved
                            ? 'This employee has already been approved.'
                            : 'Rejected${employee.rejectionReason != null ? ": ${employee.rejectionReason}" : "."}',
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 90,
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.grey600,
                  ),
            ),
          ),
          Expanded(
            child: Text(value, style: Theme.of(context).textTheme.bodyMedium),
          ),
        ],
      ),
    );
  }
}
