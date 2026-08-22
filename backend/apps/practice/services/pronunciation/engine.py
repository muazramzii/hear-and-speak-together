"""The pronunciation engine: turns a transcript into a score.

Whisper answers "what did the model think was said". This module answers
"how well was it said" - the two questions this project has kept
deliberately separate since Phase 4, when the same principle applied to
Azure and the LLM feedback layer. Nothing here calls an LLM and nothing here
is a network call; every number is derived from the reference word, the
recognised text, and Whisper's own confidence signal.

No prosody metric exists in this architecture - Whisper and a text-level
phonetic comparison have no acoustic signal to derive stress, intonation or
rhythm from, so the field simply is not part of this result. That is more
honest than the alternative available to a from-scratch engine: not having a
metric, rather than fabricating one.
"""

import logging
from dataclasses import dataclass, field

from django.conf import settings

from .error_detection import PronunciationError, detect_errors
from .g2p_english import EnglishG2P
from .g2p_malay import MalayG2P
from .phonetic_distance import PhoneticDistance

logger = logging.getLogger(__name__)

DEFAULT_WEIGHTS = {"similarity": 0.5, "confidence": 0.3, "completeness": 0.2}


@dataclass(frozen=True)
class PronunciationEngineResult:
    reference_text: str
    recognized_text: str
    language_code: str

    pronunciation_score: int  # 0-100, the weighted final score
    similarity_score: float  # phonetic-feature similarity, 0-100
    confidence_score: float  # from Whisper, 0-100
    completeness_score: float  # 0-100

    errors: list[PronunciationError] = field(default_factory=list)


class PronunciationEngine:
    """Deterministic and swappable: nothing here is an LLM call, so the same
    engine instance is used in tests as in production - unlike the speech
    recognition stage, there is no separate mock implementation, because
    there is nothing external to mock."""

    def __init__(self, *, weights=None):
        self._weights = weights or getattr(
            settings, "PRONUNCIATION_SCORE_WEIGHTS", DEFAULT_WEIGHTS
        )
        self._g2p = {"en": EnglishG2P(), "ms": MalayG2P()}

    def evaluate(self, *, reference_text, recognized_text, confidence, language_code):
        g2p = self._g2p.get(language_code)
        if g2p is None:
            raise ValueError(f"No G2P available for language {language_code!r}")

        reference_phonemes = g2p.phonemes(reference_text)
        spoken_phonemes = g2p.phonemes(recognized_text)

        similarity = PhoneticDistance.get().similarity(
            "".join(reference_phonemes), "".join(spoken_phonemes)
        )
        completeness = self._completeness(reference_phonemes, spoken_phonemes)
        confidence_score = 0.0 if confidence is None else float(confidence)

        final = (
            self._weights["similarity"] * similarity
            + self._weights["confidence"] * confidence_score
            + self._weights["completeness"] * completeness
        )
        final = max(0, min(100, round(final)))

        errors = detect_errors(reference_phonemes, spoken_phonemes)

        return PronunciationEngineResult(
            reference_text=reference_text,
            recognized_text=recognized_text,
            language_code=language_code,
            pronunciation_score=final,
            similarity_score=similarity,
            confidence_score=confidence_score,
            completeness_score=completeness,
            errors=errors,
        )

    @staticmethod
    def _completeness(reference_phonemes, spoken_phonemes):
        """How much of the reference word's sound content shows up in what
        was spoken, as a fraction of expected length. A child who trails off
        mid-word produces fewer phonemes than the target, which this
        penalises; a longer-than-expected utterance is capped at 100 rather
        than rewarded, since padding is not completeness."""
        if not reference_phonemes:
            return 0.0
        ratio = len(spoken_phonemes) / len(reference_phonemes)
        return round(min(1.0, ratio) * 100, 1)
