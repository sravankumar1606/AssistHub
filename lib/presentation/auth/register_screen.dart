import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:assisthub/providers/core/constants/app_colors.dart';
import 'package:assisthub/providers/core/constants/app_routes.dart';
import 'package:assisthub/providers/core/constants/app_strings.dart';
import 'package:assisthub/providers/core/utils/validators.dart';
import 'package:assisthub/providers/core/utils/helpers.dart';
import 'package:assisthub/providers/core/widgets/custom_button.dart';
import 'package:assisthub/providers/core/widgets/custom_text_field.dart';
import 'package:assisthub/data/models/user_model.dart';
import 'package:assisthub/providers/auth_provider.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _phoneController = TextEditingController();
  final _otpController = TextEditingController();
  bool _isLoading = false;
  bool _usePhoneAuth = false;
  bool _otpSent = false;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _phoneController.dispose();
    _otpController.dispose();
    super.dispose();
  }

  Future<void> _signUp() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    final authProvider = context.read<AuthProvider>();
    final success = await authProvider.signUpWithEmail(
      _emailController.text.trim(),
      _passwordController.text,
      _nameController.text.trim(),
    );

    if (!mounted) return;
    setState(() => _isLoading = false);

    if (success) {
      // Show verification message instead of navigating
      Helpers.showSnackBar(
        context,
        'Account created! Please verify your email before logging in.',
      );
      // Clear fields so user can't resubmit
      _emailController.clear();
      _passwordController.clear();
      _confirmPasswordController.clear();
      _nameController.clear();
      // Go to login screen
      Navigator.pushReplacementNamed(context, AppRoutes.login);
    } else {
      // Show error and keep fields editable
      final error = authProvider.error ?? 'Registration failed. Please try again.';
      Helpers.showSnackBar(context, error, isError: true);
      // Re-enable form by resetting validation
      _formKey.currentState?.reset();
    }
  }

  Future<void> _sendOtp() async {
    if (_nameController.text.trim().isEmpty) {
      Helpers.showSnackBar(context, 'Enter your full name', isError: true);
      return;
    }
    if (_phoneController.text.trim().isEmpty) {
      Helpers.showSnackBar(context, 'Enter your phone number', isError: true);
      return;
    }

    setState(() => _isLoading = true);
    final authProvider = context.read<AuthProvider>();
    final sent = await authProvider.sendPhoneOtp(_phoneController.text.trim());
    setState(() {
      _isLoading = false;
      _otpSent = sent;
    });

    if (!mounted) return;
    if (sent) {
      Helpers.showSnackBar(context, 'OTP sent');
    } else if (authProvider.error != null) {
      Helpers.showSnackBar(context, authProvider.error!, isError: true);
    }
  }

  Future<void> _signUpWithOtp() async {
    if (_nameController.text.trim().isEmpty) {
      Helpers.showSnackBar(context, 'Enter your full name', isError: true);
      return;
    }
    if (_otpController.text.trim().length < 6) {
      Helpers.showSnackBar(context, 'Enter the 6 digit OTP', isError: true);
      return;
    }

    setState(() => _isLoading = true);
    final authProvider = context.read<AuthProvider>();
    final success = await authProvider.signUpWithPhoneOtp(
      _phoneController.text.trim(),
      _nameController.text.trim(),
      _otpController.text.trim(),
    );
    setState(() => _isLoading = false);

    if (success && mounted) {
      if (authProvider.user?.role == UserRole.customer) {
        Navigator.pushReplacementNamed(context, AppRoutes.customerMain);
      } else {
        Navigator.pushReplacementNamed(context, AppRoutes.employeeRegistration);
      }
    } else if (mounted && authProvider.error != null) {
      Helpers.showSnackBar(context, authProvider.error!, isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  AppStrings.createAccount,
                  style: Theme.of(context).textTheme.displaySmall,
                ),
                const SizedBox(height: 8),
                Text(
                  'Fill in your details to get started',
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: AppColors.grey600,
                      ),
                ),
                const SizedBox(height: 32),
                CustomTextField(
                  label: AppStrings.name,
                  hint: 'Enter your full name',
                  controller: _nameController,
                  prefixIcon: Icons.person_outline,
                  textCapitalization: TextCapitalization.words,
                  validator: (value) => Validators.required(value, 'Name'),
                ),
                const SizedBox(height: 16),
                _buildAuthFields(),
                const SizedBox(height: 32),
                GradientButton(
                  text: _usePhoneAuth
                      ? (_otpSent ? 'Verify OTP & Sign Up' : 'Send OTP')
                      : AppStrings.signUp,
                  onPressed: _usePhoneAuth
                      ? (_otpSent ? _signUpWithOtp : _sendOtp)
                      : _signUp,
                  isLoading: _isLoading,
                ),
                TextButton(
                  onPressed: _isLoading
                      ? null
                      : () {
                          setState(() {
                            _usePhoneAuth = !_usePhoneAuth;
                            _otpSent = false;
                            _otpController.clear();
                          });
                        },
                  child: Text(
                    _usePhoneAuth
                        ? 'Sign up with email instead'
                        : 'Sign up with phone OTP',
                  ),
                ),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      AppStrings.alreadyHaveAccount,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    TextButton(
                      onPressed: () {
                        Navigator.pushReplacementNamed(context, AppRoutes.login);
                      },
                      child: const Text(AppStrings.signIn),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAuthFields() {
    if (_usePhoneAuth) {
      return Column(
        children: [
          CustomTextField(
            label: 'Phone Number',
            hint: '+91 9876543210',
            controller: _phoneController,
            keyboardType: TextInputType.phone,
            prefixIcon: Icons.phone_outlined,
            enabled: !_otpSent,
          ),
          if (_otpSent) ...[
            const SizedBox(height: 16),
            CustomTextField(
              label: 'OTP',
              hint: 'Enter 6 digit code',
              controller: _otpController,
              keyboardType: TextInputType.number,
              maxLength: 6,
              prefixIcon: Icons.sms_outlined,
            ),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: _isLoading ? null : _sendOtp,
                child: const Text('Resend OTP'),
              ),
            ),
          ],
        ],
      );
    }

    return Column(
      children: [
        CustomTextField(
          label: AppStrings.email,
          hint: 'Enter your email',
          controller: _emailController,
          keyboardType: TextInputType.emailAddress,
          prefixIcon: Icons.email_outlined,
          validator: Validators.email,
        ),
        const SizedBox(height: 16),
        CustomTextField(
          label: AppStrings.password,
          hint: 'Create a password',
          controller: _passwordController,
          obscureText: true,
          prefixIcon: Icons.lock_outline,
          validator: Validators.password,
        ),
        const SizedBox(height: 16),
        CustomTextField(
          label: AppStrings.confirmPassword,
          hint: 'Confirm your password',
          controller: _confirmPasswordController,
          obscureText: true,
          prefixIcon: Icons.lock_outline,
          validator: (value) => Validators.confirmPassword(
            value,
            _passwordController.text,
          ),
        ),
      ],
    );
  }
}
