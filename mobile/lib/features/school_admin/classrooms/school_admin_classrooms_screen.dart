import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/network/api_exception.dart';
import '../../../models/school.dart';
import '../../../repositories/classroom_repository.dart';
import '../../../routes/app_router.dart';
import '../../parent/design/parent_theme.dart';
import '../../parent/widgets/parent_widgets.dart';
import '../widgets/school_admin_skeleton.dart';

class SchoolAdminClassroomsScreen extends ConsumerStatefulWidget {
  const SchoolAdminClassroomsScreen({super.key});

  @override
  ConsumerState<SchoolAdminClassroomsScreen> createState() =>
      _SchoolAdminClassroomsScreenState();
}

class _SchoolAdminClassroomsScreenState
    extends ConsumerState<SchoolAdminClassroomsScreen> {
  final _search = TextEditingController();

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.parentColors;
    final filter = ref.watch(classroomListFilterProvider);
    final classroomsAsync = ref.watch(classroomsProvider);

    return Scaffold(
      backgroundColor: palette.background,
      appBar: AppBar(
        title: const Text('Classrooms'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_rounded),
            tooltip: 'Create classroom',
            onPressed: () => _openCreateSheet(context, ref),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            const ConnectivityBanner(),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: TextField(
                controller: _search,
                decoration: InputDecoration(
                  hintText: 'Search classrooms',
                  prefixIcon: const Icon(Icons.search_rounded),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  isDense: true,
                ),
                onChanged: (value) {
                  ref.read(classroomListFilterProvider.notifier).state = filter
                      .copyWith(search: value);
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: Row(
                children: [
                  FilterChip(
                    label: const Text('Active only'),
                    selected: filter.activeOnly,
                    onSelected: (selected) {
                      ref.read(classroomListFilterProvider.notifier).state =
                          filter.copyWith(activeOnly: selected);
                    },
                  ),
                ],
              ),
            ),
            Expanded(
              child: classroomsAsync.when(
                loading: () => const _ClassroomsSkeleton(),
                error: (error, _) => _ErrorState(
                  message: error is ApiException ? error.message : '$error',
                  onRetry: () => ref.invalidate(classroomsProvider),
                ),
                data: (classrooms) {
                  if (classrooms.isEmpty) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            ParentEmptyState(
                              icon: Icons.meeting_room_rounded,
                              message: filter.search.isNotEmpty
                                  ? 'No classrooms match "${filter.search}".'
                                  : 'No classrooms yet. Create one to start '
                                        'assigning teachers and students.',
                            ),
                            const SizedBox(height: 8),
                            FilledButton.icon(
                              onPressed: () => _openCreateSheet(context, ref),
                              icon: const Icon(Icons.add_rounded),
                              label: const Text('Create classroom'),
                            ),
                          ],
                        ),
                      ),
                    );
                  }

                  return RefreshIndicator(
                    onRefresh: () async => ref.invalidate(classroomsProvider),
                    child: ListView.separated(
                      padding: const EdgeInsets.all(16),
                      itemCount: classrooms.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 12),
                      itemBuilder: (context, index) => _ClassroomCard(
                        classroom: classrooms[index],
                        onTap: () => context.goNamed(
                          AppRoutes.schoolAdminClassroomDetailName,
                          pathParameters: {
                            'classroomId': '${classrooms[index].id}',
                          },
                        ),
                      ),
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

  Future<void> _openCreateSheet(BuildContext context, WidgetRef ref) async {
    final created = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (_) => const _CreateClassroomSheet(),
    );

    if (created ?? false) ref.invalidate(classroomsProvider);
  }
}

class _ClassroomCard extends ConsumerWidget {
  const _ClassroomCard({required this.classroom, required this.onTap});

  final Classroom classroom;
  final VoidCallback onTap;

  Future<void> _rename(BuildContext context, WidgetRef ref) async {
    final controller = TextEditingController(text: classroom.name);
    final newName = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Rename classroom'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'Classroom name'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.of(dialogContext).pop(controller.text.trim()),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    controller.dispose();

    if (newName == null || newName.isEmpty || newName == classroom.name) {
      return;
    }

    try {
      await ref
          .read(classroomRepositoryProvider)
          .renameClassroom(id: classroom.id, name: newName);
      ref.invalidate(classroomsProvider);
    } on ApiException catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.message)));
      }
    }
  }

  Future<void> _archive(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Archive classroom'),
        content: Text(
          '${classroom.name} will be hidden from active lists. Its staff, '
          'students and history are kept, not deleted.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Archive'),
          ),
        ],
      ),
    );
    if (!(confirmed ?? false)) return;

    try {
      await ref.read(classroomRepositoryProvider).archiveClassroom(classroom.id);
      ref.invalidate(classroomsProvider);
    } on ApiException catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.message)));
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.parentColors;

    return AnalyticsCard(
      onTap: onTap,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        classroom.name,
                        style: Theme.of(context).textTheme.titleMedium,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (!classroom.isActive)
                      Container(
                        margin: const EdgeInsets.only(left: 8),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
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
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: palette.indigoSoft,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    classroom.classroomCode,
                    style: TextStyle(
                      color: palette.indigo,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1,
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Icon(
                      Icons.groups_rounded,
                      size: 16,
                      color: palette.textSecondary,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '${classroom.studentCount} students',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                ),
              ],
            ),
          ),
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'rename') _rename(context, ref);
              if (value == 'archive') _archive(context, ref);
            },
            itemBuilder: (context) => const [
              PopupMenuItem(value: 'rename', child: Text('Rename')),
              PopupMenuItem(value: 'archive', child: Text('Archive')),
            ],
          ),
        ],
      ),
    );
  }
}

class _CreateClassroomSheet extends ConsumerStatefulWidget {
  const _CreateClassroomSheet();

  @override
  ConsumerState<_CreateClassroomSheet> createState() =>
      _CreateClassroomSheetState();
}

class _CreateClassroomSheetState extends ConsumerState<_CreateClassroomSheet> {
  final _name = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
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
          .createClassroom(name: _name.text);
      if (mounted) Navigator.of(context).pop(true);
    } on ApiException catch (error) {
      setState(() {
        _busy = false;
        _error = error.errorFor('name') ?? error.message;
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
            'Create a classroom',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 4),
          Text(
            'A unique classroom code is generated automatically.',
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
            controller: _name,
            enabled: !_busy,
            decoration: const InputDecoration(
              labelText: 'Classroom name',
              hintText: 'e.g. Room 4B',
              border: OutlineInputBorder(),
            ),
            onSubmitted: (_) => _busy ? null : _submit(),
          ),
          const SizedBox(height: 20),

          FilledButton(
            onPressed: _busy ? null : _submit,
            child: Text(_busy ? 'Creating…' : 'Create'),
          ),
        ],
      ),
    );
  }
}

class _ClassroomsSkeleton extends StatelessWidget {
  const _ClassroomsSkeleton();

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      physics: const NeverScrollableScrollPhysics(),
      itemCount: 4,
      separatorBuilder: (_, _) => const SizedBox(height: 12),
      itemBuilder: (_, _) => const SkeletonBox(height: 100, borderRadius: 16),
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
