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
      child: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.errorContainer.withOpacity(0.2),
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.errorContainer),
              ),
              child: const Icon(Icons.cloud_off_rounded, size: 28, color: AppColors.error),
            ),
            const SizedBox(height: 10),
            Text(
              title,
              style: AppTypography.headlineSm.copyWith(fontSize: 15),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 4),
            Text(
              message,
              textAlign: TextAlign.center,
              style: AppTypography.bodyMd.copyWith(color: AppColors.outline, fontSize: 12),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
            if (onRetry != null) ...[
              const SizedBox(height: 12),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.surfaceContainer,
                  foregroundColor: AppColors.primary,
                  side: const BorderSide(color: AppColors.primaryBrand),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  visualDensity: VisualDensity.compact,
                ),
                onPressed: onRetry,
                icon: const Icon(Icons.refresh, size: 16),
                label: Text('Retry Connection', style: AppTypography.labelMd.copyWith(color: AppColors.primary, fontSize: 12)),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
