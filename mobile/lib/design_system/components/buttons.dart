import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../tokens.dart';

/// A press-scale wrapper shared by every button below, so "pressed" reads
/// the same way across the whole app - a small, quick shrink, not a colour
/// change alone. Colour-only feedback is invisible to a child who cannot
/// yet reliably distinguish subtle hue shifts; a size change is not.
class _PressableScale extends StatefulWidget {
  const _PressableScale({
    required this.onTap,
    required this.child,
    this.enabled = true,
  });

  final VoidCallback? onTap;
  final Widget child;
  final bool enabled;

  @override
  State<_PressableScale> createState() => _PressableScaleState();
}

class _PressableScaleState extends State<_PressableScale> {
  bool _pressed = false;

  void _setPressed(bool value) {
    if (widget.onTap == null) return;
    setState(() => _pressed = value);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => _setPressed(true),
      onTapCancel: () => _setPressed(false),
      onTapUp: (_) => _setPressed(false),
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: _pressed ? 0.96 : 1.0,
        duration: AppMotion.instant,
        curve: AppMotion.standard,
        child: Opacity(
          opacity: widget.enabled ? 1.0 : 0.5,
          child: widget.child,
        ),
      ),
    );
  }
}

/// The app's hero action button - gradient fill, generous tap target, a
/// press animation instead of Material's default ripple. Reserved for the
/// one primary action on a screen (start recording, continue the journey);
/// a screen with two of these has picked the wrong emphasis somewhere.
class AppPrimaryButton extends StatelessWidget {
  const AppPrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.gradient = AppGradients.primary,
    this.expand = true,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final Gradient gradient;

  /// Full-width by default, matching the existing FilledButton convention
  /// used across the app's forms and confirmations.
  final bool expand;

  @override
  Widget build(BuildContext context) {
    final textColor = AppA11y.textColorFor(
      gradient.colors.reduce(
        (a, b) =>
            AppA11y.relativeLuminance(a) < AppA11y.relativeLuminance(b) ? a : b,
      ),
    );

    final content = Container(
      height: AppSpacing.minTapTarget,
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
      decoration: BoxDecoration(
        gradient: onPressed == null ? null : gradient,
        color: onPressed == null ? AppColors.border : null,
        borderRadius: BorderRadius.circular(AppRadius.md),
        boxShadow:
            onPressed == null
                ? null
                : [
                  BoxShadow(
                    color: gradient.colors.last.withValues(alpha: 0.35),
                    blurRadius: 16,
                    offset: const Offset(0, 8),
                  ),
                ],
      ),
      child: Row(
        mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (icon != null) ...[
            Icon(icon, color: textColor, size: 22),
            const SizedBox(width: AppSpacing.sm),
          ],
          Flexible(
            child: Text(
              label,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: textColor,
                fontWeight: FontWeight.w800,
                fontSize: 17,
              ),
            ),
          ),
        ],
      ),
    );

    return Semantics(
      button: true,
      enabled: onPressed != null,
      child: _PressableScale(
        onTap: onPressed,
        enabled: onPressed != null,
        child:
            expand ? SizedBox(width: double.infinity, child: content) : content,
      ),
    );
  }
}

/// The secondary action - outlined, no fill, same press animation as
/// [AppPrimaryButton] so the two feel like one family rather than two
/// unrelated button systems (Material's default filled/outlined pairing
/// otherwise differs in more than colour: different ripple, different
/// timing).
class AppSecondaryButton extends StatelessWidget {
  const AppSecondaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.expand = true,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool expand;

  @override
  Widget build(BuildContext context) {
    final color =
        onPressed == null ? AppColors.textSecondary : AppColors.primary;

    final content = Container(
      height: AppSpacing.minTapTarget,
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
      decoration: BoxDecoration(
        border: Border.all(color: color, width: 1.5),
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Row(
        mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (icon != null) ...[
            Icon(icon, color: color, size: 20),
            const SizedBox(width: AppSpacing.sm),
          ],
          Flexible(
            child: Text(
              label,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.w700,
                fontSize: 16,
              ),
            ),
          ),
        ],
      ),
    );

    return Semantics(
      button: true,
      enabled: onPressed != null,
      child: _PressableScale(
        onTap: onPressed,
        enabled: onPressed != null,
        child:
            expand ? SizedBox(width: double.infinity, child: content) : content,
      ),
    );
  }
}

/// A large circular action button - used for exactly one thing in this
/// redesign: the Speaking Practice hero microphone. Not a general-purpose
/// icon button; see [AppMotion.slow] for its companion pulse animation,
/// built where the mic button is used rather than baked in here, since only
/// that screen needs the "listening" pulse state.
class AppCircularButton extends StatelessWidget {
  const AppCircularButton({
    super.key,
    required this.icon,
    required this.onPressed,
    this.diameter = 96,
    this.gradient = AppGradients.primary,
    this.semanticLabel,
  });

  final IconData icon;
  final VoidCallback? onPressed;
  final double diameter;
  final Gradient gradient;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final iconColor = AppA11y.textColorFor(gradient.colors.last);

    return Semantics(
      button: true,
      label: semanticLabel,
      enabled: onPressed != null,
      child: _PressableScale(
        onTap: onPressed,
        enabled: onPressed != null,
        child: Container(
          height: diameter,
          width: diameter,
          decoration: BoxDecoration(
            gradient: gradient,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: gradient.colors.last.withValues(alpha: 0.4),
                blurRadius: 24,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Icon(icon, color: iconColor, size: diameter * 0.42),
        ),
      ),
    );
  }
}
