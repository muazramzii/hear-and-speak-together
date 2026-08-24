import 'package:flutter/material.dart';

import '../../../models/progress.dart';
import '../design/parent_theme.dart';

/// One row in the Recent Activity timeline: a word, when it was attempted,
/// and the score - a plain chronological feed, not a graded list.
class ActivityTile extends StatelessWidget {
  const ActivityTile({super.key, required this.attempt});

  final RecentAttempt attempt;

  String _dayLabel() {
    final now = DateTime.now();
    final date = attempt.createdAt.toLocal();
    final today = DateTime(now.year, now.month, now.day);
    final day = DateTime(date.year, date.month, date.day);
    final difference = today.difference(day).inDays;

    if (difference == 0) return 'Today';
    if (difference == 1) return 'Yesterday';
    return '${date.day}/${date.month}/${date.year}';
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.parentColors;
    final score = attempt.score;
    final color =
        score == null
            ? palette.textSecondary
            : (score >= 75 ? palette.emerald : palette.amber);

    return Semantics(
      label:
          '${attempt.word}, ${_dayLabel()}, '
          '${score == null ? 'not scored' : '$score percent'}',
      excludeSemantics: true,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          children: [
            Container(
              width: 8,
              height: 8,
              margin: const EdgeInsets.only(right: 12),
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    attempt.word,
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                  Text(
                    _dayLabel(),
                    style: Theme.of(context).textTheme.labelSmall,
                  ),
                ],
              ),
            ),
            Text(
              score == null ? '—' : '$score%',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(color: color),
            ),
          ],
        ),
      ),
    );
  }
}
