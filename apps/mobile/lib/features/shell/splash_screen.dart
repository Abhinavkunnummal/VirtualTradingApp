import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../shared/widgets/tradeverse_logo.dart';

class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const TradeVerseLogo(size: 72),
                const SizedBox(height: 20),
                Text(
                  'TradeVerse AI',
                  style: AppTypography.displaySm,
                ),
                const SizedBox(height: 6),
                Text(
                  'Institutional-Grade Paper Trading Simulator',
                  style: AppTypography.bodyMd.copyWith(color: AppColors.outline),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 36),
                const SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    color: AppColors.primaryBrand,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
