import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/network/api_exception.dart';
import '../../../models/user.dart';
import '../../../repositories/students_repository.dart';
import '../../../routes/app_router.dart';
import '../design/parent_theme.dart';
import '../parent_providers.dart';
import '../widgets/parent_widgets.dart';

/// Screen 2: every learner this account may supervise. Tapping a card
/// selects that child - every other Parent Mode tab reads
/// `selectedStudentIdProvider`, so the whole platform updates immediately.
class ParentStudentsScreen extends ConsumerWidget {
  const ParentStudentsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.parentColors;
    final studentsAsync = ref.watch(studentsProvider);

    return Scaffold(
      backgroundColor: palette.background,
      appBar: AppBar(title: const Text('Students')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openLinkSheet(context, ref),
        icon: const Icon(Icons.person_add_alt_1_rounded),
        label: const Text('Link a learner'),
      ),
      body: SafeArea(
        child: studentsAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error:
              (error, _) => Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        error is ApiException ? error.message : '$error',
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      OutlinedButton(
                        onPressed: () => ref.invalidate(studentsProvider),
                        child: const Text('Try Again'),
                      ),
                    ],
                  ),
                ),
              ),
          data:
              (students) =>
                  students.isEmpty
                      ? const ParentEmptyState(
                        icon: Icons.family_restroom_rounded,
                        message:
                            'No learners yet. Link a child using their share code.',
                      )
                      : RefreshIndicator(
                        onRefresh: () async => ref.invalidate(studentsProvider),
                        child: ListView.separated(
                          padding: const EdgeInsets.all(16),
                          itemCount: students.length,
                          separatorBuilder:
                              (_, _) => const SizedBox(height: 12),
                          itemBuilder: (context, index) {
                            final student = students[index];
                            final isSelected =
                                effectiveStudentId(ref, students) == student.id;

                            return _StudentCard(
                              student: student,
                              isSelected: isSelected,
                              onTap: () {
                                ref
                                    .read(selectedStudentIdProvider.notifier)
                                    .state = student.id;
                                context.goNamed(AppRoutes.parentDashboardName);
                              },
                              onUnlink:
                                  () => _confirmUnlink(context, ref, student),
                            );
                          },
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
    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (dialogContext) => AlertDialog(
            title: const Text('Unlink learner'),
            content: Text('Stop following ${student.name}\'s progress?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(dialogContext).pop(true),
                child: const Text('Unlink'),
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
    required this.isSelected,
    required this.onTap,
    required this.onUnlink,
  });

  final SupervisedStudent student;
  final bool isSelected;
  final VoidCallback onTap;
  final VoidCallback onUnlink;

  @override
  Widget build(BuildContext context) {
    final palette = context.parentColors;
    final average = student.summary.averageScore;
    final language = AppLanguage.fromCode(student.languageCode).label;

    return Semantics(
      button: true,
      selected: isSelected,
      label:
          '${student.name}, level ${student.level}, '
          '${average == null ? "no score yet" : "$average percent average"}',
      child: Material(
        color: isSelected ? palette.indigoSoft : palette.surface,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isSelected ? palette.indigo : palette.border,
                width: isSelected ? 1.5 : 1,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      radius: 22,
                      backgroundColor: palette.indigoSoft,
                      child: Text(
                        student.name.isEmpty
                            ? '?'
                            : student.name[0].toUpperCase(),
                        style: TextStyle(
                          color: palette.indigo,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            student.name,
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          Text(
                            '$language · Level ${student.level}',
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                        ],
                      ),
                    ),
                    Text(
                      average == null ? '—' : '$average%',
                      style: Theme.of(
                        context,
                      ).textTheme.headlineMedium?.copyWith(
                        color:
                            average == null
                                ? palette.textSecondary
                                : palette.indigo,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.link_off_rounded, size: 20),
                      tooltip: 'Unlink',
                      onPressed: onUnlink,
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    _MiniStat(label: 'Streak', value: '${student.streakDays}d'),
                    _MiniStat(
                      label: 'Words learned',
                      value: '${student.summary.wordsLearned}',
                    ),
                    _MiniStat(
                      label: 'Sessions',
                      value: '${student.summary.practiceSessions}',
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
    final palette = context.parentColors;

    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Link a learner', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 4),
          Text(
            "Ask the family for the learner's share code.",
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 20),

          if (_error != null) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: palette.amberSoft,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(_error!, style: TextStyle(color: palette.amber)),
            ),
            const SizedBox(height: 12),
          ],

          TextField(
            controller: _code,
            enabled: !_busy,
            textCapitalization: TextCapitalization.characters,
            decoration: const InputDecoration(
              labelText: 'Share code',
              hintText: 'ABCD2345',
              border: OutlineInputBorder(),
            ),
            onSubmitted: (_) => _busy ? null : _submit(),
          ),
          const SizedBox(height: 20),

          FilledButton(
            onPressed: _busy ? null : _submit,
            child: Text(_busy ? 'Linking…' : 'Link'),
          ),
        ],
      ),
    );
  }
}
