import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../constants/api_constants.dart';
import '../storage/token_storage.dart';
import 'auth_events.dart';
import 'auth_interceptor.dart';

/// Builds a [Dio] instance with the shared transport configuration and no
/// interceptors attached.
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
        // Headers carry the bearer token and bodies carry passwords, so
        // neither is ever written to the debug console.
        requestHeader: false,
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

  // A bare client for replaying a request after a token refresh; it must not
  // run the auth interceptor again.
  final retryClient = buildDio();

  final storage = ref.watch(tokenStorageProvider);
  final events = ref.watch(authEventsProvider);

  dio.interceptors.add(
    AuthInterceptor(
      storage: storage,
      retryClient: retryClient,
      onAuthenticationLost: () async {
        await storage.clear();
        if (!events.isClosed) {
          events.add(AuthEvent.sessionExpired);
        }
      },
    ),
  );

  ref.onDispose(() {
    dio.close();
    retryClient.close();
  });

  return dio;
});
