import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../tokens.dart';

/// The base rounded surface for the redesigned screens - a flat tint fill,
/// no border (unlike the pre-Phase-3 `Card` theme, which outlines every
/// card in `AppColors.border`). The redesign leans on colour and spacing for
/// separation instead of borders, which read as more "premium" than a hard
/// outline around every tile.
class AppCard extends StatelessWidget {
  const AppCard({
    super.key,
    required this.child,
    this.color = AppColors.surface,
    this.padding = const EdgeInsets.all(AppSpacing.lg),
    this.radius = AppRadius.lg,
    this.onTap,
  });

  final Widget child;
  final Color color;
  final EdgeInsetsGeometry padding;
  final double radius;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final content = Container(
      padding: padding,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(radius),
      ),
      child: child,
    );

    if (onTap == null) return content;

    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(radius),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(radius),
        child: content,
      ),
    );
  }
}

/// A hero card with a gradient fill - reserved for the one or two surfaces
/// per screen that should visually anchor it (the Home greeting, a "level
/// up" moment), the same way [AppPrimaryButton] is reserved for the one
/// primary action. Text colour is picked automatically from the gradient's
/// darkest stop via [AppA11y.textColorFor], so a future palette change
/// cannot silently drop a gradient card's contrast below AA.
class AppGradientCard extends StatelessWidget {
  const AppGradientCard({
    super.key,
    required this.child,
    this.gradient = AppGradients.primary,
    this.padding = const EdgeInsets.all(AppSpacing.lg),
    this.radius = AppRadius.xl,
  });

  final Widget child;
  final Gradient gradient;
  final EdgeInsetsGeometry padding;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final darkestStop = gradient.colors.reduce(
      (a, b) =>
          AppA11y.relativeLuminance(a) < AppA11y.relativeLuminance(b) ? a : b,
    );
    final textColor = AppA11y.textColorFor(darkestStop);

    return Container(
      padding: padding,
      decoration: BoxDecoration(
        gradient: gradient,
        borderRadius: BorderRadius.circular(radius),
        boxShadow: [
          BoxShadow(
            color: darkestStop.withValues(alpha: 0.35),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: DefaultTextStyle.merge(
        style: TextStyle(color: textColor),
        child: IconTheme.merge(
          data: IconThemeData(color: textColor),
          child: child,
        ),
      ),
    );
  }
}
