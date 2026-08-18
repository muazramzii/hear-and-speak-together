import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Things that can happen to a session outside of a user action.
enum AuthEvent {
  /// The refresh token was missing, expired or rejected. The user must sign
  /// in again.
  sessionExpired,
}

/// A one-way channel from the networking layer up to the auth controller.
///
/// The interceptor cannot simply call the auth controller: the controller
/// depends on the Dio client, so reaching back down would make the two
/// providers depend on each other. This stream has no dependencies of its
/// own, which breaks the cycle.
final authEventsProvider = Provider<StreamController<AuthEvent>>((ref) {
  final controller = StreamController<AuthEvent>.broadcast();
  ref.onDispose(controller.close);
  return controller;
});
