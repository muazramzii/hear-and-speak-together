import 'package:flutter/material.dart';

import '../../theme/theme.dart';
import 'app_card.dart';

/// One badge, earned or still locked. Locked badges are shown dimmed rather
/// than hidden - seeing what is still ahead is the point of a rewards
/// screen. `emoji` comes from seeded achievement content (the backend's
/// `Achievement.icon`), which is content, not UI chrome - the app's
/// "emoji only inside learning content" rule allows it here the same way it
/// allows a word's illustration emoji.
class AchievementCard extends StatelessWidget {
  const AchievementCard({
    super.key,
    required this.emoji,
    required this.name,
    required this.description,
    required this.earned,
  });

  final String emoji;
  final String name;
  final String description;
  final bool earned;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: earned ? 1.0 : 0.5,
      child: AppCard(
        color: earned ? AppColors.amberSoft : AppColors.surfaceVariant,
        child: Column(
          children: [
            Text(
              emoji.isEmpty ? '🏅' : emoji,
              style: const TextStyle(fontSize: 40),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              name,
              textAlign: TextAlign.center,
              style: AppTypography.h3.copyWith(fontSize: 16),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              description,
              textAlign: TextAlign.center,
              style: AppTypography.caption,
            ),
            if (!earned) ...[
              const SizedBox(height: AppSpacing.sm),
              const Icon(
                Icons.lock_outline_rounded,
                color: AppColors.textSecondary,
                size: 18,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
