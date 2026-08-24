import 'package:flutter/material.dart';

import '../design/parent_theme.dart';

/// A horizontal bar whose fill colour intensity reflects its value - used
/// for category mastery (Progress > Categories) and the score-distribution
/// chart (Reports). Deliberately not a table: one glance at colour + length
/// says more than a column of numbers for this kind of comparison.
///
/// Colour is never the only signal: the percentage is always printed next
/// to the bar too, so the indicator reads correctly without colour vision.
class HeatBar extends StatelessWidget {
  const HeatBar({
    super.key,
    required this.label,
    required this.value,
    this.subtitle,
  });

  final String label;

  /// 0-100.
  final int value;
  final String? subtitle;

  Color _heatColor(ParentPalette palette) {
    final t = (value / 100).clamp(0.0, 1.0);
    return Color.lerp(palette.amber, palette.emerald, t)!;
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.parentColors;
    final color = _heatColor(palette);

    return Semantics(
      label: '$label: $value%${subtitle != null ? ', $subtitle' : ''}',
      excludeSemantics: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  label,
                  style: Theme.of(context).textTheme.bodyLarge,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Text(
                '$value%',
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(color: color),
              ),
            ],
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 2),
            Text(subtitle!, style: Theme.of(context).textTheme.labelSmall),
          ],
          const SizedBox(height: 6),
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: value / 100),
            duration: const Duration(milliseconds: 500),
            curve: Curves.easeOutCubic,
            builder: (context, fraction, _) {
              return LayoutBuilder(
                builder: (context, constraints) {
                  return Stack(
                    children: [
                      Container(
                        height: 10,
                        width: constraints.maxWidth,
                        decoration: BoxDecoration(
                          color: palette.surfaceAlt,
                          borderRadius: BorderRadius.circular(999),
                        ),
                      ),
                      Container(
                        height: 10,
                        width: constraints.maxWidth * fraction.clamp(0.0, 1.0),
                        decoration: BoxDecoration(
                          color: color,
                          borderRadius: BorderRadius.circular(999),
                        ),
                      ),
                    ],
                  );
                },
              );
            },
          ),
        ],
      ),
    );
  }
}
