import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:assisthub/providers/core/constants/app_colors.dart';
import 'package:assisthub/providers/core/constants/app_routes.dart';
import 'package:assisthub/providers/core/constants/app_strings.dart';
import 'package:assisthub/data/models/user_model.dart';
import 'package:assisthub/providers/auth_provider.dart';
import 'package:assisthub/providers/employee_provider.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeIn),
    );

    _scaleAnimation = Tween<double>(begin: 0.5, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.elasticOut),
    );

    _controller.forward();
    _checkAuthState();
  }

  Future<void> _checkAuthState() async {
    await Future.delayed(const Duration(seconds: 2));

    if (!mounted) return;

    final authProvider = context.read<AuthProvider>();

    // Wait for Firebase to restore session (max 5 seconds)
    int waited = 0;
    while (authProvider.isLoading && waited < 10) {
      await Future.delayed(const Duration(milliseconds: 500));
      waited++;
    }

    if (!mounted) return;

    if (authProvider.isAuthenticated && authProvider.user != null) {
      final user = authProvider.user!;

      // Dual role — show role picker
      if (authProvider.isDualRole) {
        Navigator.pushReplacementNamed(context, AppRoutes.rolePicker);
        return;
      }

      if (user.role == UserRole.customer) {
        Navigator.pushReplacementNamed(context, AppRoutes.customerMain);
      } else {
        final employeeProvider = context.read<EmployeeProvider>();
        await employeeProvider.loadCurrentEmployee(user.id);

        if (!mounted) return;

        if (employeeProvider.currentEmployee != null) {
          Navigator.pushReplacementNamed(context, AppRoutes.employeeMain);
        } else {
          Navigator.pushReplacementNamed(context, AppRoutes.employeeRegistration);
        }
      }
    } else {
      Navigator.pushReplacementNamed(context, AppRoutes.roleSelection);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: AppColors.primaryGradient,
        ),
        child: Center(
          child: FadeTransition(
            opacity: _fadeAnimation,
            child: ScaleTransition(
              scale: _scaleAnimation,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: AppColors.white.withOpacity(0.2),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.handyman,
                      size: 80,
                      color: AppColors.white,
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    AppStrings.appName,
                    style: Theme.of(context).textTheme.displayMedium?.copyWith(
                          color: AppColors.white,
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    AppStrings.appTagline,
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          color: AppColors.white.withOpacity(0.8),
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
