import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';

class DemoModeBanner extends StatelessWidget {
  final VoidCallback? onLoginTap;

  const DemoModeBanner({super.key, this.onLoginTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: const BoxDecoration(
        color: AppColors.surfaceLowest,
        border: Border(
          bottom: BorderSide(color: AppColors.borderSubtle),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: AppColors.warning.withOpacity(0.15),
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: AppColors.warning.withOpacity(0.3)),
            ),
            child: Text(
              'DEMO MODE',
              style: AppTypography.labelSm.copyWith(
                fontSize: 9,
                color: AppColors.warning,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Fictional simulated prices • No live orders placed',
              style: AppTypography.labelSm.copyWith(fontSize: 10, color: AppColors.onSurfaceVariant),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (onLoginTap != null)
            GestureDetector(
              onTap: onLoginTap,
              child: Text(
                'Log in',
                style: AppTypography.labelSm.copyWith(
                  fontSize: 10,
                  color: AppColors.primary,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
