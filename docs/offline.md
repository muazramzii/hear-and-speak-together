# Offline Experience (Phase 5)

What is actually cached, what gets queued and replayed, and - just as
important - what deliberately is not, and why.

---

## What's cached

| Data | Where | Survives app restart? |
| --- | --- | --- |
| Lesson list per language | `OfflineCache` (`SharedPreferences`, JSON) | Yes |
| A learner's progress report (Parent Mode) | `OfflineCache` | Yes |
| Word/lesson illustrations | `cached_network_image`'s disk cache | Yes |

Both `lessonsForLanguageProvider` and `StudentsRepository.fetchStudentProgress`
follow the same shape: fetch live, and on success write the result to
`OfflineCache` in the background (`unawaited`, failure swallowed - caching
must never turn a working request into a failed one). On failure, read
whatever was last cached and return that instead of an error screen,
re-throwing the original `ApiException` only if nothing has ever been
cached. Illustrations are handled at a different layer entirely -
`cached_network_image`, wired into `WordVisual`, gives them a real on-disk
cache with no code in this project managing it directly.

This is deliberately a "last good answer" cache, not a sync engine: there
is no version log, no conflict resolution, and no notion of "stale" beyond
"a live fetch will overwrite it the next time one succeeds." The backend
stays the single source of truth.

## What gets queued while offline

**Quiz/Listen results only.** `PracticeRepository.submitQuizResult` queues
the tally (profile, lesson, mode, correct count, total rounds - a few
integers, `PendingQuizQueue`) when a submission fails with no server
response at all (a real connectivity failure, not a 4xx/5xx the server
actually answered). `SyncCoordinator` listens for the offline→online
transition (`connectivity_plus`) and replays the queue automatically,
in order, keeping whatever is left queued if one submission still fails.

The call site (`ChoiceSessionController`, in the frozen lesson-logic
layer) is completely unaware of any of this: `submitQuizResult` still
throws the exact same `ApiException` it always did on failure, which that
controller already catches and swallows ("the score is lost, not the
session" - see its own docstring). Queuing just means the score usually
is not lost after all, without that frozen code needing to change at all.

## What is *not* queued, on purpose

**Pronunciation attempts (Speak) are never queued.** Two independent
reasons, either one sufficient on its own:

1. The recorded audio file is deleted immediately after every attempt -
   success or failure - by the existing, frozen practice flow
   (`AudioRecorderService.discard()`, called unconditionally in
   `PracticeController.stopAndEvaluate`'s `finally` block). By the time a
   retry could run, there is no audio left to send.
2. Even if the audio survived, deferring the result would break the
   feature itself: a child taps the mic expecting to hear how they did
   *right then*. A "your score will arrive later" queue is not a degraded
   version of that interaction - it is a different, worse one.

A child who tries to speak while offline sees the existing "could not
reach the server" failure state (unchanged, frozen) rather than a silent
queue that never delivers the feedback the whole interaction is built
around.

## Verifying it

There is no reliable way to force "airplane mode" in this environment, so
this was verified by reading through the fallback and queue logic and unit
testing `OfflineCache` and `PendingQuizQueue` directly (`test/offline/`) -
including a submission that fails mid-flush leaving the right items
requeued in the right order. It has not been exercised end-to-end against
a real dropped Wi-Fi connection on a device; that is worth doing once
before a release.
