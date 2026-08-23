import 'package:flutter/material.dart';

import '../../theme/theme.dart';
import 'button_base.dart';

/// The app's hero action button - gradient fill, generous tap target.
/// Reserved for the one primary action on a screen (start recording,
/// continue the journey); a screen with two of these has picked the wrong
/// emphasis somewhere.
///
/// States: normal (gradient + shadow), pressed (`AppPressable`'s scale-down),
/// disabled (`onPressed: null` - flat border-grey fill, no shadow), loading
/// (`isLoading: true` - a spinner replaces the label, `onPressed` is ignored
/// while loading so a slow request can't be fired twice).
class AppPrimaryButton extends StatelessWidget {
  const AppPrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.gradient = AppGradients.primary,
    this.expand = true,
    this.isLoading = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final Gradient gradient;

  /// Full-width by default, matching the existing FilledButton convention
  /// used across the app's forms and confirmations.
  final bool expand;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    final disabled = onPressed == null || isLoading;
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
        gradient: disabled ? null : gradient,
        color: disabled ? AppColors.border : null,
        borderRadius: BorderRadius.circular(AppRadius.medium),
        boxShadow: disabled ? null : AppShadows.glow(gradient.colors.last),
      ),
      child:
          isLoading
              ? Center(
                child: SizedBox(
                  height: 22,
                  width: 22,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    color: textColor,
                  ),
                ),
              )
              : Row(
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
      enabled: !disabled,
      child: AppPressable(
        onTap: disabled ? null : onPressed,
        enabled: !disabled,
        child:
            expand ? SizedBox(width: double.infinity, child: content) : content,
      ),
    );
  }
}
