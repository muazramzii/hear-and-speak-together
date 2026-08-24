import 'package:flutter/material.dart';

import '../../../models/progress.dart';
import '../design/parent_theme.dart';

/// One sound's row in the Pronunciation tab's heat-map: the phoneme, its
/// substitution rate as a heat-coloured bar, and the words it was misheard
/// in. Unlike [HeatBar]'s mastery bars, a *high* value here is the sound
/// worth worrying about, so the colour ramp runs the other way - amber for
/// frequent errors, emerald for a sound that is reliably correct.
class PhonemeBar extends StatelessWidget {
  const PhonemeBar({super.key, required this.stat, required this.isWeak});

  final PhonemeStat stat;

  /// Whether this row is being shown in the "needs improvement" list -
  /// purely for the accessibility label's wording, since the colour ramp
  /// already reflects the rate either way.
  final bool isWeak;

  Color _severityColor(ParentPalette palette) {
    final t = (stat.frequency / 100).clamp(0.0, 1.0);
    return Color.lerp(palette.emerald, palette.amber, t)!;
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.parentColors;
    final color = _severityColor(palette);
    final textTheme = Theme.of(context).textTheme;

    return Semantics(
      label:
          '${isWeak ? "Needs improvement" : "Strong"}: sound /${stat.phoneme}/, '
          '${stat.frequency}% error rate across ${stat.sampleSize} attempts'
          '${stat.examples.isNotEmpty ? ", heard in ${stat.examples.join(', ')}" : ''}',
      excludeSemantics: true,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 44,
              height: 44,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '/${stat.phoneme}/',
                style: textTheme.titleMedium?.copyWith(color: color),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0, end: stat.frequency / 100),
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
                                width:
                                    constraints.maxWidth *
                                    fraction.clamp(0.0, 1.0),
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
                  if (stat.examples.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: [
                        for (final example in stat.examples)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: palette.surfaceAlt,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(example, style: textTheme.labelSmall),
                          ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 12),
            Text(
              '${stat.frequency}%',
              style: textTheme.titleMedium?.copyWith(color: color),
            ),
          ],
        ),
      ),
    );
  }
}
