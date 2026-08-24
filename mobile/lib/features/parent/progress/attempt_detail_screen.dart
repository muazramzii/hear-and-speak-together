import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_exception.dart';
import '../../../models/attempt.dart';
import '../../../repositories/attempts_repository.dart';
import '../design/parent_theme.dart';
import '../widgets/parent_widgets.dart';

/// Screen 4: the professional analysis view of one recording - full
/// terminology, no simplification, because this is for an adult who wants
/// to understand exactly what the pronunciation engine measured.
class AttemptDetailScreen extends ConsumerWidget {
  const AttemptDetailScreen({super.key, required this.attemptId});

  final int attemptId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.parentColors;
    final attemptAsync = ref.watch(attemptDetailProvider(attemptId));

    return Scaffold(
      backgroundColor: palette.background,
      appBar: AppBar(title: const Text('Attempt Detail')),
      body: SafeArea(
        child: attemptAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error:
              (error, _) => Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(
                    error is ApiException ? error.message : '$error',
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
          data: (attempt) => _DetailBody(attempt: attempt),
        ),
      ),
    );
  }
}

class _DetailBody extends StatelessWidget {
  const _DetailBody({required this.attempt});

  final Attempt attempt;

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

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        AnalyticsCard(
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _WordColumn(label: 'Target', value: attempt.wordText),
                  Icon(
                    Icons.arrow_forward_rounded,
                    color: palette.textSecondary,
                  ),
                  _WordColumn(
                    label: 'Recognized',
                    value:
                        attempt.recognizedText.isEmpty
                            ? '(nothing heard)'
                            : attempt.recognizedText,
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Text(
                score == null ? '—' : '$score%',
                style: textTheme.headlineLarge?.copyWith(
                  color: color,
                  fontSize: 44,
                ),
              ),
              Text('Overall score', style: textTheme.bodyMedium),
            ],
          ),
        ),
        const SizedBox(height: 16),

        AnalyticsCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Score breakdown', style: textTheme.titleMedium),
              const SizedBox(height: 16),
              _ScoreRow(
                label: 'Similarity',
                value: attempt.similarityScore,
                helper:
                    'Phonetic-feature distance between reference and spoken audio.',
              ),
              const SizedBox(height: 12),
              _ScoreRow(
                label: 'Confidence',
                value: attempt.confidenceScore,
                helper:
                    "The recognition model's own confidence in the transcription.",
              ),
              const SizedBox(height: 12),
              _ScoreRow(
                label: 'Completeness',
                value: attempt.completenessScore,
                helper:
                    "How much of the reference word's sound content was present.",
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        if (attempt.errors.isNotEmpty) ...[
          AnalyticsCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Detected errors', style: textTheme.titleMedium),
                const SizedBox(height: 12),
                for (final error in attempt.errors)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Row(
                      children: [
                        Icon(
                          Icons.report_gmailerrorred_rounded,
                          size: 16,
                          color: palette.amber,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _describeError(error),
                            style: textTheme.bodyLarge,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 16),
        ],

        if (attempt.feedback.isNotEmpty)
          AnalyticsCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Feedback', style: textTheme.titleMedium),
                const SizedBox(height: 8),
                Text(attempt.feedback, style: textTheme.bodyLarge),
              ],
            ),
          ),
        const SizedBox(height: 16),

        AnalyticsCard(
          child: Row(
            children: [
              Icon(
                Icons.schedule_rounded,
                size: 16,
                color: palette.textSecondary,
              ),
              const SizedBox(width: 8),
              Text(
                '${time.day}/${time.month}/${time.year} '
                '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}'
                ' · ${attempt.languageCode.toUpperCase()} · +${attempt.pointsAwarded} XP',
                style: textTheme.bodyMedium,
              ),
            ],
          ),
        ),
      ],
    );
  }

  String _describeError(PronunciationErrorEntry error) {
    return switch (error.type) {
      'missing_ending' =>
        'Missing ending sound (/${error.expected}/ was dropped)',
      'missing_phoneme' => 'Missing sound (/${error.expected}/ was dropped)',
      'wrong_consonant' =>
        'Wrong consonant (/${error.expected}/ heard as /${error.detected}/)',
      'wrong_vowel' =>
        'Wrong vowel (/${error.expected}/ heard as /${error.detected}/)',
      'substitution' =>
        '/${error.expected}/ substituted with /${error.detected}/',
      'extra_sound' => 'Extra sound inserted (/${error.detected}/)',
      _ => error.type,
    };
  }
}

class _WordColumn extends StatelessWidget {
  const _WordColumn({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(label, style: Theme.of(context).textTheme.labelSmall),
        const SizedBox(height: 4),
        Text(value, style: Theme.of(context).textTheme.titleLarge),
      ],
    );
  }
}

class _ScoreRow extends StatelessWidget {
  const _ScoreRow({
    required this.label,
    required this.value,
    required this.helper,
  });

  final String label;
  final double? value;
  final String helper;

  @override
  Widget build(BuildContext context) {
    final palette = context.parentColors;
    final rounded = value?.round();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: Theme.of(context).textTheme.bodyLarge),
            Text(
              rounded == null ? '—' : '$rounded%',
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ],
        ),
        const SizedBox(height: 4),
        LayoutBuilder(
          builder: (context, constraints) {
            return Stack(
              children: [
                Container(
                  height: 8,
                  width: constraints.maxWidth,
                  decoration: BoxDecoration(
                    color: palette.surfaceAlt,
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
                Container(
                  height: 8,
                  width:
                      constraints.maxWidth *
                      ((rounded ?? 0) / 100).clamp(0.0, 1.0),
                  decoration: BoxDecoration(
                    color: palette.indigo,
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ],
            );
          },
        ),
        const SizedBox(height: 4),
        Text(helper, style: Theme.of(context).textTheme.labelSmall),
      ],
    );
  }
}
