import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';

class ErrorStateWidget extends StatelessWidget {
  final String title;
  final String message;
  final VoidCallback? onRetry;

  const ErrorStateWidget({
    super.key,
    this.title = 'Unable to Load Data',
    this.message = 'Network connection failed or server is unreachable.',
    this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.errorContainer.withOpacity(0.2),
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.errorContainer),
              ),
              child: const Icon(Icons.cloud_off_rounded, size: 36, color: AppColors.error),
            ),
            const SizedBox(height: 16),
            Text(title, style: AppTypography.headlineSm),
            const SizedBox(height: 6),
            Text(
              message,
              textAlign: TextAlign.center,
              style: AppTypography.bodyMd.copyWith(color: AppColors.outline),
            ),
            if (onRetry != null) ...[
              const SizedBox(height: 20),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.surfaceContainer,
                  foregroundColor: AppColors.primary,
                  side: const BorderSide(color: AppColors.primaryBrand),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                onPressed: onRetry,
                icon: const Icon(Icons.refresh, size: 18),
                label: Text('Retry Connection', style: AppTypography.labelMd.copyWith(color: AppColors.primary)),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
