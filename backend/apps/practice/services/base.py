"""The pronunciation assessment boundary.

Business logic depends on `PronunciationAssessmentResult` - our own shape -
rather than on whatever Azure happens to return. That keeps an Azure API
change confined to one adapter, and makes the mock used in tests a genuine
drop-in rather than a special case threaded through the codebase.
"""

from abc import ABC, abstractmethod
from dataclasses import dataclass, field


class AssessmentError(Exception):
    """Assessment could not be completed.

    `user_message` is safe to show a child; `detail` is for the server log
    only and must never reach the client.
    """

    def __init__(self, user_message, detail=None, *, retryable=True):
        super().__init__(detail or user_message)
        self.user_message = user_message
        self.detail = detail
        self.retryable = retryable


class NoSpeechDetected(AssessmentError):
    """The recording contained no recognisable speech.

    Not a failure of the system - a very common, very normal thing for a
    child to do - so it is handled as a result, not an error.
    """

    def __init__(self):
        super().__init__(
            user_message="We could not hear anything. Try again and speak clearly.",
            detail="Azure returned NoMatch",
        )


@dataclass
class WordResult:
    """Per-word detail. `error_type` is Azure's own vocabulary:
    None, Omission, Insertion, Mispronunciation."""

    word: str
    accuracy_score: float | None = None
    error_type: str | None = None


@dataclass
class PronunciationAssessmentResult:
    """The normalised result the rest of the application works with.

    Every score is optional. A locale that does not support a metric returns
    `None`, and `None` must be rendered as "not measured" - never as zero, and
    never quietly replaced with a plausible number.
    """

    language_code: str
    locale: str
    reference_text: str
    recognized_text: str

    accuracy_score: float | None = None
    fluency_score: float | None = None
    pronunciation_score: float | None = None
    completeness_score: float | None = None
    prosody_score: float | None = None

    error_type: str | None = None
    words: list[WordResult] = field(default_factory=list)

    @property
    def display_score(self):
        """The single number shown to the child.

        Azure's `PronScore` is the composite it calculates itself, weighing
        whichever sub-scores were available, so it is preferred. Accuracy is
        the fallback when a locale or a failure path leaves it unset.
        """
        if self.pronunciation_score is not None:
            return round(self.pronunciation_score)
        if self.accuracy_score is not None:
            return round(self.accuracy_score)
        return None

    @property
    def measured_metrics(self):
        """Only the metrics that actually came back with a value."""
        candidates = {
            "accuracy": self.accuracy_score,
            "fluency": self.fluency_score,
            "completeness": self.completeness_score,
            "pronunciation": self.pronunciation_score,
            "prosody": self.prosody_score,
        }
        return {name: value for name, value in candidates.items() if value is not None}


class PronunciationAssessmentService(ABC):
    """Scores speech against a known reference word.

    Implementations must never invent a score. If a metric is unavailable for
    the locale, leave it `None`.
    """

    @abstractmethod
    def assess(self, *, audio, reference_text, language_code, locale, enable_prosody):
        """Return a `PronunciationAssessmentResult`.

        `audio` is a file-like object positioned at the start.
        `enable_prosody` is decided by the caller from the Language record's
        verified capability flags, not guessed here.

        Raises `AssessmentError` (or `NoSpeechDetected`) on failure.
        """
        raise NotImplementedError
