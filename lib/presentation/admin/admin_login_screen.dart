import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:assisthub/providers/core/constants/app_colors.dart';
import 'package:assisthub/providers/core/utils/helpers.dart';
import 'package:assisthub/providers/core/widgets/custom_button.dart';
import 'package:assisthub/providers/core/widgets/custom_text_field.dart';
import 'package:assisthub/providers/auth_provider.dart';
import 'package:assisthub/presentation/admin/admin_shell_screen.dart';

/// Standalone admin sign-in. Admin accounts are created manually in
/// Firebase Authentication + a matching Firestore users doc with
/// role: 'admin' — there is no self-registration path for this role.
class AdminLoginScreen extends StatefulWidget {
  const AdminLoginScreen({super.key});

  @override
  State<AdminLoginScreen> createState() => _AdminLoginScreenState();
}

class _AdminLoginScreenState extends State<AdminLoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    final authProvider = context.read<AuthProvider>();

    final success = await authProvider.signInAdmin(
      _emailController.text.trim(),
      _passwordController.text,
    );

    if (!mounted) return;
    setState(() => _isLoading = false);

    if (!success) {
      Helpers.showSnackBar(
        context,
        authProvider.error ?? 'Login failed',
        isError: true,
      );
      return;
    }

    if (!mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const AdminShellScreen()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.grey900,
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 400),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.admin_panel_settings_outlined,
                    size: 56,
                    color: AppColors.white,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Admin Access',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          color: AppColors.white,
                        ),
                  ),
                  const SizedBox(height: 32),
                  CustomTextField(
                    label: 'Email',
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    prefixIcon: Icons.email_outlined,
                    validator: (value) =>
                        (value == null || value.trim().isEmpty) ? 'Enter email' : null,
                  ),
                  const SizedBox(height: 16),
                  CustomTextField(
                    label: 'Password',
                    controller: _passwordController,
                    obscureText: true,
                    prefixIcon: Icons.lock_outline,
                    validator: (value) =>
                        (value == null || value.isEmpty) ? 'Enter password' : null,
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: GradientButton(
                      text: 'Sign In',
                      onPressed: _login,
                      isLoading: _isLoading,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
