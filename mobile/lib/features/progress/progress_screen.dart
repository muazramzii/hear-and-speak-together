import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/api_exception.dart';
import '../../core/theme/app_theme.dart';
import '../../l10n/l10n.dart';
import '../../models/progress.dart';
import '../../repositories/profile_repository.dart';
import '../../repositories/progress_repository.dart';

class ProgressScreen extends ConsumerWidget {
  const ProgressScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final profile = ref.watch(activeProfileProvider);

    if (profile == null) {
      return Scaffold(
        appBar: AppBar(title: Text(l10n.progressTitle)),
        body: Center(child: Text(l10n.practiceChooseProfileFirst)),
      );
    }

    final report = ref.watch(progressReportProvider(profile.id));

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: Text(l10n.progressTitle),
      ),
      body: SafeArea(
        child: report.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error:
              (error, _) => _ErrorState(
                message:
                    error is ApiException ? error.message : l10n.errorGeneric,
                onRetry:
                    () => ref.invalidate(progressReportProvider(profile.id)),
              ),
          data:
              (data) => RefreshIndicator(
                onRefresh:
                    () async =>
                        ref.invalidate(progressReportProvider(profile.id)),
                child: _ReportView(report: data),
              ),
        ),
      ),
    );
  }
}

class _ReportView extends StatelessWidget {
  const _ReportView({required this.report});

  final ProgressReport report;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final summary = report.summary;

    return ListView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      children: [
        if (!summary.hasPractised)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Text(
                l10n.progressNoData,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ),
          ),

        if (summary.hasPractised) ...[
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: AppSpacing.md,
            crossAxisSpacing: AppSpacing.md,
            childAspectRatio: 1.6,
            children: [
              _StatTile(
                // A dash, not 0% - nothing measured is not the same as a
                // score of zero.
                value:
                    summary.averageScore == null
                        ? '-'
                        : '${summary.averageScore}%',
                label: l10n.progressAverageScore,
                tint: AppColors.greenSoft,
                icon: Icons.insights_rounded,
                accent: AppColors.green,
              ),
              _StatTile(
                value: '${summary.wordsLearned}',
                label: l10n.progressWordsLearned,
                tint: AppColors.blueSoft,
                icon: Icons.menu_book_rounded,
                accent: AppColors.blue,
              ),
              _StatTile(
                value: '${summary.lessonsStarted}',
                label: l10n.progressLessonsStarted,
                tint: AppColors.amberSoft,
                icon: Icons.school_rounded,
                accent: AppColors.amber,
              ),
              _StatTile(
                value: '${summary.practiceSessions}',
                label: l10n.progressSessions,
                tint: AppColors.violetSoft,
                icon: Icons.mic_rounded,
                accent: AppColors.primary,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
        ],

        if (report.weakWords.isNotEmpty) ...[
          Text(
            l10n.progressWeakWords,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: AppSpacing.sm),
          for (final word in report.weakWords) _WeakWordRow(word: word),
          const SizedBox(height: AppSpacing.lg),
        ],

        if (report.categories.isNotEmpty) ...[
          Text(
            l10n.navProgress,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: AppSpacing.sm),
          for (final category in report.categories)
            _CategoryRow(category: category),
          const SizedBox(height: AppSpacing.lg),
        ],

        for (final lesson in report.lessons) _LessonRow(lesson: lesson),
      ],
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({
    required this.value,
    required this.label,
    required this.tint,
    required this.icon,
    required this.accent,
  });

  final String value;
  final String label;
  final Color tint;
  final IconData icon;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: tint,
        borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Icon(icon, color: accent, size: 22),
          Text(value, style: Theme.of(context).textTheme.headlineMedium),
          Text(label, style: Theme.of(context).textTheme.labelSmall),
        ],
      ),
    );
  }
}

class _WeakWordRow extends StatelessWidget {
  const _WeakWordRow({required this.word});

  final WeakWord word;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: AppColors.amberSoft,
          borderRadius: BorderRadius.circular(AppSpacing.buttonRadius),
        ),
        child: Row(
          children: [
            const Icon(Icons.refresh_rounded, color: AppColors.warning),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(word.text, style: Theme.of(context).textTheme.bodyLarge),
                  Text(
                    context.l10n.progressAttemptsCount(word.attempts),
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
    );
  }
}

class _CategoryRow extends StatelessWidget {
  const _CategoryRow({required this.category});

  final CategoryPerformance category;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      child: Row(
        children: [
          Text(
            category.icon.isEmpty ? '📚' : category.icon,
            style: const TextStyle(fontSize: 20),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  category.name,
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
                const SizedBox(height: AppSpacing.xs),
                ClipRRect(
                  borderRadius: BorderRadius.circular(999),
                  child: LinearProgressIndicator(
                    value: category.averageScore / 100,
                    backgroundColor: AppColors.border,
                    color:
                        category.isWeak ? AppColors.warning : AppColors.success,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Text(
            '${category.averageScore}%',
            style: Theme.of(context).textTheme.bodyLarge,
          ),
        ],
      ),
    );
  }
}

class _LessonRow extends StatelessWidget {
  const _LessonRow({required this.lesson});

  final LessonProgress lesson;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  lesson.title,
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
                Text(
                  '${lesson.completedWords} / ${lesson.totalWords}',
                  style: Theme.of(context).textTheme.labelSmall,
                ),
                const SizedBox(height: AppSpacing.xs),
                ClipRRect(
                  borderRadius: BorderRadius.circular(999),
                  child: LinearProgressIndicator(
                    value: lesson.fraction,
                    backgroundColor: AppColors.border,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Text(
            '${lesson.completionPercentage}%',
            style: Theme.of(context).textTheme.bodyLarge,
          ),
        ],
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.error_outline_rounded,
              size: 44,
              color: AppColors.danger,
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              message,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: AppSpacing.lg),
            FilledButton(
              onPressed: onRetry,
              child: Text(context.l10n.actionTryAgain),
            ),
          ],
        ),
      ),
    );
  }
}
