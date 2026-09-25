import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:assisthub/providers/core/constants/app_colors.dart';
import 'package:assisthub/providers/core/utils/helpers.dart';
import 'package:assisthub/providers/employee_provider.dart';

/// Lets an employee upload short work-sample videos that customers can
/// watch on the employee's public profile before booking. Separate from
/// the single private verification video reviewed by admins.
class EmployeeWorkVideosScreen extends StatefulWidget {
  const EmployeeWorkVideosScreen({super.key});

  @override
  State<EmployeeWorkVideosScreen> createState() => _EmployeeWorkVideosScreenState();
}

class _EmployeeWorkVideosScreenState extends State<EmployeeWorkVideosScreen> {
  Future<void> _addVideo() async {
    final provider = context.read<EmployeeProvider>();
    final video = await provider.pickVideo();
    if (video == null) return;

    final success = await provider.addWorkVideo(video);
    if (!mounted) return;
    Helpers.showSnackBar(
      context,
      success ? 'Video added to your profile' : (provider.error ?? 'Upload failed'),
      isError: !success,
    );
  }

  Future<void> _removeVideo(String url) async {
    final confirm = await Helpers.showConfirmDialog(
      context,
      title: 'Remove video',
      message: 'Remove this video from your profile?',
    );
    if (confirm != true) return;

    final success = await context.read<EmployeeProvider>().removeWorkVideo(url);
    if (!mounted) return;
    if (!success) {
      Helpers.showSnackBar(context, 'Failed to remove video', isError: true);
    }
  }

  Future<void> _openVideo(String url) async {
    final uri = Uri.parse(url);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      if (mounted) Helpers.showSnackBar(context, 'Could not open video', isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('My Work Videos')),
      body: Consumer<EmployeeProvider>(
        builder: (context, provider, child) {
          final videos = provider.currentEmployee?.workVideoUrls ?? [];

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Card(
                  color: AppColors.info.withOpacity(0.1),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        const Icon(Icons.info_outline, color: AppColors.info),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Short videos of your past work help customers decide to book you. These show up on your public profile.',
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  color: AppColors.info,
                                ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              Expanded(
                child: videos.isEmpty
                    ? const Center(child: Text('No work videos added yet'))
                    : ListView.separated(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: videos.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 10),
                        itemBuilder: (context, index) {
                          final url = videos[index];
                          return Card(
                            child: ListTile(
                              leading: const Icon(Icons.videocam, color: AppColors.primary),
                              title: Text('Work video ${index + 1}'),
                              onTap: () => _openVideo(url),
                              trailing: IconButton(
                                icon: const Icon(Icons.delete_outline, color: AppColors.error),
                                onPressed: () => _removeVideo(url),
                              ),
                            ),
                          );
                        },
                      ),
              ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: ElevatedButton.icon(
                  onPressed: provider.isLoading ? null : _addVideo,
                  icon: provider.isLoading
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.add),
                  label: Text(provider.isLoading ? 'Uploading...' : 'Add work video'),
                  style: ElevatedButton.styleFrom(minimumSize: const Size.fromHeight(48)),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
