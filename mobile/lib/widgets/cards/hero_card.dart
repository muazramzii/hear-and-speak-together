import 'package:flutter/material.dart';

import '../../theme/theme.dart';

/// A hero card with a gradient fill - reserved for the one or two surfaces
/// per screen that should visually anchor it (a greeting card, a "level up"
/// moment), the same way `AppPrimaryButton` is reserved for the one primary
/// action. Text/icon colour is picked automatically from the gradient's
/// darkest stop via `AppA11y.textColorFor`, so a future palette change
/// cannot silently drop a hero card's contrast below AA.
class HeroCard extends StatelessWidget {
  const HeroCard({
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
        boxShadow: AppShadows.glow(darkestStop),
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
