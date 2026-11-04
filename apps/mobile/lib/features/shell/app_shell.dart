import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';

class AppShell extends StatelessWidget {
  final StatefulNavigationShell navigationShell;

  const AppShell({
    super.key,
    required this.navigationShell,
  });

  void _onItemTapped(int index) {
    navigationShell.goBranch(
      index,
      initialLocation: index == navigationShell.currentIndex,
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentIndex = navigationShell.currentIndex;

    return Scaffold(
      body: navigationShell,
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: AppColors.surfaceLow.withOpacity(0.95),
          border: const Border(
            top: BorderSide(color: AppColors.borderSubtle, width: 1.0),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.4),
              blurRadius: 16,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: ClipRect(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
            child: SafeArea(
              top: false,
              child: SizedBox(
                height: 64,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _NavBarItem(
                      icon: Icons.dashboard_outlined,
                      activeIcon: Icons.dashboard,
                      label: 'Home',
                      isActive: currentIndex == 0,
                      onTap: () => _onItemTapped(0),
                    ),
                    _NavBarItem(
                      icon: Icons.trending_up,
                      activeIcon: Icons.trending_up,
                      label: 'Markets',
                      isActive: currentIndex == 1,
                      onTap: () => _onItemTapped(1),
                    ),
                    // Elevated Center Trade Action
                    GestureDetector(
                      onTap: () => _onItemTapped(2),
                      behavior: HitTestBehavior.opaque,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: currentIndex == 2
                                  ? AppColors.primaryBrand
                                  : AppColors.primaryContainer.withOpacity(0.2),
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: currentIndex == 2
                                    ? AppColors.primary
                                    : AppColors.primaryContainer.withOpacity(0.4),
                                width: 1.5,
                              ),
                            ),
                            child: Icon(
                              Icons.swap_horiz_rounded,
                              size: 24,
                              color: currentIndex == 2
                                  ? AppColors.surfaceLowest
                                  : AppColors.primary,
                            ),
                          ),
                          const SizedBox(height: 2),
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              'Trade',
                              style: AppTypography.labelSm.copyWith(
                                fontSize: 10,
                                color: currentIndex == 2
                                    ? AppColors.primary
                                    : AppColors.outline,
                                fontWeight: currentIndex == 2
                                    ? FontWeight.w700
                                    : FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    _NavBarItem(
                      icon: Icons.groups_outlined,
                      activeIcon: Icons.groups,
                      label: 'Community',
                      isActive: currentIndex == 3,
                      onTap: () => _onItemTapped(3),
                    ),
                    _NavBarItem(
                      icon: Icons.pie_chart_outline,
                      activeIcon: Icons.pie_chart,
                      label: 'Portfolio',
                      isActive: currentIndex == 4,
                      onTap: () => _onItemTapped(4),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _NavBarItem extends StatelessWidget {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  final bool isActive;
  final VoidCallback onTap;

  const _NavBarItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: SizedBox(
        width: 60,
        height: 52,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              isActive ? activeIcon : icon,
              size: 22,
              color: isActive ? AppColors.primary : AppColors.outline,
            ),
            const SizedBox(height: 3),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                label,
                style: AppTypography.labelSm.copyWith(
                  fontSize: 10,
                  color: isActive ? AppColors.primary : AppColors.outline,
                  fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
