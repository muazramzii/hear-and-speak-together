import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../repositories/students_repository.dart';

/// Which learner Parent Mode's Dashboard/Progress/Reports tabs are showing.
/// Null means "not chosen yet" - resolved to the first student once the
/// list loads, via [effectiveStudentId], rather than defaulted here, since
/// this provider has no access to the student list itself.
final selectedStudentIdProvider = StateProvider<int?>((ref) => null);

/// The student every analytics screen should show: whichever was explicitly
/// selected, falling back to the first supervised learner - the common
/// single-child case needs no picker interaction at all.
int? effectiveStudentId(WidgetRef ref, List<SupervisedStudent> students) {
  final selected = ref.watch(selectedStudentIdProvider);
  if (selected != null && students.any((s) => s.id == selected)) {
    return selected;
  }
  return students.isEmpty ? null : students.first.id;
}
