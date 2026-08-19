import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/network/api_exception.dart';
import '../../core/theme/app_theme.dart';
import '../../l10n/l10n.dart';
import '../../repositories/students_repository.dart';
import '../../routes/app_router.dart';
import '../../widgets/app_text_field.dart';

/// The parent/teacher view: every learner they may follow.
class StudentsScreen extends ConsumerWidget {
  const StudentsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final students = ref.watch(studentsProvider);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.studentsTitle)),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openLinkSheet(context, ref),
        icon: const Icon(Icons.person_add_alt_1_rounded),
        label: Text(l10n.studentsLink),
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: students.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error:
                  (error, _) => _ErrorState(
                    message:
                        error is ApiException
                            ? error.message
                            : l10n.errorGeneric,
                    onRetry: () => ref.invalidate(studentsProvider),
                  ),
              data:
                  (items) =>
                      items.isEmpty
                          ? Padding(
                            padding: const EdgeInsets.all(AppSpacing.lg),
                            child: Text(
                              l10n.studentsEmpty,
                              textAlign: TextAlign.center,
                              style: Theme.of(context).textTheme.bodyMedium,
                            ),
                          )
                          : RefreshIndicator(
                            onRefresh:
                                () async => ref.invalidate(studentsProvider),
                            child: ListView(
                              padding: const EdgeInsets.all(AppSpacing.lg),
                              children: [
                                for (final student in items)
                                  _StudentCard(
                                    student: student,
                                    onTap:
                                        () => context.pushNamed(
                                          AppRoutes.studentDetailName,
                                          pathParameters: {
                                            'profileId': '${student.id}',
                                          },
                                        ),
                                    onUnlink:
                                        () => _confirmUnlink(
                                          context,
                                          ref,
                                          student,
                                        ),
                                  ),
                              ],
                            ),
                          ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _confirmUnlink(
    BuildContext context,
    WidgetRef ref,
    SupervisedStudent student,
  ) async {
    final l10n = context.l10n;

    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (dialogContext) => AlertDialog(
            title: Text(l10n.studentsUnlink),
            content: Text('${student.name} - ${l10n.studentsUnlinkConfirm}'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(false),
                child: Text(l10n.actionCancel),
              ),
              FilledButton(
                onPressed: () => Navigator.of(dialogContext).pop(true),
                child: Text(l10n.studentsUnlink),
              ),
            ],
          ),
    );

    if (!(confirmed ?? false)) return;

    try {
      await ref.read(studentsRepositoryProvider).unlinkStudent(student.id);
      ref.invalidate(studentsProvider);
    } on ApiException catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.message)));
      }
    }
  }

  Future<void> _openLinkSheet(BuildContext context, WidgetRef ref) async {
    final linked = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (_) => const _LinkStudentSheet(),
    );

    if (linked ?? false) ref.invalidate(studentsProvider);
  }
}

class _StudentCard extends StatelessWidget {
  const _StudentCard({
    required this.student,
    required this.onTap,
    required this.onUnlink,
  });

  final SupervisedStudent student;
  final VoidCallback onTap;
  final VoidCallback onUnlink;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final average = student.summary.averageScore;

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Material(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
          child: Container(
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            student.name,
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          const SizedBox(height: AppSpacing.xs),
                          Text(
                            l10n.profileLevel(student.level),
                            style: Theme.of(context).textTheme.labelSmall,
                          ),
                        ],
                      ),
                    ),
                    // A dash rather than 0% when nothing has been measured.
                    Text(
                      average == null ? '-' : '$average%',
                      style: Theme.of(
                        context,
                      ).textTheme.headlineMedium?.copyWith(
                        color:
                            average == null
                                ? AppColors.textSecondary
                                : AppColors.primary,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.link_off_rounded, size: 20),
                      tooltip: l10n.studentsUnlink,
                      onPressed: onUnlink,
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.sm),
                Row(
                  children: [
                    _MiniStat(
                      label: l10n.progressWordsLearned,
                      value: '${student.summary.wordsLearned}',
                    ),
                    _MiniStat(
                      label: l10n.progressSessions,
                      value: '${student.summary.practiceSessions}',
                    ),
                    _MiniStat(
                      label: l10n.navProgress,
                      value: '${student.streakDays}',
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  const _MiniStat({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Text(value, style: Theme.of(context).textTheme.titleMedium),
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

class _LinkStudentSheet extends ConsumerStatefulWidget {
  const _LinkStudentSheet();

  @override
  ConsumerState<_LinkStudentSheet> createState() => _LinkStudentSheetState();
}

class _LinkStudentSheetState extends ConsumerState<_LinkStudentSheet> {
  final _code = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() {
      _busy = true;
      _error = null;
    });

    try {
      await ref.read(studentsRepositoryProvider).linkStudent(_code.text);
      if (mounted) Navigator.of(context).pop(true);
    } on ApiException catch (error) {
      setState(() {
        _busy = false;
        _error = error.errorFor('share_code') ?? error.message;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return Padding(
      padding: EdgeInsets.only(
        left: AppSpacing.lg,
        right: AppSpacing.lg,
        top: AppSpacing.lg,
        bottom: MediaQuery.of(context).viewInsets.bottom + AppSpacing.lg,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            l10n.studentsLink,
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            l10n.studentsLinkHelp,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: AppSpacing.lg),

          if (_error != null) ...[
            AppErrorBanner(message: _error!),
            const SizedBox(height: AppSpacing.md),
          ],

          AppTextField(
            label: l10n.studentsShareCode,
            controller: _code,
            hint: 'ABCD2345',
            enabled: !_busy,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _busy ? null : _submit(),
          ),
          const SizedBox(height: AppSpacing.lg),

          FilledButton(
            onPressed: _busy ? null : _submit,
            child: Text(_busy ? l10n.statusLoading : l10n.studentsLink),
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
