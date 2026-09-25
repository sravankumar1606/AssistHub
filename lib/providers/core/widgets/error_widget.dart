import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../constants/app_strings.dart';
import 'custom_button.dart';

class CustomErrorWidget extends StatelessWidget {
  final String? message;
  final VoidCallback? onRetry;
  final IconData icon;

  const CustomErrorWidget({
    super.key,
    this.message,
    this.onRetry,
    this.icon = Icons.error_outline,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 80,
              color: AppColors.error.withOpacity(0.5),
            ),
            const SizedBox(height: 16),
            Text(
              message ?? AppStrings.somethingWentWrong,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: AppColors.grey600,
                  ),
            ),
            if (onRetry != null) ...[
              const SizedBox(height: 24),
              CustomButton(
                text: AppStrings.tryAgain,
                onPressed: onRetry,
                icon: Icons.refresh,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class NoInternetWidget extends StatelessWidget {
  final VoidCallback? onRetry;

  const NoInternetWidget({super.key, this.onRetry});

  @override
  Widget build(BuildContext context) {
    return CustomErrorWidget(
      message: AppStrings.noInternetConnection,
      onRetry: onRetry,
      icon: Icons.wifi_off,
    );
  }
}
