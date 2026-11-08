import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

/// Animated skeleton placeholder with shimmer effect.
/// Use as a loading-state placeholder for list items.
class SkeletonLoader extends StatefulWidget {
  final double width;
  final double height;
  final double borderRadius;

  const SkeletonLoader({
    super.key,
    this.width = double.infinity,
    this.height = 16,
    this.borderRadius = 8,
  });

  @override
  State<SkeletonLoader> createState() => _SkeletonLoaderState();
}

class _SkeletonLoaderState extends State<SkeletonLoader>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();
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
        final dx = _controller.value * 2 - 0.5;
        return Container(
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(widget.borderRadius),
            gradient: LinearGradient(
              begin: Alignment(-1.0 + dx, 0),
              end: Alignment(0.5 + dx, 0),
              colors: const [
                Color(0xFF1E1E2E),
                Color(0xFF2A2A3E),
                Color(0xFF1E1E2E),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// Shows [count] skeleton rows that mimic a typical list tile layout.
/// Each row has a circular avatar, two text bars, and a trailing bar.
class SkeletonList extends StatelessWidget {
  final int count;

  const SkeletonList({super.key, this.count = 6});

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      itemCount: count,
      physics: const NeverScrollableScrollPhysics(),
      itemBuilder: (context, index) {
        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: context.cardBg,
            borderRadius: BorderRadius.circular(14),
          ),
          child: const Row(
            children: [
              // Avatar placeholder
              SkeletonLoader(width: 48, height: 48, borderRadius: 14),
              SizedBox(width: 14),
              // Text bars
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SkeletonLoader(width: 140, height: 14, borderRadius: 6),
                    SizedBox(height: 8),
                    SkeletonLoader(width: 90, height: 10, borderRadius: 6),
                  ],
                ),
              ),
              SizedBox(width: 12),
              // Trailing badge
              SkeletonLoader(width: 56, height: 22, borderRadius: 6),
            ],
          ),
        );
      },
    );
  }
}
