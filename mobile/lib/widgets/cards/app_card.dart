import 'package:flutter/material.dart';

import '../../theme/theme.dart';
import '../buttons/button_base.dart';

/// The base rounded surface every other card in the app builds on - a flat
/// tint fill with a soft, low resting shadow (see `AppShadows.small`)
/// instead of the pre-refactor `CardThemeData`'s hard `AppColors.border`
/// outline. The redesign leans on soft elevation and spacing for
/// separation, not a drawn border around every tile.
class AppCard extends StatelessWidget {
  const AppCard({
    super.key,
    required this.child,
    this.color = AppColors.surface,
    this.padding = const EdgeInsets.all(AppSpacing.lg),
    this.radius = AppRadius.large,
    this.shadow,
    this.onTap,
  });

  final Widget child;
  final Color color;
  final EdgeInsetsGeometry padding;
  final double radius;

  /// Defaults to `AppShadows.small` - a resting card just needs enough lift
  /// to separate from the background, not to float above it. Pass
  /// `AppShadows.none` for a flush card (e.g. one already inside another
  /// card) or `AppShadows.medium`/`large` for a more prominent one.
  final List<BoxShadow>? shadow;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final content = Container(
      padding: padding,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(radius),
        boxShadow: shadow ?? AppShadows.small,
      ),
      child: child,
    );

    if (onTap == null) return content;

    return AppPressable(onTap: onTap, child: content);
  }
}
