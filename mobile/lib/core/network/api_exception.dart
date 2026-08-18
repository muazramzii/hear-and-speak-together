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
    this.fieldErrors = const {},
  });

  final ApiErrorKind kind;
  final String message;
  final int? statusCode;

  /// Per-field validation errors from DRF, e.g.
  /// `{"email": ["An account with this email already exists."]}`.
  /// Empty for anything that is not a 400.
  final Map<String, List<String>> fieldErrors;

  /// The first field error, suitable for showing above a form. Null when the
  /// failure was not a validation error.
  String? get fieldMessage {
    for (final messages in fieldErrors.values) {
      if (messages.isNotEmpty) return messages.first;
    }
    return null;
  }

  /// Errors for one specific input, so a form can mark that field.
  String? errorFor(String field) {
    final messages = fieldErrors[field];
    return (messages == null || messages.isEmpty) ? null : messages.first;
  }

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
        final fieldErrors = _parseFieldErrors(error.response?.data);
        return ApiException(
          kind: ApiErrorKind.server,
          statusCode: status,
          message: _messageForStatus(status),
          fieldErrors: fieldErrors,
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

  /// DRF reports validation failures as `{"field": ["message", ...]}`, and
  /// non-field failures as `{"detail": "message"}`. Both shapes are flattened
  /// into one map here so callers do not have to care which they got.
  static Map<String, List<String>> _parseFieldErrors(dynamic body) {
    if (body is! Map) return const {};

    final result = <String, List<String>>{};
    body.forEach((key, value) {
      if (key is! String) return;
      if (value is List) {
        final messages = value.whereType<String>().toList();
        if (messages.isNotEmpty) result[key] = messages;
      } else if (value is String) {
        result[key] = [value];
      }
    });
    return result;
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
