import 'validation_enums.dart';

/// One row of `observations.csv` - a single participant's outcome on a
/// single task. This is the "Data Collection" record the Phase 4.5 brief
/// specifies: Participant ID, Task, Completion, Completion Time, Errors,
/// Assistance, and Notes. Age group and role live on [Participant] and
/// are joined by `participantId` rather than duplicated on every row.
class Observation {
  const Observation({
    required this.participantId,
    required this.task,
    required this.completion,
    this.completionTime,
    this.errors = 0,
    this.assistanceGiven = false,
    this.notes = '',
  });

  final String participantId;
  final ValidationTask task;
  final CompletionStatus completion;

  /// Null when a task is purely observational and timing wasn't captured
  /// (e.g. Task 1's success criterion is reaching Home unassisted, not a
  /// timed measurement).
  final Duration? completionTime;

  /// Mistakes/retries counted during the task (Task 4's retry count,
  /// Task 5's quiz mistakes, and so on).
  final int errors;

  final bool assistanceGiven;

  final String notes;

  factory Observation.fromCsvRow(Map<String, String> row) {
    final seconds = row['completion_time_seconds']?.trim();
    final taskName = row['task']?.trim();
    return Observation(
      participantId: row['participant_id']?.trim() ?? '',
      task: ValidationTask.values.firstWhere(
        (candidate) => candidate.name == taskName,
        orElse: () => throw FormatException('Unknown task: $taskName'),
      ),
      completion: CompletionStatus.fromLabel(row['completion'] ?? ''),
      completionTime:
          (seconds == null || seconds.isEmpty)
              ? null
              : Duration(seconds: int.parse(seconds)),
      errors: int.tryParse(row['errors']?.trim() ?? '') ?? 0,
      assistanceGiven:
          (row['assistance_given']?.trim().toLowerCase() ?? 'false') ==
          'true',
      notes: row['notes']?.trim() ?? '',
    );
  }

  Map<String, String> toCsvRow() {
    return {
      'participant_id': participantId,
      'task': task.name,
      'completion': completion.label,
      'completion_time_seconds': completionTime?.inSeconds.toString() ?? '',
      'errors': errors.toString(),
      'assistance_given': assistanceGiven.toString(),
      'notes': notes,
    };
  }
}
