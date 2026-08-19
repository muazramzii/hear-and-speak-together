"""Deterministic feedback.

Layer 1 of the feedback design: always available, no API call, no cost, and no
dependency on anything that can be down. An optional LLM layer may rephrase
this later, but it never replaces it and never touches the score - the number
always comes from Azure.

Feedback is written in the language the child is practising, because a Malay
learner should not be praised in English.
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
        "good": "Good job! Your pronunciation is getting better!",
        "fair": "Nice try! Listen again and say the word slowly.",
        "keep_trying": "Keep practising! Listen carefully and try again.",
        "no_speech": "We could not hear anything. Try again and speak clearly.",
    },
    LanguageCode.MALAY: {
        "excellent": "Cemerlang! Sebutan anda sangat jelas!",
        "good": "Syabas! Sebutan anda semakin baik!",
        "fair": "Bagus dicuba! Dengar sekali lagi dan sebut perlahan-lahan.",
        "keep_trying": "Teruskan berlatih! Dengar dengan teliti dan cuba lagi.",
        "no_speech": "Kami tidak dapat mendengar apa-apa. Cuba lagi dan sebut dengan jelas.",
    },
}

# Short observations shown as a checklist under the score. Each is tied to a
# metric, so a metric the locale cannot measure simply produces no row - the
# UI never shows an intonation tick for a language Azure does not assess.
_TIPS = {
    LanguageCode.ENGLISH: {
        "accuracy_high": "Clear pronunciation",
        "accuracy_low": "Try saying each sound more clearly",
        "fluency_high": "Smooth and steady",
        "fluency_low": "Try saying it a little more smoothly",
        "prosody_high": "Good intonation",
        "prosody_low": "Try saying it more naturally",
        "completeness_low": "Try saying the whole word",
    },
    LanguageCode.MALAY: {
        "accuracy_high": "Sebutan jelas",
        "accuracy_low": "Cuba sebut setiap bunyi dengan lebih jelas",
        "fluency_high": "Lancar dan sekata",
        "fluency_low": "Cuba sebut dengan lebih lancar",
        "prosody_high": "Intonasi baik",
        "prosody_low": "Cuba sebut dengan lebih semula jadi",
        "completeness_low": "Cuba sebut perkataan itu sepenuhnya",
    },
}

_HIGH = 75


def _messages_for(language_code):
    return _MESSAGES.get(language_code, _MESSAGES[LanguageCode.ENGLISH])


def _tips_for(language_code):
    return _TIPS.get(language_code, _TIPS[LanguageCode.ENGLISH])


def band_for_score(score):
    for threshold, band in _BANDS:
        if score >= threshold:
            return band
    return "keep_trying"


def build_feedback(result):
    """The headline sentence for a `PronunciationAssessmentResult`."""
    score = result.display_score
    messages = _messages_for(result.language_code)

    if score is None:
        return messages["no_speech"]

    return messages[band_for_score(score)]


def no_speech_feedback(language_code):
    return _messages_for(language_code)["no_speech"]


def build_tips(result):
    """Checklist rows, derived only from metrics that were actually measured.

    Returns dicts of {metric, tone, text}. `tone` is `positive` or
    `suggestion`, so the client can pick an icon without re-deriving the
    judgement - and so the meaning survives for a user who cannot rely on
    colour alone.
    """
    tips = []
    labels = _tips_for(result.language_code)
    measured = result.measured_metrics

    def add(metric, high_key, low_key):
        value = measured.get(metric)
        if value is None:
            return  # not measured for this locale - say nothing at all
        positive = value >= _HIGH
        tips.append(
            {
                "metric": metric,
                "tone": "positive" if positive else "suggestion",
                "text": labels[high_key if positive else low_key],
            }
        )

    add("accuracy", "accuracy_high", "accuracy_low")
    add("fluency", "fluency_high", "fluency_low")
    add("prosody", "prosody_high", "prosody_low")

    completeness = measured.get("completeness")
    if completeness is not None and completeness < 100:
        tips.append(
            {
                "metric": "completeness",
                "tone": "suggestion",
                "text": labels["completeness_low"],
            }
        )

    return tips


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
