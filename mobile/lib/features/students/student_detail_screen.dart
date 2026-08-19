import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/api_exception.dart';
import '../../core/theme/app_theme.dart';
import '../../l10n/l10n.dart';
import '../../models/progress.dart';
import '../../repositories/students_repository.dart';

/// One learner in full: the supervisor's version of the progress screen.
class StudentDetailScreen extends ConsumerWidget {
  const StudentDetailScreen({super.key, required this.profileId});

  final int profileId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final report = ref.watch(studentProgressProvider(profileId));

    return Scaffold(
      appBar: AppBar(title: Text(l10n.progressTitle)),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: report.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, _) => Padding(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      error is ApiException ? error.message : l10n.errorGeneric,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    const SizedBox(height: AppSpacing.md),
                    FilledButton(
                      onPressed: () =>
                          ref.invalidate(studentProgressProvider(profileId)),
                      child: Text(l10n.actionTryAgain),
                    ),
                  ],
                ),
              ),
              data: (data) => _DetailView(report: data),
            ),
          ),
        ),
      ),
    );
  }
}

class _DetailView extends StatelessWidget {
  const _DetailView({required this.report});

  final ProgressReport report;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final summary = report.summary;

    return ListView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      children: [
        Row(
          children: [
            _Stat(
              value: summary.averageScore == null
                  ? '-'
                  : '${summary.averageScore}%',
              label: l10n.progressAverageScore,
            ),
            _Stat(
              value: '${summary.wordsLearned}',
              label: l10n.progressWordsLearned,
            ),
            _Stat(
              value: '${summary.lessonsCompleted}',
              label: l10n.progressLessonsStarted,
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.lg),

        if (report.weakWords.isNotEmpty) ...[
          Text(
            l10n.progressWeakWords,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: AppSpacing.sm),
          for (final word in report.weakWords)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: Container(
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                  color: AppColors.amberSoft,
                  borderRadius: BorderRadius.circular(AppSpacing.buttonRadius),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            word.text,
                            style: Theme.of(context).textTheme.bodyLarge,
                          ),
                          Text(
                            l10n.progressAttemptsCount(word.attempts),
                            style: Theme.of(context).textTheme.labelSmall,
                          ),
                        ],
                      ),
                    ),
                    Text(
                      '${word.averageScore}%',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ],
                ),
              ),
            ),
          const SizedBox(height: AppSpacing.lg),
        ],

        for (final category in report.categories)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
            child: Row(
              children: [
                Text(
                  category.icon.isEmpty ? '📚' : category.icon,
                  style: const TextStyle(fontSize: 20),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    category.name,
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                ),
                Text(
                  '${category.averageScore}%',
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: category.isWeak
                        ? AppColors.warning
                        : AppColors.success,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Text(value, style: Theme.of(context).textTheme.headlineMedium),
          Text(
            label,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.labelSmall,
          ),
        ],
      ),
    );
  }
}
