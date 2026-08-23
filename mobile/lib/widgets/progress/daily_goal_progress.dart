import 'package:flutter/material.dart';

import '../../theme/theme.dart';
import 'circular_score.dart';

/// A small ring showing progress toward today's practice goal (e.g. "3 of 5
/// words practised today"), with a flag icon at its centre so it reads as
/// "today's target" at a glance rather than being confused with the
/// pronunciation `CircularScore`, which it otherwise shares its painter
/// with.
class DailyGoalProgress extends StatelessWidget {
  const DailyGoalProgress({
    super.key,
    required this.value,
    required this.completed,
    required this.total,
    this.size = 88,
  });

  /// 0.0-1.0.
  final double value;
  final int completed;
  final int total;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        CircularScore(
          value: value,
          size: size,
          strokeWidth: 8,
          color: AppColors.successStrong,
          duration: AppMotion.medium,
          child: Icon(
            Icons.flag_rounded,
            color: AppColors.successStrong,
            size: size * 0.32,
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        Text('$completed / $total', style: AppTypography.caption),
      ],
    );
  }
}
