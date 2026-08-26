import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_exception.dart';
import '../../../models/school.dart';
import '../../../repositories/teacher_invitation_repository.dart';
import '../../parent/design/parent_theme.dart';
import '../../parent/widgets/parent_widgets.dart';
import '../widgets/school_admin_skeleton.dart';

/// Teacher invitations - the entire school-facing "teacher roster" this
/// app has. There is no email delivery anywhere in this system: a code is
/// generated, shown, and copyable, and getting it to the teacher (reading
/// it aloud, pasting it into a message) is the admin's own job.
///
/// A teacher who has already accepted their invitation disappears from
/// this list - accepting marks the invitation inactive (Task 5's own
/// contract for "list active invitations"), and there is no separate
/// "confirmed teacher roster" endpoint to show instead without modifying
/// the backend, which this task must not do. Documented here rather than
/// silently implied.
class SchoolAdminTeachersScreen extends ConsumerWidget {
  const SchoolAdminTeachersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.parentColors;
    final invitationsAsync = ref.watch(teacherInvitationsProvider);

    return Scaffold(
      backgroundColor: palette.background,
      appBar: AppBar(
        title: const Text('Teachers'),
        actions: [
          IconButton(
            icon: const Icon(Icons.person_add_alt_1_rounded),
            tooltip: 'Invite teacher',
            onPressed: () => _openInviteSheet(context, ref),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            const ConnectivityBanner(),
            Expanded(
              child: invitationsAsync.when(
                loading: () => const _TeachersSkeleton(),
                error: (error, _) => _ErrorState(
                  message: error is ApiException ? error.message : '$error',
                  onRetry: () => ref.invalidate(teacherInvitationsProvider),
                ),
                data: (invitations) {
                  if (invitations.isEmpty) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const ParentEmptyState(
                              icon: Icons.person_add_alt_1_rounded,
                              message:
                                  'No pending invitations. Invite a '
                                  'teacher to get started - they join with '
                                  'a code, no email required.',
                            ),
                            const SizedBox(height: 8),
                            FilledButton.icon(
                              onPressed: () => _openInviteSheet(context, ref),
                              icon: const Icon(Icons.add_rounded),
                              label: const Text('Invite teacher'),
                            ),
                          ],
                        ),
                      ),
                    );
                  }

                  return RefreshIndicator(
                    onRefresh: () async =>
                        ref.invalidate(teacherInvitationsProvider),
                    child: ListView.separated(
                      padding: const EdgeInsets.all(16),
                      itemCount: invitations.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 12),
                      itemBuilder: (context, index) =>
                          _InvitationCard(invitation: invitations[index]),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openInviteSheet(BuildContext context, WidgetRef ref) async {
    final invited = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (_) => const _InviteTeacherSheet(),
    );

    if (invited ?? false) ref.invalidate(teacherInvitationsProvider);
  }
}

class _InvitationCard extends ConsumerStatefulWidget {
  const _InvitationCard({required this.invitation});

  final TeacherInvitation invitation;

  @override
  ConsumerState<_InvitationCard> createState() => _InvitationCardState();
}

class _InvitationCardState extends ConsumerState<_InvitationCard> {
  bool _busy = false;

  String get _expiryLabel {
    final invitation = widget.invitation;
    if (invitation.isExpired) return 'Expired';
    final daysLeft = invitation.expiresAt.difference(DateTime.now()).inDays;
    if (daysLeft <= 0) return 'Expires today';
    return 'Expires in $daysLeft ${daysLeft == 1 ? 'day' : 'days'}';
  }

  Future<void> _copyCode() async {
    await Clipboard.setData(
      ClipboardData(text: widget.invitation.invitationCode),
    );
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Invitation code copied')),
      );
    }
  }

  Future<void> _reset() async {
    setState(() => _busy = true);
    try {
      await ref
          .read(teacherInvitationRepositoryProvider)
          .resetInvitation(widget.invitation.id);
      ref.invalidate(teacherInvitationsProvider);
    } on ApiException catch (error) {
      if (mounted) {
        setState(() => _busy = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.message)));
      }
    }
  }

  Future<void> _deactivate() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Deactivate invitation'),
        content: Text(
          'The code for ${widget.invitation.email} will stop working. '
          'This cannot be undone from here - invite them again if needed.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Deactivate'),
          ),
        ],
      ),
    );
    if (!(confirmed ?? false)) return;

    setState(() => _busy = true);
    try {
      await ref
          .read(teacherInvitationRepositoryProvider)
          .deactivateInvitation(widget.invitation.id);
      ref.invalidate(teacherInvitationsProvider);
    } on ApiException catch (error) {
      if (mounted) {
        setState(() => _busy = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.message)));
      }
    }
  }

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
                  widget.invitation.email,
                  style: Theme.of(context).textTheme.titleMedium,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 3,
                ),
                decoration: BoxDecoration(
                  color: widget.invitation.isExpired
                      ? palette.amberSoft
                      : palette.emeraldSoft,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  _expiryLabel,
                  style: TextStyle(
                    color: widget.invitation.isExpired
                        ? palette.amber
                        : palette.emerald,
                    fontWeight: FontWeight.w700,
                    fontSize: 11,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          InkWell(
            onTap: _copyCode,
            borderRadius: BorderRadius.circular(10),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 10,
              ),
              decoration: BoxDecoration(
                color: palette.surfaceAlt,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: palette.border),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      widget.invitation.invitationCode,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        letterSpacing: 2,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  Icon(
                    Icons.copy_rounded,
                    size: 18,
                    color: palette.textSecondary,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton.icon(
                onPressed: _busy ? null : _reset,
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: const Text('Reset'),
              ),
              TextButton.icon(
                onPressed: _busy ? null : _deactivate,
                icon: Icon(
                  Icons.block_rounded,
                  size: 18,
                  color: palette.amber,
                ),
                label: Text(
                  'Deactivate',
                  style: TextStyle(color: palette.amber),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _InviteTeacherSheet extends ConsumerStatefulWidget {
  const _InviteTeacherSheet();

  @override
  ConsumerState<_InviteTeacherSheet> createState() =>
      _InviteTeacherSheetState();
}

class _InviteTeacherSheetState extends ConsumerState<_InviteTeacherSheet> {
  final _email = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() {
      _busy = true;
      _error = null;
    });

    try {
      await ref
          .read(teacherInvitationRepositoryProvider)
          .inviteTeacher(email: _email.text);
      if (mounted) Navigator.of(context).pop(true);
    } on ApiException catch (error) {
      setState(() {
        _busy = false;
        _error = error.errorFor('email') ?? error.message;
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
          Text('Invite a teacher', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 4),
          Text(
            'They join using a code - no email is sent from this app.',
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
            controller: _email,
            enabled: !_busy,
            keyboardType: TextInputType.emailAddress,
            decoration: const InputDecoration(
              labelText: 'Teacher email',
              hintText: 'teacher@example.com',
              border: OutlineInputBorder(),
            ),
            onSubmitted: (_) => _busy ? null : _submit(),
          ),
          const SizedBox(height: 20),

          FilledButton(
            onPressed: _busy ? null : _submit,
            child: Text(_busy ? 'Sending…' : 'Create invitation'),
          ),
        ],
      ),
    );
  }
}

class _TeachersSkeleton extends StatelessWidget {
  const _TeachersSkeleton();

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: 4,
      separatorBuilder: (_, _) => const SizedBox(height: 12),
      itemBuilder: (_, _) => const AnalyticsCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SkeletonBox(width: 160, height: 18),
            SizedBox(height: 12),
            SkeletonBox(height: 44, borderRadius: 10),
          ],
        ),
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
