import 'package:flutter/material.dart';

import '../../theme/theme.dart';
import 'linear_progress.dart';

/// A labelled XP/streak bar - a star, "12 / 20 XP" (or similar), and the
/// bar itself. Thin wrapper around [LinearProgressBar] themed in the
/// brand's accent (warm yellow) colour, since XP/streak framing is meant to
/// feel like a small reward, not a neutral status indicator.
class XpProgress extends StatelessWidget {
  const XpProgress({
    super.key,
    required this.value,
    required this.label,
    this.color = AppColors.accent,
  });

  /// 0.0-1.0.
  final double value;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.star_rounded, color: AppColors.accent, size: 18),
            const SizedBox(width: AppSpacing.xs),
            Text(label, style: AppTypography.caption),
          ],
        ),
        const SizedBox(height: AppSpacing.xs),
        LinearProgressBar(value: value, color: color),
      ],
    );
  }
}
