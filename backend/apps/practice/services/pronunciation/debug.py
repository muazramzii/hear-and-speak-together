"""Expanded, development-only view into the pronunciation engine.

`PronunciationEngine.evaluate()` (see `engine.py`) returns only what the
child-facing API needs. This module wraps the same building blocks - G2P,
phonetic distance, error detection - and additionally exposes the
intermediate values (phoneme lists, edit-distance op count) that are useful
for debugging the engine itself but have no place in a child's result
screen. It is used only by the developer sandbox endpoint, never by the
production evaluation flow.
"""

from dataclasses import dataclass, field

from .engine import DEFAULT_WEIGHTS, PronunciationEngine
from .error_detection import PronunciationError, align, detect_errors
from .g2p_english import EnglishG2P
from .g2p_malay import MalayG2P
from .phonetic_distance import PhoneticDistance

_G2P = {"en": EnglishG2P(), "ms": MalayG2P()}


@dataclass(frozen=True)
class PronunciationDebugResult:
    reference_text: str
    recognized_text: str
    language_code: str

    reference_phonemes: list[str]
    recognized_phonemes: list[str]
    # Count of non-matching alignment operations (substitute/delete/insert) -
    # a plain edit-distance figure, distinct from the weighted phonetic
    # *feature* distance `similarity_score` is derived from.
    phoneme_edit_distance: int

    similarity_score: float
    confidence_score: float
    completeness_score: float
    pronunciation_score: int
    errors: list[PronunciationError] = field(default_factory=list)

    @property
    def top_error_type(self):
        return self.errors[0].type if self.errors else None


def debug_evaluate(*, reference_text, recognized_text, confidence, language_code, weights=None):
    """Runs the full pronunciation pipeline and returns every intermediate
    value, not just the final score - for the sandbox endpoint only."""
    g2p = _G2P.get(language_code)
    if g2p is None:
        raise ValueError(f"No G2P available for language {language_code!r}")

    reference_phonemes = g2p.phonemes(reference_text)
    recognized_phonemes = g2p.phonemes(recognized_text)

    similarity = PhoneticDistance.get().similarity(
        "".join(reference_phonemes), "".join(recognized_phonemes)
    )
    completeness = PronunciationEngine._completeness(
        reference_phonemes, recognized_phonemes
    )
    confidence_score = 0.0 if confidence is None else float(confidence)

    active_weights = weights or DEFAULT_WEIGHTS
    final = (
        active_weights["similarity"] * similarity
        + active_weights["confidence"] * confidence_score
        + active_weights["completeness"] * completeness
    )
    final = max(0, min(100, round(final)))

    ops = align(reference_phonemes, recognized_phonemes)
    edit_distance = sum(1 for kind, _, _ in ops if kind != "match")
    errors = detect_errors(reference_phonemes, recognized_phonemes)

    return PronunciationDebugResult(
        reference_text=reference_text,
        recognized_text=recognized_text,
        language_code=language_code,
        reference_phonemes=reference_phonemes,
        recognized_phonemes=recognized_phonemes,
        phoneme_edit_distance=edit_distance,
        similarity_score=similarity,
        confidence_score=confidence_score,
        completeness_score=completeness,
        pronunciation_score=final,
        errors=errors,
    )
