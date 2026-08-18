import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:hear_speak_together/core/network/api_exception.dart';
import 'package:hear_speak_together/core/network/auth_events.dart';
import 'package:hear_speak_together/models/auth_session.dart';
import 'package:hear_speak_together/models/user.dart';
import 'package:hear_speak_together/providers/auth_provider.dart';
import 'package:hear_speak_together/repositories/auth_repository.dart';

const _user = User(
  id: 1,
  name: 'Amir Rahman',
  email: 'amir@example.com',
  role: UserRole.student,
  preferredLanguage: AppLanguage.malay,
);

/// In-memory stand-in so no test touches the network or secure storage.
class _FakeAuthRepository implements AuthRepository {
  _FakeAuthRepository({this.storedSession = false});

  bool storedSession;
  bool loggedOut = false;
  User? meResult = _user;
  ApiException? meError;
  ApiException? loginError;
  AuthSession? loginResult;

  @override
  Future<bool> hasStoredSession() async => storedSession;

  @override
  Future<User> fetchCurrentUser() async {
    if (meError != null) throw meError!;
    return meResult!;
  }

  @override
  Future<AuthSession> login({
    required String email,
    required String password,
  }) async {
    if (loginError != null) throw loginError!;
    return loginResult ??
        const AuthSession(user: _user, accessToken: 'a', refreshToken: 'r');
  }

  @override
  Future<AuthSession> register({
    required String name,
    required String email,
    required String password,
    required String passwordConfirm,
    required UserRole role,
    required AppLanguage preferredLanguage,
  }) async {
    if (loginError != null) throw loginError!;
    return const AuthSession(
      user: _user,
      accessToken: 'a',
      refreshToken: 'r',
    );
  }

  @override
  Future<void> logout() async {
    loggedOut = true;
    storedSession = false;
  }

  @override
  Future<User> updateProfile({
    String? name,
    AppLanguage? preferredLanguage,
  }) async {
    return _user.copyWith(name: name, preferredLanguage: preferredLanguage);
  }
}

AuthController _controllerFor(
  _FakeAuthRepository repository, {
  StreamController<AuthEvent>? events,
}) {
  return AuthController(
    repository: repository,
    events: (events ?? StreamController<AuthEvent>.broadcast()).stream,
  );
}

void main() {
  group('session restore', () {
    test('resolves to unauthenticated when no token is stored', () async {
      final controller = _controllerFor(
        _FakeAuthRepository(storedSession: false),
      );
      await pumpEventQueue();

      expect(controller.state.status, AuthStatus.unauthenticated);
      expect(controller.state.user, isNull);
    });

    test('restores the user when a stored token is still valid', () async {
      final controller = _controllerFor(
        _FakeAuthRepository(storedSession: true),
      );
      await pumpEventQueue();

      expect(controller.state.status, AuthStatus.authenticated);
      expect(controller.state.user?.email, 'amir@example.com');
    });

    test('discards an unusable stored token instead of hanging', () async {
      final repository = _FakeAuthRepository(storedSession: true)
        ..meError = const ApiException(
          kind: ApiErrorKind.server,
          message: 'nope',
          statusCode: 401,
        );

      final controller = _controllerFor(repository);
      await pumpEventQueue();

      expect(controller.state.status, AuthStatus.unauthenticated);
      expect(repository.loggedOut, isTrue);
    });
  });

  group('login', () {
    test('authenticates and stores the user on success', () async {
      final controller = _controllerFor(_FakeAuthRepository());
      await pumpEventQueue();

      final ok = await controller.login(
        email: 'amir@example.com',
        password: 'TeaCup!2026',
      );

      expect(ok, isTrue);
      expect(controller.state.status, AuthStatus.authenticated);
      expect(controller.state.isSubmitting, isFalse);
    });

    test('reports bad credentials in child-friendly wording', () async {
      final repository = _FakeAuthRepository()
        ..loginError = const ApiException(
          kind: ApiErrorKind.server,
          message: 'You are not signed in.',
          statusCode: 401,
        );
      final controller = _controllerFor(repository);
      await pumpEventQueue();

      final ok = await controller.login(
        email: 'amir@example.com',
        password: 'wrong',
      );

      expect(ok, isFalse);
      expect(controller.state.status, isNot(AuthStatus.authenticated));
      expect(
        controller.state.errorMessage,
        'That email or password is not right. Please try again.',
      );
    });

    test('surfaces a network failure rather than a credentials error', () async {
      final repository = _FakeAuthRepository()
        ..loginError = const ApiException(
          kind: ApiErrorKind.network,
          message: 'Could not reach the server.',
        );
      final controller = _controllerFor(repository);
      await pumpEventQueue();

      await controller.login(email: 'a@b.com', password: 'x');

      expect(controller.state.errorMessage, 'Could not reach the server.');
    });

    test('clearError removes a stale message', () async {
      final repository = _FakeAuthRepository()
        ..loginError = const ApiException(
          kind: ApiErrorKind.server,
          message: 'bad',
          statusCode: 401,
        );
      final controller = _controllerFor(repository);
      await pumpEventQueue();
      await controller.login(email: 'a@b.com', password: 'x');

      controller.clearError();

      expect(controller.state.errorMessage, isNull);
    });
  });

  group('registration', () {
    test('prefers the server field error over the generic message', () async {
      final repository = _FakeAuthRepository()
        ..loginError = const ApiException(
          kind: ApiErrorKind.server,
          message: 'Something went wrong. Please try again.',
          statusCode: 400,
          fieldErrors: {
            'email': ['An account with this email already exists.'],
          },
        );
      final controller = _controllerFor(repository);
      await pumpEventQueue();

      final ok = await controller.register(
        name: 'Amir',
        email: 'amir@example.com',
        password: 'TeaCup!2026',
        passwordConfirm: 'TeaCup!2026',
        role: UserRole.student,
        preferredLanguage: AppLanguage.english,
      );

      expect(ok, isFalse);
      expect(
        controller.state.errorMessage,
        'An account with this email already exists.',
      );
    });
  });

  group('logout and session expiry', () {
    test('logout clears the user and the tokens', () async {
      final repository = _FakeAuthRepository(storedSession: true);
      final controller = _controllerFor(repository);
      await pumpEventQueue();

      await controller.logout();

      expect(controller.state.status, AuthStatus.unauthenticated);
      expect(controller.state.user, isNull);
      expect(repository.loggedOut, isTrue);
    });

    test('a sessionExpired event signs the user out with an explanation', () async {
      final events = StreamController<AuthEvent>.broadcast();
      final controller = _controllerFor(
        _FakeAuthRepository(storedSession: true),
        events: events,
      );
      await pumpEventQueue();
      expect(controller.state.status, AuthStatus.authenticated);

      events.add(AuthEvent.sessionExpired);
      await pumpEventQueue();

      expect(controller.state.status, AuthStatus.unauthenticated);
      expect(controller.state.user, isNull);
      expect(
        controller.state.errorMessage,
        'Your session has ended. Please sign in again.',
      );

      await events.close();
    });
  });
}
