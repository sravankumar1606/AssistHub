import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:assisthub/providers/core/widgets/custom_button.dart';
import 'package:assisthub/providers/core/widgets/custom_text_field.dart';
import 'package:assisthub/providers/core/utils/helpers.dart';
import 'package:assisthub/providers/complaint_provider.dart';

/// Reusable complaint form — link to this from both the customer and
/// employee profile screens (e.g. a "Report a problem" list item).
class SubmitComplaintScreen extends StatefulWidget {
  const SubmitComplaintScreen({super.key, this.bookingId});

  final String? bookingId;

  @override
  State<SubmitComplaintScreen> createState() => _SubmitComplaintScreenState();
}

class _SubmitComplaintScreenState extends State<SubmitComplaintScreen> {
  final _formKey = GlobalKey<FormState>();
  final _subjectController = TextEditingController();
  final _descriptionController = TextEditingController();
  bool _isSubmitting = false;

  @override
  void dispose() {
    _subjectController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSubmitting = true);
    final success = await context.read<ComplaintProvider>().submitComplaint(
          subject: _subjectController.text.trim(),
          description: _descriptionController.text.trim(),
          bookingId: widget.bookingId,
        );

    if (!mounted) return;
    setState(() => _isSubmitting = false);

    if (success) {
      Helpers.showSnackBar(context, 'Complaint submitted. Our team will review it.');
      Navigator.pop(context);
    } else {
      Helpers.showSnackBar(context, 'Failed to submit complaint', isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Report a problem')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            CustomTextField(
              label: 'Subject',
              hint: 'Brief summary of the issue',
              controller: _subjectController,
              validator: (value) =>
                  (value == null || value.trim().isEmpty) ? 'Enter a subject' : null,
            ),
            const SizedBox(height: 16),
            CustomTextField(
              label: 'Description',
              hint: 'Describe what happened in detail...',
              controller: _descriptionController,
              maxLines: 5,
              validator: (value) =>
                  (value == null || value.trim().isEmpty) ? 'Enter a description' : null,
            ),
            const SizedBox(height: 24),
            GradientButton(
              text: 'Submit Complaint',
              onPressed: _submit,
              isLoading: _isSubmitting,
            ),
          ],
        ),
      ),
    );
  }
}
