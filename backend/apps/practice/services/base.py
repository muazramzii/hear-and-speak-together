"""Shared failure types for the speech pipeline.

Both the recognition stage (Whisper) and the scoring stage (the pronunciation
engine) can fail, and the caller needs to treat those failures the same way -
so the exception types live here rather than in either stage.
"""


class AssessmentError(Exception):
    """Speech processing could not be completed.

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
            detail="Whisper produced an empty transcript",
        )
