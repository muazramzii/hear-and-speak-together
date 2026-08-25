import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Whether the device currently has *some* network path (Wi-Fi, mobile
/// data, ethernet). Not a guarantee the API is reachable - a captive portal
/// or a down server would still report `true` here - only a cheap, fast
/// signal for "don't even try" versus "worth a request", which is what the
/// offline banner and the sync queue both need.
final connectivityProvider = StreamProvider<bool>((ref) {
  final connectivity = Connectivity();
  return connectivity.onConnectivityChanged.map(
    (results) => !results.contains(ConnectivityResult.none),
  );
});

/// A synchronous best-guess for widgets that cannot wait on the stream's
/// first event (e.g. deciding whether to attempt a fetch right now).
/// Defaults to "online" so a slow first read never blocks a request that
/// would have succeeded.
final isOnlineNowProvider = Provider<bool>((ref) {
  return ref.watch(connectivityProvider).maybeWhen(
    data: (isOnline) => isOnline,
    orElse: () => true,
  );
});
