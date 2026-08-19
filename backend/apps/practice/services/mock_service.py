"""Deterministic stand-in for Azure, used in tests and local development.

Automated tests must never call a paid API: it costs money, needs a key, needs
the network, and makes results depend on a third party. This implementation
returns predictable scores derived from the reference text, so assertions can
be exact.

It is honest about locale limits too - `enable_prosody=False` yields
`prosody_score=None`, exactly as Azure does for ms-MY. A mock that returned a
prosody number for every locale would hide the very bug the capability layer
exists to prevent.
"""

import hashlib

from .base import (
    NoSpeechDetected,
    PronunciationAssessmentResult,
    PronunciationAssessmentService,
    WordResult,
)


class MockPronunciationAssessmentService(PronunciationAssessmentService):
    def __init__(self, *, forced_score=None, simulate_no_speech=False):
        """`forced_score` pins the result for a specific test; otherwise the
        score is derived from the reference text, so it is stable across runs
        but varies between words."""
        self._forced_score = forced_score
        self._simulate_no_speech = simulate_no_speech

    def assess(
        self, *, audio, reference_text, language_code, locale, enable_prosody
    ):
        if self._simulate_no_speech:
            raise NoSpeechDetected()

        # Read the stream so callers behave the same as with the real service.
        audio.read()

        score = self._forced_score
        if score is None:
            digest = hashlib.sha256(reference_text.encode("utf-8")).digest()
            score = 60 + (digest[0] % 41)  # stable, in 60..100

        accuracy = float(score)
        fluency = float(min(100, score + 5))
        completeness = 100.0
        pronunciation = float(score)

        return PronunciationAssessmentResult(
            language_code=language_code,
            locale=locale,
            reference_text=reference_text,
            recognized_text=reference_text if score >= 70 else "",
            accuracy_score=accuracy,
            fluency_score=fluency,
            pronunciation_score=pronunciation,
            completeness_score=completeness,
            # Mirrors Azure: only where the locale supports it.
            prosody_score=float(min(100, score + 2)) if enable_prosody else None,
            error_type=None if score >= 70 else "Mispronunciation",
            words=[
                WordResult(
                    word=reference_text,
                    accuracy_score=accuracy,
                    error_type=None if score >= 70 else "Mispronunciation",
                )
            ],
        )
