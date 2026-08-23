import 'package:flutter/material.dart';

import '../../theme/theme.dart';
import 'app_card.dart';

/// A single stat, as a small tinted tile - "Average Score: 87%", "Words
/// Learned: 12". Icon colour must clear AA against `tint`; pass a colour
/// this card can safely put white-adjacent icon glyphs on (any of the
/// `*Strong` tokens, or `primary`/`textPrimary`).
class ProgressCard extends StatelessWidget {
  const ProgressCard({
    super.key,
    required this.value,
    required this.label,
    required this.icon,
    this.tint = AppColors.violetSoft,
    this.accent = AppColors.primary,
  });

  final String value;
  final String label;
  final IconData icon;
  final Color tint;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      color: tint,
      padding: const EdgeInsets.all(AppSpacing.md),
      shadow: AppShadows.none,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Icon(icon, color: accent, size: 22),
          const SizedBox(height: AppSpacing.sm),
          Text(value, style: AppTypography.h2.copyWith(fontSize: 24)),
          Text(label, style: AppTypography.caption),
        ],
      ),
    );
  }
}
