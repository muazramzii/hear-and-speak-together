import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../providers/locale_provider.dart';

/// One Quiz/Listen result that could not reach the server yet.
class PendingQuizSubmission {
  const PendingQuizSubmission({
    required this.profileId,
    required this.lessonId,
    required this.mode,
    required this.correctCount,
    required this.totalRounds,
  });

  final int profileId;
  final int lessonId;
  final String mode;
  final int correctCount;
  final int totalRounds;

  Map<String, dynamic> toJson() => {
    'profile_id': profileId,
    'lesson_id': lessonId,
    'mode': mode,
    'correct_count': correctCount,
    'total_rounds': totalRounds,
  };

  factory PendingQuizSubmission.fromJson(Map<String, dynamic> json) {
    return PendingQuizSubmission(
      profileId: json['profile_id'] as int,
      lessonId: json['lesson_id'] as int,
      mode: json['mode'] as String,
      correctCount: json['correct_count'] as int,
      totalRounds: json['total_rounds'] as int,
    );
  }
}

/// Holds Quiz/Listen results that failed to submit while offline, so they
/// can be replayed once the connection returns - "queue progress updates
/// when offline" from the Phase 5 brief, scoped deliberately to this one
/// kind of update.
///
/// Pronunciation attempts (Speak) are *not* queued here: the recording is
/// discarded immediately after each attempt (by the existing, frozen
/// practice flow) whether it succeeded or not, so by the time a retry could
/// run there would be no audio left to send - and the child needs their
/// score the moment they stop speaking, not minutes later when the network
/// happens to return. A quiz tally, in contrast, is a handful of numbers
/// with nothing to lose by waiting.
class PendingQuizQueue {
  PendingQuizQueue(this._preferences);

  final Future<SharedPreferences> _preferences;

  static const _key = 'offline_cache.pending_quiz_results';

  Future<List<PendingQuizSubmission>> read() async {
    final prefs = await _preferences;
    final raw = prefs.getStringList(_key) ?? const [];
    return raw
        .map(
          (item) => PendingQuizSubmission.fromJson(
            (jsonDecode(item) as Map).cast<String, dynamic>(),
          ),
        )
        .toList();
  }

  Future<void> enqueue(PendingQuizSubmission submission) async {
    final prefs = await _preferences;
    final raw = prefs.getStringList(_key) ?? const [];
    await prefs.setStringList(_key, [...raw, jsonEncode(submission.toJson())]);
  }

  Future<void> _writeAll(List<PendingQuizSubmission> submissions) async {
    final prefs = await _preferences;
    await prefs.setStringList(
      _key,
      submissions.map((s) => jsonEncode(s.toJson())).toList(),
    );
  }

  /// Attempts every queued submission via [submit], keeping whichever ones
  /// still fail (in order) for the next attempt. A submission that fails
  /// stops the run rather than being skipped over - replaying out of order
  /// is worse than waiting for the next connectivity change to try again.
  Future<void> flush(
    Future<void> Function(PendingQuizSubmission submission) submit,
  ) async {
    final pending = await read();
    if (pending.isEmpty) return;

    var index = 0;
    try {
      for (; index < pending.length; index++) {
        await submit(pending[index]);
      }
    } catch (_) {
      // Whatever is left, including the one that just failed, stays queued.
      await _writeAll(pending.sublist(index));
      return;
    }
    await _writeAll(const []);
  }
}

final pendingQuizQueueProvider = Provider<PendingQuizQueue>((ref) {
  return PendingQuizQueue(ref.watch(sharedPreferencesProvider));
});
