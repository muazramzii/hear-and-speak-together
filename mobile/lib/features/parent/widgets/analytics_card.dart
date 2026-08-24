import 'package:flutter/material.dart';

import '../design/parent_theme.dart';

/// The base surface every Parent Mode card builds on - flat, bordered,
/// minimal shadow. "More whitespace, minimal shadows" per the Phase 4
/// brief, the opposite instinct from the child app's soft-shadow `AppCard`.
class AnalyticsCard extends StatelessWidget {
  const AnalyticsCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(20),
    this.onTap,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.parentColors;

    final content = Container(
      padding: padding,
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: palette.border),
      ),
      child: child,
    );

    if (onTap == null) return content;

    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: content,
      ),
    );
  }
}
