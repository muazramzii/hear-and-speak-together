import 'package:flutter/material.dart';

import '../../../models/progress.dart';
import '../design/parent_theme.dart';
import 'analytics_card.dart';

/// "Recommended Practice" - what `LearningAnalyticsService.recommendations`
/// suggests next, and why. The reason is always shown: a suggestion with no
/// explanation is not something a parent can act on with confidence.
class RecommendationCard extends StatelessWidget {
  const RecommendationCard({
    super.key,
    required this.recommendation,
    this.onStartPractice,
  });

  final Recommendation recommendation;

  /// Called with the word to start practising - null hides the button (the
  /// recommendation types that carry no words, e.g. a reminder to return).
  final void Function(WeakWord word)? onStartPractice;

  String _reasonText() {
    return switch ((recommendation.type, recommendation.reason)) {
      ('practise_words', _) =>
        'These words are scoring below target and need repeating.',
      ('revisit_categories', _) =>
        'These categories are averaging below target.',
      ('gentle_reminder', _) =>
        recommendation.daysSincePractice != null
            ? "It's been ${recommendation.daysSincePractice} days since the last practice session."
            : 'Practice has lapsed recently.',
      ('get_started', _) => 'No practice sessions recorded yet.',
      _ => recommendation.reason,
    };
  }

  IconData get _icon => switch (recommendation.type) {
    'practise_words' => Icons.record_voice_over_rounded,
    'revisit_categories' => Icons.category_rounded,
    'gentle_reminder' => Icons.notifications_rounded,
    _ => Icons.flag_rounded,
  };

  @override
  Widget build(BuildContext context) {
    final palette = context.parentColors;
    final textTheme = Theme.of(context).textTheme;

    return AnalyticsCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(_icon, size: 18, color: palette.indigo),
              const SizedBox(width: 8),
              Text('Practice Today', style: textTheme.titleMedium),
            ],
          ),
          const SizedBox(height: 12),

          if (recommendation.words.isNotEmpty)
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final word in recommendation.words)
                  ActionChip(
                    label: Text(word.text),
                    backgroundColor: palette.indigoSoft,
                    labelStyle: TextStyle(color: palette.indigo),
                    side: BorderSide.none,
                    onPressed:
                        onStartPractice == null
                            ? null
                            : () => onStartPractice!(word),
                  ),
              ],
            )
          else if (recommendation.categories.isNotEmpty)
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final category in recommendation.categories)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: palette.amberSoft,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      category.name,
                      style: textTheme.bodyMedium?.copyWith(
                        color: palette.amber,
                      ),
                    ),
                  ),
              ],
            ),

          const SizedBox(height: 10),
          Text(_reasonText(), style: textTheme.bodyMedium),

          if (onStartPractice != null && recommendation.words.isNotEmpty) ...[
            const SizedBox(height: 14),
            OutlinedButton.icon(
              onPressed: () => onStartPractice!(recommendation.words.first),
              icon: const Icon(Icons.play_arrow_rounded, size: 18),
              label: const Text('Start Practice'),
            ),
          ],
        ],
      ),
    );
  }
}
