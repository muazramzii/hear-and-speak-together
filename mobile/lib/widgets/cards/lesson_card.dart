import 'package:flutter/material.dart';

import '../../theme/theme.dart';
import '../progress/circular_score.dart';
import 'app_card.dart';

/// One lesson, as a reusable list/grid tile - a thumbnail badge, title,
/// subtitle (typically a word count), and a small completion ring. Locked
/// lessons dim and swap the badge for a lock icon rather than disappearing,
/// so a child can always see what's ahead.
class LessonCard extends StatelessWidget {
  const LessonCard({
    super.key,
    required this.title,
    required this.subtitle,
    this.icon = Icons.menu_book_rounded,
    this.progress = 0,
    this.isLocked = false,
    this.isCompleted = false,
    this.onTap,
  });

  final String title;
  final String subtitle;
  final IconData icon;

  /// 0.0-1.0. Ignored (shown empty) when [isLocked].
  final double progress;
  final bool isLocked;
  final bool isCompleted;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final gradient =
        isLocked
            ? const LinearGradient(colors: [AppColors.border, AppColors.border])
            : (isCompleted ? AppGradients.success : AppGradients.primary);
    final badgeColor = AppA11y.textColorFor(gradient.colors.last);

    return AppCard(
      onTap: isLocked ? null : onTap,
      child: Row(
        children: [
          CircularScore(
            value: isLocked ? 0 : progress,
            size: 56,
            strokeWidth: 5,
            color: isCompleted ? AppColors.successStrong : AppColors.accent,
            child: Container(
              height: 40,
              width: 40,
              decoration: BoxDecoration(
                gradient: gradient,
                shape: BoxShape.circle,
              ),
              child: Icon(
                isLocked
                    ? Icons.lock_rounded
                    : (isCompleted ? Icons.check_rounded : icon),
                color: badgeColor,
                size: 20,
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: AppTypography.h3.copyWith(
                    fontSize: 17,
                    color:
                        isLocked
                            ? AppColors.textSecondary
                            : AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(subtitle, style: AppTypography.caption),
              ],
            ),
          ),
          Icon(
            isLocked ? Icons.lock_outline_rounded : Icons.chevron_right_rounded,
            color: AppColors.textSecondary,
          ),
        ],
      ),
    );
  }
}
