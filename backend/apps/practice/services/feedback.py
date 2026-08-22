"""Deterministic feedback.

Always available, no model call, no cost, nothing that can be down. An
optional LLM layer may rephrase this later (see `services/ai/`), but it never
touches the score - the number always comes from the pronunciation engine -
and the app must keep working exactly like this if that layer is disabled or
fails.

Written in the language being practised, because a Malay learner should not
be praised in English.
"""

from apps.accounts.models import LanguageCode

# Band thresholds are inclusive lower bounds.
_BANDS = [
    (90, "excellent"),
    (75, "good"),
    (50, "fair"),
    (0, "keep_trying"),
]

_MESSAGES = {
    LanguageCode.ENGLISH: {
        "excellent": "Excellent! Your pronunciation is very clear!",
        "good": "Great job! You're very close.",
        "fair": "Nice try! Listen again and say it slowly.",
        "keep_trying": "Let's practice together. You can do it!",
        "no_speech": "We could not hear anything. Try again and speak clearly.",
    },
    LanguageCode.MALAY: {
        "excellent": "Cemerlang! Sebutan anda sangat jelas!",
        "good": "Syabas! Sebutan anda hampir tepat.",
        "fair": "Bagus dicuba! Dengar sekali lagi dan sebut perlahan-lahan.",
        "keep_trying": "Jom kita berlatih bersama. Anda pasti boleh!",
        "no_speech": "Kami tidak dapat mendengar apa-apa. Cuba lagi dan sebut dengan jelas.",
    },
}


def _messages_for(language_code):
    return _MESSAGES.get(language_code, _MESSAGES[LanguageCode.ENGLISH])


def band_for_score(score):
    for threshold, band in _BANDS:
        if score >= threshold:
            return band
    return "keep_trying"


def build_feedback(score, language_code):
    """The one headline sentence for a pronunciation score."""
    return _messages_for(language_code)[band_for_score(score)]


def no_speech_feedback(language_code):
    return _messages_for(language_code)["no_speech"]


def points_for_score(score):
    """Stars awarded for an attempt.

    Deliberately generous at the bottom: a child who tried and scored poorly
    still earns something, because zero reward for effort discourages the
    exact behaviour the app wants.
    """
    if score is None:
        return 0
    if score >= 90:
        return 10
    if score >= 75:
        return 7
    if score >= 50:
        return 4
    return 2
