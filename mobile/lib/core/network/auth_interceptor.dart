import 'dart:async';

import 'package:dio/dio.dart';

import '../constants/api_constants.dart';
import '../storage/token_storage.dart';

/// Attaches the JWT access token to every request and, when the server says
/// the token has expired, refreshes it once and replays the original request.
///
/// The refresh call goes through a *separate* bare [Dio] instance. Reusing the
/// main client would send the request back through this interceptor and, on a
/// failing refresh, recurse until the stack blew up.
class AuthInterceptor extends Interceptor {
  AuthInterceptor({
    required TokenStorage storage,
    required Dio retryClient,
    required this.onAuthenticationLost,
  }) : _storage = storage,
       _retryClient = retryClient,
       _refreshClient = Dio(
         BaseOptions(
           baseUrl: ApiConstants.baseUrl,
           connectTimeout: ApiConstants.connectTimeout,
           receiveTimeout: ApiConstants.receiveTimeout,
           headers: const {'Accept': 'application/json'},
         ),
       );

  final TokenStorage _storage;
  final Dio _retryClient;
  final Dio _refreshClient;

  /// Called when the refresh token is missing, expired or rejected, meaning
  /// the user must sign in again.
  final Future<void> Function() onAuthenticationLost;

  /// Guards against a burst of parallel 401s each firing its own refresh.
  Future<String?>? _inFlightRefresh;

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    if (options.extra[skipAuthKey] != true) {
      final token = await _storage.readAccessToken();
      if (token != null) {
        options.headers['Authorization'] = 'Bearer $token';
      }
    }
    handler.next(options);
  }

  @override
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    final isUnauthorised = err.response?.statusCode == 401;
    final isRetryable =
        isUnauthorised &&
        err.requestOptions.extra[skipAuthKey] != true &&
        err.requestOptions.extra[_retriedKey] != true;

    if (!isRetryable) {
      return handler.next(err);
    }

    final newToken = await _refreshAccessToken();
    if (newToken == null) {
      await onAuthenticationLost();
      return handler.next(err);
    }

    try {
      final request = err.requestOptions;
      request.headers['Authorization'] = 'Bearer $newToken';
      request.extra[_retriedKey] = true;

      final response = await _retryClient.fetch(request);
      return handler.resolve(response);
    } on DioException catch (retryError) {
      return handler.next(retryError);
    }
  }

  /// Returns a fresh access token, or null when the session is unrecoverable.
  Future<String?> _refreshAccessToken() {
    // Everyone who arrives while a refresh is running awaits the same future.
    return _inFlightRefresh ??= _performRefresh().whenComplete(() {
      _inFlightRefresh = null;
    });
  }

  Future<String?> _performRefresh() async {
    final refreshToken = await _storage.readRefreshToken();
    if (refreshToken == null) {
      return null;
    }

    try {
      final response = await _refreshClient.post<Map<String, dynamic>>(
        ApiConstants.authRefresh,
        data: {'refresh': refreshToken},
      );

      final access = response.data?['access'] as String?;
      if (access == null) {
        return null;
      }

      // ROTATE_REFRESH_TOKENS is on server-side, so a new refresh token may
      // come back with it. Persist it or the next refresh will fail.
      final rotated = response.data?['refresh'] as String?;
      if (rotated != null) {
        await _storage.saveTokens(access: access, refresh: rotated);
      } else {
        await _storage.saveAccessToken(access);
      }

      return access;
    } on DioException {
      // Expired or rejected refresh token - the user has to sign in again.
      return null;
    }
  }

  /// Marks a request that must go out unauthenticated (login, register,
  /// refresh, health).
  static const String skipAuthKey = 'skipAuth';
  static const String _retriedKey = 'retriedAfterRefresh';

  /// Convenience for building those requests.
  static Options get unauthenticated =>
      Options(extra: const {skipAuthKey: true});
}
