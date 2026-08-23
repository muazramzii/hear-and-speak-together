import 'package:flutter/material.dart';

import '../../theme/theme.dart';
import 'button_base.dart';

/// A flat, solid-fill button in the brand's secondary colour (sky blue) -
/// for an action that matters but should not compete with a screen's
/// [AppPrimaryButton]. Distinct from [AppOutlineButton]: this one has a
/// fill, that one doesn't.
///
/// States: normal (solid `secondaryStrong` fill - see `AppColors`'s WCAG
/// notes for why the "strong" variant, not the plain one, carries white
/// text), pressed (scale-down), disabled (grey fill), loading (spinner
/// replaces the label).
class AppSecondaryButton extends StatelessWidget {
  const AppSecondaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.expand = true,
    this.isLoading = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool expand;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    final disabled = onPressed == null || isLoading;
    const textColor = Colors.white;

    final content = Container(
      height: AppSpacing.minTapTarget,
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
      decoration: BoxDecoration(
        color: disabled ? AppColors.border : AppColors.secondaryStrong,
        borderRadius: BorderRadius.circular(AppRadius.medium),
      ),
      child:
          isLoading
              ? const Center(
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
                    Icon(icon, color: textColor, size: 20),
                    const SizedBox(width: AppSpacing.sm),
                  ],
                  Flexible(
                    child: Text(
                      label,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: textColor,
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
