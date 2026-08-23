"""Turns Whisper's raw per-segment log-probabilities into a calibrated
0-100 confidence score.

Whisper has no calibrated confidence output. `avg_logprob` is a log
probability - typically close to 0 when the model was sure, more negative
when it was not - and `exp(avg_logprob)` is the standard community proxy for
turning that back into a 0-1 range. Phase 2's own validation (real speech,
synthesised via TTS, against the cached `medium` model) measured that raw
proxy landing consistently in a narrow band - roughly 0.35-0.70 - even for
words Whisper transcribed correctly. Returned as-is, every attempt reads as
"not very confident" regardless of how the word actually went, which is
misleading rather than merely imprecise.

`ConfidenceNormalizer` rescales that observed band across the full 0-100
range so the number actually discriminates between attempts. This is a
**documented heuristic rescale, not a statistically fitted calibration** -
a true calibration would need a labelled dataset pairing confidence against
human-judged pronunciation accuracy on real (non-synthetic) speech, which
this project does not yet have. The bounds below should be revisited once
real human recordings are available (see docs/pronunciation-engine.md and
the Phase 2.5 validation report).

The raw `avg_logprob` value itself is never returned by this class, and
`WhisperSpeechRecognitionService` never exposes it either - only this
module's calibrated 0-100 output leaves the recognition boundary, so it is
the only confidence figure that can ever reach the API or the frontend.
"""

from math import exp


class ConfidenceNormalizer:
    """Stateless by design - a pure function wrapped in a class so it has a
    name of its own to import, test, and eventually recalibrate without
    touching the Whisper adapter around it."""

    # The empirically observed range of exp(avg_logprob) for genuine speech
    # (Phase 2 validation), with a little headroom on each side. Values
    # outside this band still clamp to 0 or 100 rather than extrapolating.
    LOWER_BOUND = 0.35
    UPPER_BOUND = 0.70

    @classmethod
    def normalize(cls, avg_logprobs) -> float:
        """`avg_logprobs`: an iterable of per-segment log probabilities.
        Returns a 0-100 float, or 0.0 for empty input."""
        values = list(avg_logprobs)
        if not values:
            return 0.0

        raw_scores = [exp(value) for value in values]
        mean_raw = sum(raw_scores) / len(raw_scores)

        span = cls.UPPER_BOUND - cls.LOWER_BOUND
        scaled = (mean_raw - cls.LOWER_BOUND) / span
        return round(max(0.0, min(1.0, scaled)) * 100, 1)
