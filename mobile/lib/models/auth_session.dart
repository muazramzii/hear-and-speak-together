import 'user.dart';

/// What `/auth/login/` and `/auth/register/` return: the user plus the JWT pair.
class AuthSession {
  const AuthSession({
    required this.user,
    required this.accessToken,
    required this.refreshToken,
  });

  final User user;
  final String accessToken;
  final String refreshToken;

  factory AuthSession.fromJson(Map<String, dynamic> json) {
    return AuthSession(
      user: User.fromJson(json['user'] as Map<String, dynamic>),
      accessToken: json['access'] as String,
      refreshToken: json['refresh'] as String,
    );
  }
}
