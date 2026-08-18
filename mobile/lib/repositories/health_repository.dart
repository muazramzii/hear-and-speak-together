import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/constants/api_constants.dart';
import '../core/network/api_exception.dart';
import '../core/network/dio_client.dart';
import '../models/health_status.dart';

/// Reads the backend's health endpoint.
///
/// Repositories own all API access; widgets and providers never call Dio
/// directly.
class HealthRepository {
  const HealthRepository(this._dio);

  final Dio _dio;

  Future<HealthStatus> fetchHealth() async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        ApiConstants.health,
      );

      final data = response.data;
      if (data == null) {
        throw const ApiException(
          kind: ApiErrorKind.server,
          message: 'The server sent an unexpected response.',
        );
      }

      return HealthStatus.fromJson(data);
    } on DioException catch (error) {
      // A 503 from the health endpoint still carries a valid body describing
      // *why* the backend is unhealthy, so surface that rather than a
      // generic transport error.
      final body = error.response?.data;
      if (error.response?.statusCode == 503 && body is Map<String, dynamic>) {
        return HealthStatus.fromJson(body);
      }
      throw ApiException.fromDio(error);
    }
  }
}

final healthRepositoryProvider = Provider<HealthRepository>((ref) {
  return HealthRepository(ref.watch(dioProvider));
});

/// Drives the connection screen. `AsyncValue` gives the UI its loading,
/// success and error states for free.
final healthStatusProvider = FutureProvider.autoDispose<HealthStatus>((
  ref,
) async {
  return ref.watch(healthRepositoryProvider).fetchHealth();
});
