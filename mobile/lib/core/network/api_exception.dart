import 'package:dio/dio.dart';

/// The kinds of failure the UI needs to tell apart.
enum ApiErrorKind {
  /// No usable network, or the server could not be reached at all.
  network,

  /// The server took too long to answer.
  timeout,

  /// The server answered, but with a 4xx/5xx status.
  server,

  /// Anything we did not anticipate.
  unknown,
}

/// A transport-agnostic error the UI can render without knowing about Dio.
///
/// Every message here is written to be safe to show to a user: it never
/// contains stack traces, credentials, or internal server detail.
class ApiException implements Exception {
  const ApiException({
    required this.kind,
    required this.message,
    this.statusCode,
  });

  final ApiErrorKind kind;
  final String message;
  final int? statusCode;

  /// Translates a [DioException] into a user-facing error.
  factory ApiException.fromDio(DioException error) {
    switch (error.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
      case DioExceptionType.transformTimeout:
        return const ApiException(
          kind: ApiErrorKind.timeout,
          message: 'The server took too long to respond. Please try again.',
        );

      case DioExceptionType.connectionError:
        return const ApiException(
          kind: ApiErrorKind.network,
          message:
              'Could not reach the server. Please check your internet '
              'connection.',
        );

      case DioExceptionType.badResponse:
        final status = error.response?.statusCode;
        return ApiException(
          kind: ApiErrorKind.server,
          statusCode: status,
          message: _messageForStatus(status),
        );

      // cancel, badCertificate, unknown, and anything a future Dio release
      // adds all surface as one generic, child-safe message.
      default:
        return const ApiException(
          kind: ApiErrorKind.unknown,
          message: 'Something went wrong. Please try again.',
        );
    }
  }

  static String _messageForStatus(int? status) {
    if (status == null) {
      return 'Something went wrong. Please try again.';
    }
    if (status == 401 || status == 403) {
      return 'You are not signed in. Please sign in and try again.';
    }
    if (status == 404) {
      return 'We could not find what you were looking for.';
    }
    if (status >= 500) {
      return 'The server is having trouble right now. Please try again.';
    }
    return 'Something went wrong. Please try again.';
  }

  @override
  String toString() => 'ApiException($kind, status: $statusCode): $message';
}
