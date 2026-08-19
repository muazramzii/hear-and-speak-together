import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hear_speak_together/core/network/api_exception.dart';

DioException _badResponse(int status, dynamic body) {
  final request = RequestOptions(path: '/auth/register/');
  return DioException(
    requestOptions: request,
    type: DioExceptionType.badResponse,
    response: Response(requestOptions: request, statusCode: status, data: body),
  );
}

void main() {
  group('transport failures', () {
    test('a connection error reads as a network problem', () {
      final error = ApiException.fromDio(
        DioException(
          requestOptions: RequestOptions(path: '/'),
          type: DioExceptionType.connectionError,
        ),
      );

      expect(error.kind, ApiErrorKind.network);
      expect(error.message, contains('internet connection'));
    });

    test('a timeout reads as a timeout', () {
      final error = ApiException.fromDio(
        DioException(
          requestOptions: RequestOptions(path: '/'),
          type: DioExceptionType.receiveTimeout,
        ),
      );

      expect(error.kind, ApiErrorKind.timeout);
    });
  });

  group('DRF validation errors', () {
    test('field errors are parsed from a list payload', () {
      final error = ApiException.fromDio(
        _badResponse(400, {
          'email': ['An account with this email already exists.'],
          'password': ['This password is too common.'],
        }),
      );

      expect(
        error.errorFor('email'),
        'An account with this email already exists.',
      );
      expect(error.errorFor('password'), 'This password is too common.');
      expect(error.fieldMessage, isNotNull);
    });

    test('a plain string detail is parsed too', () {
      final error = ApiException.fromDio(
        _badResponse(400, {'detail': 'No active account found.'}),
      );

      expect(error.errorFor('detail'), 'No active account found.');
    });

    test('a non-map body yields no field errors', () {
      final error = ApiException.fromDio(_badResponse(500, 'Server Error'));

      expect(error.fieldErrors, isEmpty);
      expect(error.fieldMessage, isNull);
      expect(error.message, contains('trouble'));
    });

    test('a 401 never leaks server wording to the user', () {
      final error = ApiException.fromDio(
        _badResponse(401, {'detail': 'token_not_valid'}),
      );

      expect(error.message, contains('not signed in'));
    });
  });
}
