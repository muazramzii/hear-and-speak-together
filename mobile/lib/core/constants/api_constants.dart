/// Base configuration for talking to the Django backend.
///
/// The host differs per run target, so it is supplied at build time:
///
///   flutter run --dart-define=API_BASE_URL=http://192.168.1.5:8000/api
///
/// When nothing is supplied, the default targets the Android emulator, where
/// `10.0.2.2` is an alias for the host machine's `localhost`.
class ApiConstants {
  const ApiConstants._();

  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://10.0.2.2:8000/api',
  );

  /// Endpoints.
  static const String health = '/health/';

  static const String authRegister = '/auth/register/';
  static const String authLogin = '/auth/login/';
  static const String authRefresh = '/auth/refresh/';
  static const String authMe = '/auth/me/';

  /// Timeouts. Speech uploads in later phases need a longer receive window,
  /// so these are deliberately generous rather than snappy.
  static const Duration connectTimeout = Duration(seconds: 10);
  static const Duration receiveTimeout = Duration(seconds: 20);
  static const Duration sendTimeout = Duration(seconds: 20);
}
