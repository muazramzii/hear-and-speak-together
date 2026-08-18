import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/network/api_exception.dart';
import '../core/network/auth_events.dart';
import '../models/user.dart';
import '../repositories/auth_repository.dart';

/// Where the app is in the sign-in lifecycle.
enum AuthStatus {
  /// Still deciding - a stored token is being checked. The splash screen
  /// shows during this.
  unknown,
  authenticated,
  unauthenticated,
}

class AuthState {
  const AuthState({
    this.status = AuthStatus.unknown,
    this.user,
    this.isSubmitting = false,
    this.errorMessage,
  });

  final AuthStatus status;
  final User? user;

  /// True while a login or register request is in flight, so the form can
  /// disable its button and show a spinner.
  final bool isSubmitting;

  /// Set when a sign-in attempt fails. Always safe to show to a user.
  final String? errorMessage;

  bool get isAuthenticated => status == AuthStatus.authenticated;
  bool get isResolved => status != AuthStatus.unknown;

  AuthState copyWith({
    AuthStatus? status,
    User? user,
    bool? isSubmitting,
    String? errorMessage,
    bool clearError = false,
    bool clearUser = false,
  }) {
    return AuthState(
      status: status ?? this.status,
      user: clearUser ? null : (user ?? this.user),
      isSubmitting: isSubmitting ?? this.isSubmitting,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }
}

class AuthController extends StateNotifier<AuthState> {
  AuthController({
    required AuthRepository repository,
    required Stream<AuthEvent> events,
  }) : _repository = repository,
       super(const AuthState()) {
    _eventSubscription = events.listen((event) {
      if (event == AuthEvent.sessionExpired) {
        _handleSessionExpired();
      }
    });
    unawaited(restoreSession());
  }

  final AuthRepository _repository;
  late final StreamSubscription<AuthEvent> _eventSubscription;

  /// Called once at startup. Turns a stored refresh token back into a live
  /// session, so a returning child does not have to sign in every time.
  Future<void> restoreSession() async {
    if (!await _repository.hasStoredSession()) {
      state = state.copyWith(status: AuthStatus.unauthenticated);
      return;
    }

    try {
      final user = await _repository.fetchCurrentUser();
      state = state.copyWith(status: AuthStatus.authenticated, user: user);
    } on ApiException {
      // The stored token is unusable. Drop it and start clean rather than
      // leaving the app stuck on the splash screen.
      await _repository.logout();
      state = state.copyWith(
        status: AuthStatus.unauthenticated,
        clearUser: true,
      );
    }
  }

  Future<bool> login({required String email, required String password}) async {
    state = state.copyWith(isSubmitting: true, clearError: true);

    try {
      final session = await _repository.login(
        email: email,
        password: password,
      );
      state = state.copyWith(
        status: AuthStatus.authenticated,
        user: session.user,
        isSubmitting: false,
      );
      return true;
    } on ApiException catch (error) {
      state = state.copyWith(
        isSubmitting: false,
        errorMessage: _signInMessage(error),
      );
      return false;
    }
  }

  Future<bool> register({
    required String name,
    required String email,
    required String password,
    required String passwordConfirm,
    required UserRole role,
    required AppLanguage preferredLanguage,
  }) async {
    state = state.copyWith(isSubmitting: true, clearError: true);

    try {
      final session = await _repository.register(
        name: name,
        email: email,
        password: password,
        passwordConfirm: passwordConfirm,
        role: role,
        preferredLanguage: preferredLanguage,
      );
      state = state.copyWith(
        status: AuthStatus.authenticated,
        user: session.user,
        isSubmitting: false,
      );
      return true;
    } on ApiException catch (error) {
      state = state.copyWith(
        isSubmitting: false,
        errorMessage: error.fieldMessage ?? error.message,
      );
      return false;
    }
  }

  Future<void> logout() async {
    await _repository.logout();
    state = const AuthState(status: AuthStatus.unauthenticated);
  }

  Future<void> updateProfile({
    String? name,
    AppLanguage? preferredLanguage,
  }) async {
    final updated = await _repository.updateProfile(
      name: name,
      preferredLanguage: preferredLanguage,
    );
    state = state.copyWith(user: updated);
  }

  void clearError() => state = state.copyWith(clearError: true);

  void _handleSessionExpired() {
    state = const AuthState(
      status: AuthStatus.unauthenticated,
      errorMessage: 'Your session has ended. Please sign in again.',
    );
  }

  /// A 401 during sign-in means bad credentials, not an expired session, so
  /// the generic "please sign in" wording would be confusing here.
  String _signInMessage(ApiException error) {
    if (error.statusCode == 401) {
      return 'That email or password is not right. Please try again.';
    }
    return error.fieldMessage ?? error.message;
  }

  @override
  void dispose() {
    _eventSubscription.cancel();
    super.dispose();
  }
}

final authControllerProvider =
    StateNotifierProvider<AuthController, AuthState>((ref) {
      return AuthController(
        repository: ref.watch(authRepositoryProvider),
        events: ref.watch(authEventsProvider).stream,
      );
    });

/// The signed-in user, or null. Convenience for widgets that only need this.
final currentUserProvider = Provider<User?>((ref) {
  return ref.watch(authControllerProvider).user;
});
