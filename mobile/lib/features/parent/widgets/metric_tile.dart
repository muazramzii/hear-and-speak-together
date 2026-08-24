import 'package:flutter/material.dart';

import '../design/parent_theme.dart';

/// A single labelled number - the Overall tab's grid of "Average score",
/// "Lessons completed" etc. is built from these.
class MetricTile extends StatelessWidget {
  const MetricTile({
    super.key,
    required this.label,
    required this.value,
    this.icon,
    this.trend,
    this.trendPositive,
  });

  final String label;
  final String value;
  final IconData? icon;

  /// A short delta line, e.g. "+7% this week" - optional, shown under the
  /// value. Colour-independent: an up/down icon carries the direction, not
  /// colour alone.
  final String? trend;
  final bool? trendPositive;

  @override
  Widget build(BuildContext context) {
    final palette = context.parentColors;
    final textTheme = Theme.of(context).textTheme;

    return Semantics(
      label: '$label: $value${trend != null ? ', $trend' : ''}',
      excludeSemantics: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              if (icon != null) ...[
                Icon(icon, size: 16, color: palette.textSecondary),
                const SizedBox(width: 6),
              ],
              Flexible(
                child: Text(
                  label,
                  style: textTheme.bodyMedium,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: textTheme.headlineMedium,
            overflow: TextOverflow.ellipsis,
          ),
          if (trend != null) ...[
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(
                  trendPositive == false
                      ? Icons.trending_down_rounded
                      : Icons.trending_up_rounded,
                  size: 14,
                  color:
                      trendPositive == false ? palette.amber : palette.emerald,
                ),
                const SizedBox(width: 4),
                Flexible(
                  child: Text(
                    trend!,
                    overflow: TextOverflow.ellipsis,
                    style: textTheme.labelSmall?.copyWith(
                      color:
                          trendPositive == false
                              ? palette.amber
                              : palette.emerald,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
