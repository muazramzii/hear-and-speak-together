import 'package:flutter/material.dart';

import '../../theme/theme.dart';
import 'button_base.dart';

/// A bordered, unfilled button - the lowest-emphasis action that still
/// needs a visible tap target (e.g. "Try Again" next to a primary "Next
/// Word"). Same press animation as [AppPrimaryButton] and
/// [AppSecondaryButton] so the whole button family feels like one system.
///
/// States: normal (`primary`-coloured border and label), pressed
/// (scale-down), disabled (`textSecondary`-coloured border and label),
/// loading (spinner replaces the label).
class AppOutlineButton extends StatelessWidget {
  const AppOutlineButton({
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
    final color = disabled ? AppColors.textSecondary : AppColors.primary;

    final content = Container(
      height: AppSpacing.minTapTarget,
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
      decoration: BoxDecoration(
        border: Border.all(color: color, width: 1.5),
        borderRadius: BorderRadius.circular(AppRadius.medium),
      ),
      child:
          isLoading
              ? Center(
                child: SizedBox(
                  height: 22,
                  width: 22,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    color: color,
                  ),
                ),
              )
              : Row(
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
