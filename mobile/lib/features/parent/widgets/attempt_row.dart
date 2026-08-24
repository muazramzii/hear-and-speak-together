import 'package:flutter/material.dart';

import '../../../models/attempt.dart';
import '../design/parent_theme.dart';

/// One row in the History tab's filterable attempt list: word, what was
/// actually recognised, score, and time - tap to open the full Attempt
/// Detail screen.
class AttemptRow extends StatelessWidget {
  const AttemptRow({super.key, required this.attempt, required this.onTap});

  final Attempt attempt;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.parentColors;
    final textTheme = Theme.of(context).textTheme;
    final score = attempt.score;
    final color =
        score == null
            ? palette.textSecondary
            : (attempt.passed ? palette.emerald : palette.amber);
    final time = attempt.createdAt.toLocal();
    final timeLabel =
        '${time.day}/${time.month}/${time.year} '
        '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';

    return Semantics(
      button: true,
      label:
          '${attempt.wordText}, recognised as ${attempt.recognizedText.isEmpty ? "nothing" : attempt.recognizedText}, '
          '${score == null ? "not scored" : "$score percent"}, $timeLabel',
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(attempt.wordText, style: textTheme.bodyLarge),
                    const SizedBox(height: 2),
                    Text(
                      attempt.recognizedText.isEmpty
                          ? 'No speech recognised'
                          : 'Heard: "${attempt.recognizedText}"',
                      style: textTheme.labelSmall,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(timeLabel, style: textTheme.labelSmall),
                  ],
                ),
              ),
              Text(
                score == null ? '—' : '$score%',
                style: textTheme.titleMedium?.copyWith(color: color),
              ),
              const SizedBox(width: 4),
              Icon(
                Icons.chevron_right_rounded,
                color: palette.textSecondary,
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
