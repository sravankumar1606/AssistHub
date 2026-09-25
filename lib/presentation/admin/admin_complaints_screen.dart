import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:assisthub/providers/core/constants/app_colors.dart';
import 'package:assisthub/providers/core/utils/helpers.dart';
import 'package:assisthub/providers/complaint_provider.dart';
import 'package:assisthub/data/models/complaint_model.dart';

class AdminComplaintsScreen extends StatefulWidget {
  const AdminComplaintsScreen({super.key});

  @override
  State<AdminComplaintsScreen> createState() => _AdminComplaintsScreenState();
}

class _AdminComplaintsScreenState extends State<AdminComplaintsScreen> {
  @override
  void initState() {
    super.initState();
    context.read<ComplaintProvider>().subscribeToAllComplaints();
  }

  Future<void> _resolve(ComplaintModel complaint) async {
    final responseController = TextEditingController();
    final response = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Resolve complaint'),
        content: TextField(
          controller: responseController,
          maxLines: 3,
          decoration: const InputDecoration(hintText: 'Resolution notes'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, responseController.text.trim()),
            child: const Text('Mark Resolved'),
          ),
        ],
      ),
    );

    if (response == null || response.isEmpty) return;
    if (!mounted) return;

    final success =
        await context.read<ComplaintProvider>().resolveComplaint(complaint.id, response);
    if (!mounted) return;
    Helpers.showSnackBar(
      context,
      success ? 'Complaint resolved' : 'Failed to resolve complaint',
      isError: !success,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Complaints')),
      body: Consumer<ComplaintProvider>(
        builder: (context, provider, child) {
          final complaints = provider.allComplaints;

          if (complaints.isEmpty) {
            return const Center(child: Text('No complaints filed'));
          }

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: complaints.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              final complaint = complaints[index];
              final isResolved = complaint.status == ComplaintStatus.resolved;

              return Card(
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              complaint.subject,
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: (isResolved ? AppColors.success : AppColors.warning)
                                  .withOpacity(0.12),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              isResolved ? 'Resolved' : 'Open',
                              style: TextStyle(
                                color: isResolved ? AppColors.success : AppColors.warning,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${complaint.reporterName} (${complaint.reporterRole}) · ${Helpers.formatDate(complaint.createdAt)}',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: AppColors.grey600,
                            ),
                      ),
                      const SizedBox(height: 8),
                      Text(complaint.description),
                      if (complaint.adminResponse != null) ...[
                        const SizedBox(height: 8),
                        Text(
                          'Response: ${complaint.adminResponse}',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                fontStyle: FontStyle.italic,
                              ),
                        ),
                      ],
                      if (!isResolved) ...[
                        const SizedBox(height: 12),
                        Align(
                          alignment: Alignment.centerRight,
                          child: OutlinedButton(
                            onPressed: () => _resolve(complaint),
                            child: const Text('Resolve'),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
