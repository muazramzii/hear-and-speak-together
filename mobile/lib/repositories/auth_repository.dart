import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/constants/api_constants.dart';
import '../core/network/api_exception.dart';
import '../core/network/auth_interceptor.dart';
import '../core/network/dio_client.dart';
import '../core/storage/token_storage.dart';
import '../models/auth_session.dart';
import '../models/user.dart';

/// All authentication API access. Nothing above this layer touches Dio.
class AuthRepository {
  const AuthRepository({required Dio dio, required TokenStorage storage})
    : _dio = dio,
      _storage = storage;

  final Dio _dio;
  final TokenStorage _storage;

  Future<AuthSession> register({
    required String name,
    required String email,
    required String password,
    required String passwordConfirm,
    required UserRole role,
    required AppLanguage preferredLanguage,
  }) async {
    return _authenticate(
      ApiConstants.authRegister,
      {
        'name': name.trim(),
        'email': email.trim(),
        'password': password,
        'password_confirm': passwordConfirm,
        'role': role.value,
        'preferred_language': preferredLanguage.code,
      },
    );
  }

  Future<AuthSession> login({
    required String email,
    required String password,
  }) async {
    return _authenticate(ApiConstants.authLogin, {
      'email': email.trim(),
      'password': password,
    });
  }

  Future<AuthSession> _authenticate(
    String path,
    Map<String, dynamic> body,
  ) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        path,
        data: body,
        options: AuthInterceptor.unauthenticated,
      );

      final data = response.data;
      if (data == null) {
        throw const ApiException(
          kind: ApiErrorKind.server,
          message: 'The server sent an unexpected response.',
        );
      }

      final session = AuthSession.fromJson(data);
      await _storage.saveTokens(
        access: session.accessToken,
        refresh: session.refreshToken,
      );
      return session;
    } on DioException catch (error) {
      throw ApiException.fromDio(error);
    }
  }

  /// Reads the signed-in user. Used on app start to turn a stored token back
  /// into a session.
  Future<User> fetchCurrentUser() async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        ApiConstants.authMe,
      );
      return User.fromJson(response.data!);
    } on DioException catch (error) {
      throw ApiException.fromDio(error);
    }
  }

  Future<User> updateProfile({
    String? name,
    AppLanguage? preferredLanguage,
  }) async {
    try {
      final response = await _dio.patch<Map<String, dynamic>>(
        ApiConstants.authMe,
        data: {
          if (name != null) 'name': name.trim(),
          if (preferredLanguage != null)
            'preferred_language': preferredLanguage.code,
        },
      );
      return User.fromJson(response.data!);
    } on DioException catch (error) {
      throw ApiException.fromDio(error);
    }
  }

  /// Signing out is purely local: the tokens are discarded. There is no
  /// server-side blacklist in this build, so a short access-token lifetime is
  /// what limits the window.
  Future<void> logout() => _storage.clear();

  Future<bool> hasStoredSession() => _storage.hasTokens;
}

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository(
    dio: ref.watch(dioProvider),
    storage: ref.watch(tokenStorageProvider),
  );
});
