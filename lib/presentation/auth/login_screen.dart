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
import 'package:assisthub/providers/employee_provider.dart';
import 'package:assisthub/data/models/employee_model.dart';
import 'package:assisthub/presentation/employee/pending_approval_screen.dart';
import 'package:assisthub/providers/core/widgets/animated_gradient_background.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _phoneController = TextEditingController();
  final _otpController = TextEditingController();
  bool _isLoading = false;
  bool _usePhoneAuth = false;
  bool _otpSent = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _phoneController.dispose();
    _otpController.dispose();
    super.dispose();
  }

  Future<void> _signInWithEmail() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    final authProvider = context.read<AuthProvider>();
    final success = await authProvider.signInWithEmail(
      _emailController.text.trim(),
      _passwordController.text,
    );

    setState(() => _isLoading = false);

    if (success && mounted) {
      await _navigateToHome(authProvider);
    } else if (mounted && authProvider.error != null) {
  if (authProvider.error!.contains('verify')) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(authProvider.error!),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 5),
        action: SnackBarAction(
          label: 'Resend',
          textColor: Colors.white,
          onPressed: () async {
            await authProvider.resendVerificationEmail();
            if (mounted) {
              Helpers.showSnackBar(context, 'Verification email resent!');
            }
          },
        ),
      ),
    );
  } else {
    Helpers.showSnackBar(context, authProvider.error!, isError: true);
  }
}
  }

  Future<void> _signInWithGoogle() async {
    setState(() => _isLoading = true);

    final authProvider = context.read<AuthProvider>();
    final success = await authProvider.signInWithGoogle();

    setState(() => _isLoading = false);

    if (success && mounted) {
      await _navigateToHome(authProvider);
    } else if (mounted && authProvider.error != null) {
      Helpers.showSnackBar(context, authProvider.error!, isError: true);
    }
  }

  Future<void> _sendOtp() async {
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

  Future<void> _signInWithOtp() async {
    if (_otpController.text.trim().length < 6) {
      Helpers.showSnackBar(context, 'Enter the 6 digit OTP', isError: true);
      return;
    }

    setState(() => _isLoading = true);
    final authProvider = context.read<AuthProvider>();
    final success = await authProvider.signInWithPhoneOtp(
      _otpController.text.trim(),
    );
    setState(() => _isLoading = false);

    if (success && mounted) {
      await _navigateToHome(authProvider);
    } else if (mounted && authProvider.error != null) {
      Helpers.showSnackBar(context, authProvider.error!, isError: true);
    }
  }

  Future<void> _navigateToHome(AuthProvider authProvider) async {
    // Show role picker if user has both roles
    if (authProvider.isDualRole) {
      Navigator.pushReplacementNamed(context, AppRoutes.rolePicker);
      return;
    }

    if (authProvider.user?.role == UserRole.customer) {
      Navigator.pushReplacementNamed(context, AppRoutes.customerMain);
    } else {
      final employeeProvider = context.read<EmployeeProvider>();
      await employeeProvider.loadCurrentEmployee(authProvider.user!.id);

      if (!mounted) return;

      final employee = employeeProvider.currentEmployee;
      if (employee == null) {
        Navigator.pushReplacementNamed(context, AppRoutes.employeeRegistration);
      } else if (employee.verificationStatus == VerificationStatus.approved) {
        Navigator.pushReplacementNamed(context, AppRoutes.employeeMain);
      } else {
        // Pending or rejected — show the waiting/resubmit screen instead
        // of letting them into the dashboard.
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const PendingApprovalScreen()),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: AnimatedGradientBackground(
        colors: [
          AppColors.primary.withOpacity(0.12),
          AppColors.primary.withOpacity(0.04),
          Colors.transparent,
        ],
        child: SafeArea(
          child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  AppStrings.welcomeBack,
                  style: Theme.of(context).textTheme.displaySmall,
                ),
                const SizedBox(height: 8),
                Text(
                  'Sign in to continue',
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: AppColors.grey600,
                      ),
                ),
                const SizedBox(height: 32),
                _buildGoogleButton(),
                const SizedBox(height: 24),
                _buildDivider(),
                const SizedBox(height: 24),
                _buildAuthFields(),
                const SizedBox(height: 8),
                if (!_usePhoneAuth)
                  Align(
  alignment: Alignment.centerRight,
  child: TextButton(onPressed: () async {
    final email = _emailController.text.trim();
    if (email.isEmpty) {
      Helpers.showSnackBar(context, 'Enter your email first', isError: true);
      return;
    }
    final authProvider = context.read<AuthProvider>();
    final success = await authProvider.forgotPassword(email);
    if (!mounted) return;
    if (success) {
      Helpers.showSnackBar(context, 'Password reset email sent! Check your inbox.');
    } else {
      Helpers.showSnackBar(context, authProvider.error ?? 'Something went wrong', isError: true);
    }
  },
  child: const Text(AppStrings.forgotPassword),
),
),
                const SizedBox(height: 24),
                GradientButton(
                  text: _usePhoneAuth
                      ? (_otpSent ? 'Verify OTP' : 'Send OTP')
                      : AppStrings.signIn,
                  onPressed: _usePhoneAuth
                      ? (_otpSent ? _signInWithOtp : _sendOtp)
                      : _signInWithEmail,
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
                        ? 'Sign in with email instead'
                        : 'Sign in with phone OTP',
                  ),
                ),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      AppStrings.dontHaveAccount,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    TextButton(
                      onPressed: () {
                        Navigator.pushReplacementNamed(
                          context,
                          AppRoutes.register,
                        );
                      },
                      child: const Text(AppStrings.signUp),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
      ),
    );
  }

  Widget _buildGoogleButton() {
    return CustomButton(
      text: AppStrings.signInWithGoogle,
      onPressed: _signInWithGoogle,
      isOutlined: true,
      prefix: const Icon(Icons.g_mobiledata, size: 24),
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
          hint: 'Enter your password',
          controller: _passwordController,
          obscureText: true,
          prefixIcon: Icons.lock_outline,
          validator: Validators.password,
        ),
      ],
    );
  }

  Widget _buildDivider() {
    return Row(
      children: [
        const Expanded(child: Divider()),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            'or',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppColors.grey500,
                ),
          ),
        ),
        const Expanded(child: Divider()),
      ],
    );
  }
}
