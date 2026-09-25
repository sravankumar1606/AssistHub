import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:assisthub/providers/core/constants/app_colors.dart';
import 'package:assisthub/providers/core/constants/app_routes.dart';
import 'package:assisthub/providers/core/utils/validators.dart';
import 'package:assisthub/providers/core/utils/helpers.dart';
import 'package:assisthub/providers/core/widgets/custom_button.dart';
import 'package:assisthub/providers/core/widgets/custom_text_field.dart';
import 'package:assisthub/providers/core/widgets/loading_widget.dart';
import 'package:assisthub/data/models/service_model.dart';
import 'package:assisthub/providers/auth_provider.dart';
import 'package:assisthub/providers/employee_provider.dart';
import 'package:assisthub/presentation/employee/pending_approval_screen.dart';
import 'dart:typed_data';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';

class EmployeeRegistrationScreen extends StatefulWidget {
  const EmployeeRegistrationScreen({super.key});

  @override
  State<EmployeeRegistrationScreen> createState() => _EmployeeRegistrationScreenState();
}

class _EmployeeRegistrationScreenState extends State<EmployeeRegistrationScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _addressController = TextEditingController();
  final _serviceDetailsController = TextEditingController();
  final _experienceController = TextEditingController();
  final _hourlyRateController = TextEditingController();

  String? _selectedCategory;
  XFile? _profileImage;
  Uint8List? _profileImageBytes;
  List<PlatformFile> _documents = [];
  XFile? _video;
  int _currentStep = 0;

  @override
  void initState() {
    super.initState();
    final user = context.read<AuthProvider>().user;
    if (user != null) {
      _nameController.text = user.name;
      _emailController.text = user.email;
      _phoneController.text = user.phone ?? '';
      _addressController.text = user.address ?? '';
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    _serviceDetailsController.dispose();
    _experienceController.dispose();
    _hourlyRateController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final employeeProvider = context.read<EmployeeProvider>();
    final image = await employeeProvider.pickImage();
    if (image != null) {
      final bytes = await image.readAsBytes();
      setState(() {
        _profileImage = image;
        _profileImageBytes = bytes;
      });
    }
  }

  Future<void> _pickDocuments() async {
    final employeeProvider = context.read<EmployeeProvider>();
    final files = await employeeProvider.pickDocuments();
    if (files.isNotEmpty) {
      setState(() => _documents = [..._documents, ...files]);
    }
  }

  void _removeDocument(int index) {
    setState(() => _documents.removeAt(index));
  }

  Future<void> _pickVideo() async {
    final employeeProvider = context.read<EmployeeProvider>();
    final video = await employeeProvider.pickVideo();
    if (video != null) {
      setState(() => _video = video);
    }
  }

  Future<void> _submitRegistration() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedCategory == null) {
      Helpers.showSnackBar(context, 'Please select a service category', isError: true);
      return;
    }

    final experienceYears = int.tryParse(_experienceController.text.trim());
    if (experienceYears == null || experienceYears < 0) {
      Helpers.showSnackBar(context, 'Enter a valid experience value', isError: true);
      return;
    }

    final hourlyRate = double.tryParse(_hourlyRateController.text.trim());
    if (hourlyRate == null || hourlyRate <= 0) {
      Helpers.showSnackBar(context, 'Enter a valid hourly rate', isError: true);
      return;
    }

    if (_documents.isEmpty && _video == null) {
      Helpers.showSnackBar(
        context,
        'Please upload at least one certificate or an introduction video for verification',
        isError: true,
      );
      return;
    }

    final authProvider = context.read<AuthProvider>();
    final employeeProvider = context.read<EmployeeProvider>();
    employeeProvider.attachAuth(authProvider);

    final success = await employeeProvider.registerAsEmployee(
      name: _nameController.text.trim(),
      email: _emailController.text.trim(),
      phone: _phoneController.text.trim(),
      address: _addressController.text.trim(),
      serviceCategory: _selectedCategory!,
      serviceDetails: _serviceDetailsController.text.trim(),
      experienceYears: experienceYears,
      hourlyRate: hourlyRate,
      profileImage: _profileImage,
      documents: _documents,
      video: _video,
    );

    if (success && mounted) {
      Helpers.showSnackBar(
        context,
        'Registration submitted! Your profile will be visible to customers once an admin approves your documents.',
      );
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const PendingApprovalScreen()),
      );
    } else if (mounted) {
      Helpers.showSnackBar(context, employeeProvider.error ?? 'Registration failed', isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Complete Your Profile'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () async {
            final confirm = await Helpers.showConfirmDialog(
              context,
              title: 'Cancel Registration',
              message: 'Are you sure you want to cancel?',
            );
            if (confirm == true && mounted) {
              await context.read<AuthProvider>().signOut();
              Navigator.pushReplacementNamed(context, AppRoutes.roleSelection);
            }
          },
        ),
      ),
      body: Consumer<EmployeeProvider>(
        builder: (context, provider, child) {
          return LoadingOverlay(
            isLoading: provider.isLoading,
            child: Form(
              key: _formKey,
              child: Stepper(
                currentStep: _currentStep,
                onStepContinue: () {
                  if (_currentStep < 3) {
                    setState(() => _currentStep++);
                  } else {
                    _submitRegistration();
                  }
                },
                onStepCancel: () {
                  if (_currentStep > 0) {
                    setState(() => _currentStep--);
                  }
                },
                controlsBuilder: (context, details) {
                  return Padding(
                    padding: const EdgeInsets.only(top: 16),
                    child: Row(
                      children: [
                        Expanded(
                          child: GradientButton(
                            text: _currentStep == 3
                                ? 'Submit'
                                : 'Continue',
                            onPressed: details.onStepContinue,
                            isLoading: provider.isLoading,
                          ),
                        ),
                        if (_currentStep > 0) ...[
                          const SizedBox(width: 12),
                          Expanded(
                            child: CustomButton(
                              text: 'Back',
                              onPressed: details.onStepCancel,
                              isOutlined: true,
                            ),
                          ),
                        ],
                      ],
                    ),
                  );
                },
                steps: [
                  Step(
                    title: const Text('Personal Info'),
                    content: _buildPersonalInfoStep(),
                    isActive: _currentStep >= 0,
                    state: _currentStep > 0 ? StepState.complete : StepState.indexed,
                  ),
                  Step(
                    title: const Text('Service Details'),
                    content: _buildServiceDetailsStep(),
                    isActive: _currentStep >= 1,
                    state: _currentStep > 1 ? StepState.complete : StepState.indexed,
                  ),
                  Step(
                    title: const Text('Verification'),
                    content: _buildVerificationStep(),
                    isActive: _currentStep >= 2,
                    state: _currentStep > 2 ? StepState.complete : StepState.indexed,
                  ),
                  Step(
                    title: const Text('Profile Photo'),
                    content: _buildProfilePhotoStep(),
                    isActive: _currentStep >= 3,
                    state: _currentStep > 3 ? StepState.complete : StepState.indexed,
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildPersonalInfoStep() {
    return Column(
      children: [
        CustomTextField(
          label: 'Full Name',
          controller: _nameController,
          prefixIcon: Icons.person_outline,
          validator: (value) => Validators.required(value, 'Name'),
        ),
        const SizedBox(height: 16),
        CustomTextField(
          label: 'Email',
          controller: _emailController,
          keyboardType: TextInputType.emailAddress,
          prefixIcon: Icons.email_outlined,
          enabled: false,
        ),
        const SizedBox(height: 16),
        CustomTextField(
          label: 'Phone Number',
          controller: _phoneController,
          keyboardType: TextInputType.phone,
          prefixIcon: Icons.phone_outlined,
          validator: Validators.phone,
        ),
        const SizedBox(height: 16),
        CustomTextField(
          label: 'Address',
          controller: _addressController,
          maxLines: 2,
          prefixIcon: Icons.location_on_outlined,
          validator: (value) => Validators.required(value, 'Address'),
        ),
      ],
    );
  }

  Widget _buildServiceDetailsStep() {
    final categories = ServiceCategories.all;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Service Category',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w500,
              ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: categories.map((category) {
            final isSelected = _selectedCategory == category.id;
            return FilterChip(
              selected: isSelected,
              label: Text(category.name),
              onSelected: (_) {
                setState(() => _selectedCategory = category.id);
              },
            );
          }).toList(),
        ),
        const SizedBox(height: 16),
        CustomTextField(
          label: 'Service Description',
          hint: 'Describe your services in detail...',
          controller: _serviceDetailsController,
          maxLines: 3,
          validator: (value) => Validators.required(value, 'Service description'),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: CustomTextField(
                label: 'Years of Experience',
                controller: _experienceController,
                keyboardType: TextInputType.number,
                prefixIcon: Icons.work_outline,
                validator: (value) => Validators.required(value, 'Experience'),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: CustomTextField(
                label: 'Hourly Rate (₹)',
                controller: _hourlyRateController,
                keyboardType: TextInputType.number,
                prefixIcon: Icons.currency_rupee,
                validator: (value) => Validators.required(value, 'Rate'),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildVerificationStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Certificates (images or PDF)',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w500,
              ),
        ),
        const SizedBox(height: 8),
        ..._documents.asMap().entries.map((entry) {
          final index = entry.key;
          final file = entry.value;
          return Card(
            margin: const EdgeInsets.only(bottom: 8),
            child: ListTile(
              leading: Icon(
                file.extension?.toLowerCase() == 'pdf'
                    ? Icons.picture_as_pdf_outlined
                    : Icons.image_outlined,
                color: AppColors.primary,
              ),
              title: Text(
                file.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              trailing: IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => _removeDocument(index),
              ),
            ),
          );
        }),
        OutlinedButton.icon(
          onPressed: _pickDocuments,
          icon: const Icon(Icons.upload_file_outlined),
          label: const Text('Add certificate'),
        ),
        const SizedBox(height: 24),
        Text(
          'Introduction video (optional)',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w500,
              ),
        ),
        const SizedBox(height: 8),
        if (_video != null)
          Card(
            margin: const EdgeInsets.only(bottom: 8),
            child: ListTile(
              leading: const Icon(Icons.videocam_outlined, color: AppColors.primary),
              title: Text(
                _video!.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              trailing: IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => setState(() => _video = null),
              ),
            ),
          ),
        OutlinedButton.icon(
          onPressed: _pickVideo,
          icon: const Icon(Icons.video_call_outlined),
          label: Text(_video == null ? 'Add video' : 'Replace video'),
        ),
        const SizedBox(height: 24),
        Card(
          color: AppColors.info.withOpacity(0.1),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                const Icon(Icons.info_outline, color: AppColors.info),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'At least one certificate or a video is required. An admin will review these before your profile appears to customers.',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppColors.info,
                        ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildProfilePhotoStep() {
    return Column(
      children: [
        GestureDetector(
          onTap: _pickImage,
          child: Container(
            width: 150,
            height: 150,
            decoration: BoxDecoration(
              color: AppColors.grey100,
              shape: BoxShape.circle,
              image: _profileImageBytes != null
                  ? DecorationImage(
                      image: MemoryImage(_profileImageBytes!),
                      fit: BoxFit.cover,
                    )
                  : null,
            ),
            child: _profileImageBytes == null
                ? Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.camera_alt,
                        size: 40,
                        color: AppColors.grey500,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Add Photo',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: AppColors.grey500,
                            ),
                      ),
                    ],
                  )
                : null,
          ),
        ),
        const SizedBox(height: 16),
        Text(
          'Profile photo is optional',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: AppColors.grey600,
              ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 24),
        Card(
          color: AppColors.info.withOpacity(0.1),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                const Icon(Icons.info_outline, color: AppColors.info),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'A clear profile photo helps build trust with customers',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppColors.info,
                        ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
