import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../repositories/practice_repository.dart';
import 'connectivity_provider.dart';

/// Auto-syncs whatever the offline queue is holding as soon as connectivity
/// comes back - "auto-sync when internet returns" from the Phase 5 brief.
///
/// A `Provider` rather than anything UI-facing: it does nothing on its own
/// except exist, so [activate] just needs to be read once (see
/// `main.dart`) to start the listener for the rest of the app's lifetime.
/// It reacts only to the offline->online transition, not to every
/// connectivity event, so it does not re-flush an already-empty queue on
/// every Wi-Fi blip.
class SyncCoordinator {
  SyncCoordinator(this._ref) {
    _ref.listen<AsyncValue<bool>>(connectivityProvider, (previous, next) {
      final wasOffline = previous?.valueOrNull == false;
      final isOnlineNow = next.valueOrNull == true;
      if (wasOffline && isOnlineNow) {
        _ref.read(practiceRepositoryProvider).flushPendingQuizResults();
      }
    });
  }

  final Ref _ref;
}

final syncCoordinatorProvider = Provider<SyncCoordinator>((ref) {
  return SyncCoordinator(ref);
});

/// Reading this anywhere keeps [SyncCoordinator] alive for as long as the
/// provider container is - see its use in `main.dart`.
void activateSyncCoordinator(WidgetRef ref) {
  ref.watch(syncCoordinatorProvider);
}
