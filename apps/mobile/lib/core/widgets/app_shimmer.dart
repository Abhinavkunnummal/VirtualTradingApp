import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

/// Pure Flutter 60fps linear animated gradient shimmer loader.
class AppShimmer extends StatefulWidget {
  final Widget child;
  final Color baseColor;
  final Color highlightColor;
  final Duration duration;

  const AppShimmer({
    super.key,
    required this.child,
    this.baseColor = AppColors.shimmerBase,
    this.highlightColor = AppColors.shimmerHighlight,
    this.duration = const Duration(milliseconds: 1500),
  });

  @override
  State<AppShimmer> createState() => _AppShimmerState();
}

class _AppShimmerState extends State<AppShimmer> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: widget.duration)
      ..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return ShaderMask(
          blendMode: BlendMode.srcATop,
          shaderCallback: (bounds) {
            return LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                widget.baseColor,
                widget.highlightColor,
                widget.baseColor,
              ],
              stops: const [0.0, 0.5, 1.0],
              transform: _SlidingGradientTransform(slidePercent: _controller.value),
            ).createShader(bounds);
          },
          child: child,
        );
      },
      child: widget.child,
    );
  }
}

class _SlidingGradientTransform extends GradientTransform {
  final double slidePercent;
  const _SlidingGradientTransform({required this.slidePercent});

  @override
  Matrix4? transform(Rect bounds, {TextDirection? textDirection}) {
    return Matrix4.translationValues(bounds.width * (slidePercent * 2 - 1), 0.0, 0.0);
  }
}

/// Rounded skeleton box placeholder
class SkeletonBox extends StatelessWidget {
  final double? width;
  final double height;
  final double borderRadius;

  const SkeletonBox({
    super.key,
    this.width,
    required this.height,
    this.borderRadius = 8,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: AppColors.shimmerBase,
        borderRadius: BorderRadius.circular(borderRadius),
      ),
    );
  }
}

/// Shimmer skeleton for Watchlist / Market tiles
class WatchlistSkeleton extends StatelessWidget {
  final int count;
  const WatchlistSkeleton({super.key, this.count = 5});

  @override
  Widget build(BuildContext context) {
    return AppShimmer(
      child: ListView.separated(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: count,
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (context, index) {
          return Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.surfaceContainer,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.borderSubtle),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: const [
                          SkeletonBox(width: 80, height: 16),
                          SizedBox(width: 8),
                          SkeletonBox(width: 40, height: 14, borderRadius: 4),
                        ],
                      ),
                      const SizedBox(height: 8),
                      const SkeletonBox(width: 140, height: 12),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: const [
                    SkeletonBox(width: 70, height: 16),
                    SizedBox(height: 6),
                    SkeletonBox(width: 55, height: 16, borderRadius: 4),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

/// Shimmer skeleton for Holdings / Portfolio cards
class HoldingsSkeleton extends StatelessWidget {
  final int count;
  const HoldingsSkeleton({super.key, this.count = 3});

  @override
  Widget build(BuildContext context) {
    return AppShimmer(
      child: ListView.separated(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: count,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          return Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.surfaceContainer,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.borderSubtle),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: const [
                    SkeletonBox(width: 90, height: 16),
                    SkeletonBox(width: 80, height: 16),
                  ],
                ),
                const SizedBox(height: 14),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: const [
                    SkeletonBox(width: 110, height: 14),
                    SkeletonBox(width: 95, height: 14),
                  ],
                ),
                const SizedBox(height: 10),
                const Divider(color: AppColors.borderSubtle),
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: const [
                    SkeletonBox(width: 70, height: 14),
                    SkeletonBox(width: 60, height: 18, borderRadius: 4),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

/// Shimmer skeleton for Orders list
class OrdersSkeleton extends StatelessWidget {
  final int count;
  const OrdersSkeleton({super.key, this.count = 4});

  @override
  Widget build(BuildContext context) {
    return AppShimmer(
      child: ListView.separated(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: count,
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (context, index) {
          return Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.surfaceContainer,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.borderSubtle),
            ),
            child: Row(
              children: [
                const SkeletonBox(width: 50, height: 22, borderRadius: 6),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      SkeletonBox(width: 85, height: 16),
                      SizedBox(height: 6),
                      SkeletonBox(width: 120, height: 12),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: const [
                    SkeletonBox(width: 65, height: 16),
                    SizedBox(height: 6),
                    SkeletonBox(width: 45, height: 12),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

/// Shimmer skeleton for Chart view
class ChartSkeleton extends StatelessWidget {
  const ChartSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return AppShimmer(
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.surfaceContainer,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.borderSubtle),
        ),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: const [
                SkeletonBox(width: 110, height: 24),
                SkeletonBox(width: 75, height: 20, borderRadius: 4),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: List.generate(
                5,
                (i) => const Padding(
                  padding: EdgeInsets.only(right: 8),
                  child: SkeletonBox(width: 38, height: 24, borderRadius: 6),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: AppColors.shimmerBase,
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
