/// The six guided tasks every Phase 4.5 usability-evaluation participant
/// performs, in order. Fixed by the study design in the Phase 4.5 brief -
/// unlike participant count or role, the task set itself is not meant to
/// vary between evaluation runs.
enum ValidationTask {
  openAppNavigateHome('Task 1', 'Open the application and navigate to Home'),
  startLesson('Task 2', 'Start a lesson via the Learning Journey'),
  learnAndListen('Task 3', 'Complete Learn and Listen'),
  speakingPractice('Task 4', 'Perform Speaking Practice'),
  quiz('Task 5', 'Complete the Quiz'),
  parentDashboard('Task 6', 'Explore the Parent Dashboard');

  const ValidationTask(this.label, this.description);

  final String label;
  final String description;
}

/// The closed outcome vocabulary the brief specifies for every task
/// ("completed / failed / assistance required"), reused consistently
/// across all six tasks rather than a different scale per task.
enum CompletionStatus {
  completed('Completed'),
  failed('Failed'),
  assistanceRequired('Assistance required');

  const CompletionStatus(this.label);

  final String label;

  static CompletionStatus fromLabel(String value) {
    final normalized = value.trim().toLowerCase();
    return CompletionStatus.values.firstWhere(
      (status) =>
          status.label.toLowerCase() == normalized ||
          status.name.toLowerCase() == normalized,
      orElse:
          () => throw FormatException('Unknown completion status: $value'),
    );
  }
}
