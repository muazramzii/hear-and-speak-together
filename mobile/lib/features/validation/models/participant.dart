/// One row of `participants.csv` - the evaluation roster. Deliberately
/// separate from any production model: Phase 4.5 is research-only and
/// must never read from or write to production tables.
class Participant {
  const Participant({
    required this.id,
    required this.ageGroup,
    required this.role,
    this.notes = '',
  });

  /// A short evaluator-assigned code (e.g. "P01"), not a database ID.
  final String id;

  /// Free text rather than a closed enum - the brief only *suggests*
  /// children (7-12), parents, and teachers/therapists, and explicitly
  /// requires supporting any participant makeup, not a fixed taxonomy.
  final String ageGroup;

  final String role;

  final String notes;

  factory Participant.fromCsvRow(Map<String, String> row) {
    return Participant(
      id: row['participant_id']?.trim() ?? '',
      ageGroup: row['age_group']?.trim() ?? '',
      role: row['role']?.trim() ?? '',
      notes: row['notes']?.trim() ?? '',
    );
  }

  Map<String, String> toCsvRow() {
    return {
      'participant_id': id,
      'age_group': ageGroup,
      'role': role,
      'notes': notes,
    };
  }
}
