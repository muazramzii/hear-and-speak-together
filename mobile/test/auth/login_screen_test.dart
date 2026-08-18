import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hear_speak_together/core/network/api_exception.dart';
import 'package:hear_speak_together/features/auth/login_screen.dart';
import 'package:hear_speak_together/models/auth_session.dart';
import 'package:hear_speak_together/models/user.dart';
import 'package:hear_speak_together/repositories/auth_repository.dart';

const _user = User(
  id: 1,
  name: 'Amir',
  email: 'amir@example.com',
  role: UserRole.student,
  preferredLanguage: AppLanguage.english,
);

class _FakeAuthRepository implements AuthRepository {
  ApiException? loginError;
  Completer<AuthSession>? pending;
  ({String email, String password})? lastCredentials;

  @override
  Future<bool> hasStoredSession() async => false;

  @override
  Future<User> fetchCurrentUser() async => _user;

  @override
  Future<AuthSession> login({
    required String email,
    required String password,
  }) {
    lastCredentials = (email: email, password: password);
    if (loginError != null) return Future.error(loginError!);
    if (pending != null) return pending!.future;
    return Future.value(
      const AuthSession(user: _user, accessToken: 'a', refreshToken: 'r'),
    );
  }

  @override
  Future<AuthSession> register({
    required String name,
    required String email,
    required String password,
    required String passwordConfirm,
    required UserRole role,
    required AppLanguage preferredLanguage,
  }) async =>
      const AuthSession(user: _user, accessToken: 'a', refreshToken: 'r');

  @override
  Future<void> logout() async {}

  @override
  Future<User> updateProfile({
    String? name,
    AppLanguage? preferredLanguage,
  }) async => _user;
}

Widget _harness(_FakeAuthRepository repository) {
  return ProviderScope(
    overrides: [authRepositoryProvider.overrideWithValue(repository)],
    child: const MaterialApp(home: LoginScreen()),
  );
}

void main() {
  testWidgets('renders the sign-in form', (tester) async {
    await tester.pumpWidget(_harness(_FakeAuthRepository()));
    await tester.pumpAndSettle();

    expect(find.text('Welcome back!'), findsOneWidget);
    expect(find.text('Email'), findsOneWidget);
    expect(find.text('Password'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Sign In'), findsOneWidget);
  });

  testWidgets('validates empty fields without calling the API', (tester) async {
    final repository = _FakeAuthRepository();
    await tester.pumpWidget(_harness(repository));
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(FilledButton, 'Sign In'));
    await tester.pumpAndSettle();

    expect(find.text('Please enter your email.'), findsOneWidget);
    expect(find.text('Please enter your password.'), findsOneWidget);
    expect(repository.lastCredentials, isNull);
  });

  testWidgets('rejects an address with no @', (tester) async {
    await tester.pumpWidget(_harness(_FakeAuthRepository()));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextFormField).first, 'not-an-email');
    await tester.enterText(find.byType(TextFormField).last, 'TeaCup!2026');
    await tester.tap(find.widgetWithText(FilledButton, 'Sign In'));
    await tester.pumpAndSettle();

    expect(find.text('Please enter a valid email address.'), findsOneWidget);
  });

  testWidgets('submits the typed credentials', (tester) async {
    final repository = _FakeAuthRepository();
    await tester.pumpWidget(_harness(repository));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byType(TextFormField).first,
      'amir@example.com',
    );
    await tester.enterText(find.byType(TextFormField).last, 'TeaCup!2026');
    await tester.tap(find.widgetWithText(FilledButton, 'Sign In'));
    await tester.pumpAndSettle();

    expect(repository.lastCredentials?.email, 'amir@example.com');
    expect(repository.lastCredentials?.password, 'TeaCup!2026');
  });

  testWidgets('shows a busy state while the request is in flight', (
    tester,
  ) async {
    final repository = _FakeAuthRepository()..pending = Completer();
    await tester.pumpWidget(_harness(repository));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byType(TextFormField).first,
      'amir@example.com',
    );
    await tester.enterText(find.byType(TextFormField).last, 'TeaCup!2026');
    await tester.tap(find.widgetWithText(FilledButton, 'Sign In'));
    await tester.pump();

    expect(find.text('Signing in...'), findsOneWidget);

    repository.pending!.complete(
      const AuthSession(user: _user, accessToken: 'a', refreshToken: 'r'),
    );
    await tester.pumpAndSettle();
  });

  testWidgets('shows the server error as visible text', (tester) async {
    final repository = _FakeAuthRepository()
      ..loginError = const ApiException(
        kind: ApiErrorKind.server,
        message: 'You are not signed in.',
        statusCode: 401,
      );
    await tester.pumpWidget(_harness(repository));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byType(TextFormField).first,
      'amir@example.com',
    );
    await tester.enterText(find.byType(TextFormField).last, 'wrong');
    await tester.tap(find.widgetWithText(FilledButton, 'Sign In'));
    await tester.pumpAndSettle();

    expect(
      find.text('That email or password is not right. Please try again.'),
      findsOneWidget,
    );
  });

  testWidgets('password is obscured until the reveal button is tapped', (
    tester,
  ) async {
    await tester.pumpWidget(_harness(_FakeAuthRepository()));
    await tester.pumpAndSettle();

    EditableText passwordField() => tester.widget<EditableText>(
      find.byType(EditableText).last,
    );

    expect(passwordField().obscureText, isTrue);

    await tester.tap(find.byTooltip('Show password'));
    await tester.pumpAndSettle();

    expect(passwordField().obscureText, isFalse);
  });
}
