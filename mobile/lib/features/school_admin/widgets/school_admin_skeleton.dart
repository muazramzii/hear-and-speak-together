import 'package:flutter/material.dart';

import '../../parent/design/parent_theme.dart';

/// A pulsing placeholder block, shown in place of real content while an
/// analytics request is in flight - built with a plain `TweenAnimationBuilder`
/// loop rather than a new dependency, matching every other animation in
/// this design system (see `HeatBar`/`CircularScore`).
class SkeletonBox extends StatefulWidget {
  const SkeletonBox({
    super.key,
    this.width,
    this.height = 16,
    this.borderRadius = 8,
  });

  final double? width;
  final double height;
  final double borderRadius;

  @override
  State<SkeletonBox> createState() => _SkeletonBoxState();
}

class _SkeletonBoxState extends State<SkeletonBox>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.parentColors;

    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          return Container(
            width: widget.width,
            height: widget.height,
            decoration: BoxDecoration(
              color: Color.lerp(
                palette.surfaceAlt,
                palette.border,
                _controller.value,
              ),
              borderRadius: BorderRadius.circular(widget.borderRadius),
            ),
          );
        },
      ),
    );
  }
}

/// The Dashboard's loading placeholder: the same card layout the real
/// content will occupy, so the page doesn't visibly jump once data
/// arrives.
class SchoolAdminDashboardSkeleton extends StatelessWidget {
  const SchoolAdminDashboardSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      physics: const NeverScrollableScrollPhysics(),
      children: [
        const SkeletonBox(width: 160, height: 24),
        const SizedBox(height: 20),
        Row(
          children: List.generate(
            3,
            (index) => Expanded(
              child: Padding(
                padding: EdgeInsets.only(right: index < 2 ? 12 : 0),
                child: const SkeletonBox(height: 80, borderRadius: 16),
              ),
            ),
          ),
        ),
        const SizedBox(height: 20),
        const SkeletonBox(height: 100, borderRadius: 16),
        const SizedBox(height: 20),
        const SkeletonBox(width: 140, height: 20),
        const SizedBox(height: 12),
        const SkeletonBox(height: 160, borderRadius: 16),
      ],
    );
  }
}
