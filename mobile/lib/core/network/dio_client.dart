import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../constants/api_constants.dart';

/// Builds the single [Dio] instance the whole app shares.
///
/// The auth interceptor that attaches JWT access tokens is added in Phase 2;
/// this phase only establishes the transport and logging.
Dio buildDio() {
  final dio = Dio(
    BaseOptions(
      baseUrl: ApiConstants.baseUrl,
      connectTimeout: ApiConstants.connectTimeout,
      receiveTimeout: ApiConstants.receiveTimeout,
      sendTimeout: ApiConstants.sendTimeout,
      headers: const {'Accept': 'application/json'},
      responseType: ResponseType.json,
    ),
  );

  if (kDebugMode) {
    dio.interceptors.add(
      LogInterceptor(
        request: true,
        requestHeader: false, // keeps tokens out of the debug console
        requestBody: false,
        responseHeader: false,
        responseBody: true,
        error: true,
      ),
    );
  }

  return dio;
}

/// App-wide HTTP client. Widgets never construct their own [Dio].
final dioProvider = Provider<Dio>((ref) {
  final dio = buildDio();
  ref.onDispose(dio.close);
  return dio;
});
