/// The backend's self-report from `GET /api/health/`.
class HealthStatus {
  const HealthStatus({
    required this.status,
    required this.message,
    required this.database,
  });

  /// `ok` when everything is healthy, `degraded` when the API is up but a
  /// dependency (currently PostgreSQL) is not.
  final String status;
  final String message;

  /// `connected` or `unavailable`.
  final String database;

  bool get isHealthy => status == 'ok';
  bool get isDatabaseConnected => database == 'connected';

  factory HealthStatus.fromJson(Map<String, dynamic> json) {
    return HealthStatus(
      status: json['status'] as String? ?? 'unknown',
      message: json['message'] as String? ?? '',
      database: json['database'] as String? ?? 'unknown',
    );
  }
}
