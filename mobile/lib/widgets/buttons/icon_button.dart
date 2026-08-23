import 'package:flutter/material.dart';

import '../../theme/theme.dart';
import 'button_base.dart';

/// A small, icon-only tappable - a close button, a back arrow, a settings
/// gear. Always at least [AppSpacing.minTapTarget] regardless of the icon's
/// own size, so a visually small icon still gets a full-size touch target.
///
/// States: normal (`textSecondary` icon on a transparent or `surfaceVariant`
/// fill), pressed (scale-down), disabled (icon fades to 50% opacity via
/// `AppPressable`).
class AppIconButton extends StatelessWidget {
  const AppIconButton({
    super.key,
    required this.icon,
    required this.onPressed,
    this.semanticLabel,
    this.filled = false,
    this.color,
    this.size = AppSpacing.minTapTarget,
  });

  final IconData icon;
  final VoidCallback? onPressed;
  final String? semanticLabel;

  /// When true, sits on a soft `surfaceVariant` circle instead of a bare
  /// transparent background - for an icon button that needs to read clearly
  /// against a busy or image background.
  final bool filled;
  final Color? color;
  final double size;

  @override
  Widget build(BuildContext context) {
    final iconColor =
        color ??
        (onPressed == null ? AppColors.textSecondary : AppColors.textPrimary);

    return Semantics(
      button: true,
      label: semanticLabel,
      enabled: onPressed != null,
      child: AppPressable(
        onTap: onPressed,
        enabled: onPressed != null,
        child: Container(
          height: size,
          width: size,
          decoration: BoxDecoration(
            color: filled ? AppColors.surfaceVariant : Colors.transparent,
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: iconColor, size: size * 0.45),
        ),
      ),
    );
  }
}
