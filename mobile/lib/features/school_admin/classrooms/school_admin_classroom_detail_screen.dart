import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_exception.dart';
import '../../../models/school.dart';
import '../../../repositories/classroom_repository.dart';
import '../../parent/design/parent_theme.dart';
import '../../parent/widgets/parent_widgets.dart';
import '../widgets/school_admin_skeleton.dart';

/// Classroom detail: staff roster, student count, and the three actions
/// the Phase 6 brief calls for - assign teacher, remove teacher, transfer
/// student - each via a modal bottom sheet.
///
/// Known API gap, documented rather than hidden: neither "assign
/// teacher" nor "transfer student" can offer a real picker. Assigning a
/// teacher needs their `public_id` (a UUID) - no endpoint in this system
/// exposes a school-wide teacher roster or returns a newly-accepted
/// teacher's UUID (Task 5's accept response only echoes school name/role/
/// timestamp). Transferring a student needs a `profile_id`, and no
/// endpoint returns a classroom's actual student roster, only the
/// `student_count` on this very detail response. Both actions take that
/// raw identifier as typed input instead of a dropdown - correct against
/// the real API, but a real UX gap this task's "do not modify backend"
/// constraint cannot close. Worth a follow-up task: have invitation
/// acceptance return the teacher's public_id, and add a classroom
/// student-roster endpoint.
class SchoolAdminClassroomDetailScreen extends ConsumerWidget {
  const SchoolAdminClassroomDetailScreen({
    super.key,
    required this.classroomId,
  });

  final int classroomId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.parentColors;
    final detailAsync = ref.watch(classroomDetailProvider(classroomId));

    return Scaffold(
      backgroundColor: palette.background,
      appBar: AppBar(
        title: detailAsync.maybeWhen(
          data: (detail) => Text(detail.name),
          orElse: () => const Text('Classroom'),
        ),
      ),
      body: SafeArea(
        child: detailAsync.when(
          loading: () => const _DetailSkeleton(),
          error: (error, _) => _ErrorState(
            message: error is ApiException ? error.message : '$error',
            onRetry: () =>
                ref.invalidate(classroomDetailProvider(classroomId)),
          ),
          data: (detail) => RefreshIndicator(
            onRefresh: () async =>
                ref.invalidate(classroomDetailProvider(classroomId)),
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _HeaderCard(detail: detail),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Teachers',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    TextButton.icon(
                      onPressed: () => _openAssignTeacherSheet(
                        context,
                        ref,
                        classroomId,
                      ),
                      icon: const Icon(Icons.person_add_alt_1_rounded),
                      label: const Text('Assign'),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                if (detail.staff.isEmpty)
                  const AnalyticsCard(
                    child: ParentEmptyState(
                      icon: Icons.school_outlined,
                      message: 'No teachers assigned to this classroom yet.',
                    ),
                  )
                else
                  AnalyticsCard(
                    child: Column(
                      children: [
                        for (var i = 0; i < detail.staff.length; i++) ...[
                          if (i > 0) const Divider(height: 24),
                          _StaffRow(
                            member: detail.staff[i],
                            classroomId: classroomId,
                          ),
                        ],
                      ],
                    ),
                  ),
                const SizedBox(height: 24),
                Text(
                  'Students',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 8),
                AnalyticsCard(
                  child: Row(
                    children: [
                      Expanded(
                        child: MetricTile(
                          label: 'Enrolled',
                          value: '${detail.studentCount}',
                          icon: Icons.groups_rounded,
                        ),
                      ),
                      FilledButton.icon(
                        onPressed: () => _openTransferStudentSheet(
                          context,
                          ref,
                          classroomId,
                        ),
                        icon: const Icon(Icons.swap_horiz_rounded),
                        label: const Text('Transfer student'),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _openAssignTeacherSheet(
    BuildContext context,
    WidgetRef ref,
    int classroomId,
  ) async {
    final assigned = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _AssignTeacherSheet(classroomId: classroomId),
    );
    if (assigned ?? false) {
      ref.invalidate(classroomDetailProvider(classroomId));
    }
  }

  Future<void> _openTransferStudentSheet(
    BuildContext context,
    WidgetRef ref,
    int classroomId,
  ) async {
    final transferred = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _TransferStudentSheet(classroomId: classroomId),
    );
    if (transferred ?? false) {
      ref.invalidate(classroomDetailProvider(classroomId));
    }
  }
}

class _HeaderCard extends StatelessWidget {
  const _HeaderCard({required this.detail});

  final ClassroomDetail detail;

  @override
  Widget build(BuildContext context) {
    final palette = context.parentColors;

    return AnalyticsCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  detail.name,
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
              ),
              if (!detail.isActive)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: palette.surfaceAlt,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    'Archived',
                    style: TextStyle(
                      color: palette.textSecondary,
                      fontWeight: FontWeight.w700,
                      fontSize: 11,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: palette.indigoSoft,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.qr_code_rounded, size: 16, color: palette.indigo),
                const SizedBox(width: 6),
                Text(
                  detail.classroomCode,
                  style: TextStyle(
                    color: palette.indigo,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.5,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StaffRow extends ConsumerWidget {
  const _StaffRow({required this.member, required this.classroomId});

  final ClassroomMembership member;
  final int classroomId;

  Future<void> _remove(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Remove teacher'),
        content: Text(
          'Remove ${member.teacherName} from this classroom? Their '
          'account is not affected.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (!(confirmed ?? false)) return;

    try {
      await ref
          .read(classroomRepositoryProvider)
          .removeTeacher(
            classroomId: classroomId,
            teacherPublicId: member.teacherId,
          );
      ref.invalidate(classroomDetailProvider(classroomId));
    } on ApiException catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.fieldMessage ?? error.message)));
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.parentColors;

    return Row(
      children: [
        CircleAvatar(
          radius: 18,
          backgroundColor: palette.indigoSoft,
          child: Text(
            member.teacherName.isEmpty
                ? '?'
                : member.teacherName[0].toUpperCase(),
            style: TextStyle(color: palette.indigo, fontWeight: FontWeight.w800),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                member.teacherName,
                style: Theme.of(context).textTheme.bodyLarge,
              ),
              Text(
                member.roleLabel,
                style: Theme.of(
                  context,
                ).textTheme.labelSmall?.copyWith(color: palette.textSecondary),
              ),
            ],
          ),
        ),
        IconButton(
          icon: Icon(Icons.close_rounded, color: palette.amber),
          tooltip: 'Remove',
          onPressed: () => _remove(context, ref),
        ),
      ],
    );
  }
}

class _AssignTeacherSheet extends ConsumerStatefulWidget {
  const _AssignTeacherSheet({required this.classroomId});

  final int classroomId;

  @override
  ConsumerState<_AssignTeacherSheet> createState() =>
      _AssignTeacherSheetState();
}

class _AssignTeacherSheetState extends ConsumerState<_AssignTeacherSheet> {
  final _teacherId = TextEditingController();
  String _role = 'LEAD_TEACHER';
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _teacherId.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() {
      _busy = true;
      _error = null;
    });

    try {
      await ref
          .read(classroomRepositoryProvider)
          .assignTeacher(
            classroomId: widget.classroomId,
            teacherPublicId: _teacherId.text.trim(),
            role: _role,
          );
      if (mounted) Navigator.of(context).pop(true);
    } on ApiException catch (error) {
      setState(() {
        _busy = false;
        _error = error.fieldMessage ?? error.message;
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
          Text('Assign a teacher', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 4),
          Text(
            "Find the teacher's ID from the Teachers list once they've "
            'accepted an invitation, or from another classroom they '
            'already staff.',
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
            controller: _teacherId,
            enabled: !_busy,
            decoration: const InputDecoration(
              labelText: 'Teacher ID',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            value: _role,
            decoration: const InputDecoration(
              labelText: 'Role',
              border: OutlineInputBorder(),
            ),
            items: const [
              DropdownMenuItem(
                value: 'LEAD_TEACHER',
                child: Text('Lead teacher'),
              ),
              DropdownMenuItem(value: 'ASSISTANT', child: Text('Assistant')),
              DropdownMenuItem(value: 'THERAPIST', child: Text('Therapist')),
            ],
            onChanged: _busy
                ? null
                : (value) => setState(() => _role = value ?? _role),
          ),
          const SizedBox(height: 20),

          FilledButton(
            onPressed: _busy ? null : _submit,
            child: Text(_busy ? 'Assigning…' : 'Assign'),
          ),
        ],
      ),
    );
  }
}

class _TransferStudentSheet extends ConsumerStatefulWidget {
  const _TransferStudentSheet({required this.classroomId});

  final int classroomId;

  @override
  ConsumerState<_TransferStudentSheet> createState() =>
      _TransferStudentSheetState();
}

class _TransferStudentSheetState
    extends ConsumerState<_TransferStudentSheet> {
  final _profileId = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _profileId.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final id = int.tryParse(_profileId.text.trim());
    if (id == null) {
      setState(() => _error = 'Enter a valid student profile ID.');
      return;
    }

    setState(() {
      _busy = true;
      _error = null;
    });

    try {
      await ref
          .read(classroomRepositoryProvider)
          .moveStudent(classroomId: widget.classroomId, profileId: id);
      if (mounted) Navigator.of(context).pop(true);
    } on ApiException catch (error) {
      setState(() {
        _busy = false;
        _error = error.fieldMessage ?? error.message;
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
          Text(
            'Transfer a student',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 4),
          Text(
            'Moves the student into this classroom. A student already '
            'enrolled elsewhere in this school is moved; one enrolled at '
            'a different school is rejected.',
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
            controller: _profileId,
            enabled: !_busy,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'Student profile ID',
              border: OutlineInputBorder(),
            ),
            onSubmitted: (_) => _busy ? null : _submit(),
          ),
          const SizedBox(height: 20),

          FilledButton(
            onPressed: _busy ? null : _submit,
            child: Text(_busy ? 'Moving…' : 'Transfer'),
          ),
        ],
      ),
    );
  }
}

class _DetailSkeleton extends StatelessWidget {
  const _DetailSkeleton();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      children: const [
        SkeletonBox(height: 100, borderRadius: 16),
        SizedBox(height: 24),
        SkeletonBox(width: 100, height: 20),
        SizedBox(height: 8),
        SkeletonBox(height: 80, borderRadius: 16),
      ],
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            message,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 16),
          OutlinedButton(onPressed: onRetry, child: const Text('Try Again')),
        ],
      ),
    );
  }
}
