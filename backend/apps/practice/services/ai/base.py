"""The AI feedback boundary.

Layer 2 of the feedback design. The LLM's only job is to rephrase an
already-computed result into warmer, more specific encouragement for a child.

It is explicitly **not** responsible for:
  - producing or adjusting any score (that is the pronunciation engine's, always)
  - deciding whether the attempt was good (the score band decides that)
  - being available (every failure falls back to deterministic feedback)

`generate_feedback` returns `None` rather than raising, because a feedback
sentence is a nice-to-have and must never be able to fail an attempt.
"""

from abc import ABC, abstractmethod
from dataclasses import dataclass


@dataclass(frozen=True)
class FeedbackContext:
    """Everything the model is allowed to see.

    Deliberately narrow: no child's name, no email, no account identifier, no
    audio. There is no reason to send personal data to a third party to get a
    sentence about a word.
    """

    target_word: str
    language_code: str
    locale: str
    recognized_text: str
    score: int
    similarity_score: float | None = None
    confidence_score: float | None = None
    error_type: str | None = None

    @property
    def language_name(self):
        return {"en": "English", "ms": "Bahasa Melayu"}.get(
            self.language_code, "English"
        )


class AIService(ABC):
    """Turns a structured assessment into one friendly sentence."""

    @abstractmethod
    def generate_feedback(self, context: FeedbackContext) -> str | None:
        """Return a short encouraging sentence, or None if unavailable.

        Implementations must not raise. A provider being down, slow, or
        misconfigured has to degrade to `None` so the caller can use the
        deterministic message instead.
        """
        raise NotImplementedError


def build_prompt(context: FeedbackContext) -> str:
    """The shared prompt.

    Kept in one place so every provider is judged on the same instructions,
    and so the constraints that matter - short, kind, in the right language,
    never inventing a score - are stated once.
    """
    details = [f"Target word: {context.target_word}"]
    if context.recognized_text:
        details.append(f"The child was heard saying: {context.recognized_text}")
    details.append(f"Overall pronunciation score: {context.score} out of 100")
    if context.similarity_score is not None:
        details.append(f"Similarity to the target word: {round(context.similarity_score)}")
    if context.confidence_score is not None:
        details.append(f"Recognition confidence: {round(context.confidence_score)}")
    if context.error_type:
        details.append(f"Error type: {context.error_type}")

    joined = "\n".join(details)

    return (
        "You are helping a young child practise pronunciation.\n"
        f"Write ONE short sentence of feedback in {context.language_name}.\n\n"
        "Rules:\n"
        "- Maximum 20 words.\n"
        "- Warm, simple and encouraging. The reader is a child.\n"
        "- Never state a number or a score.\n"
        "- If the score is low, stay kind and suggest trying again.\n"
        "- Reply with the sentence only, no quotes and no preamble.\n\n"
        f"Assessment:\n{joined}"
    )


def is_usable(text) -> bool:
    """Guards against a model returning something unsuitable.

    A refusal, an empty string, or a paragraph would all be worse than the
    deterministic sentence, so anything failing this check is discarded.
    """
    if not text:
        return False
    cleaned = text.strip()
    if not (3 <= len(cleaned) <= 300):
        return False
    # A model that ignored "one sentence" is not usable for a child's result
    # screen.
    return cleaned.count("\n") <= 1
