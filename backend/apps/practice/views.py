"""Practice endpoints."""

import logging

from rest_framework import status, viewsets
from rest_framework.parsers import FormParser, MultiPartParser
from rest_framework.permissions import IsAuthenticated
from rest_framework.response import Response
from rest_framework.views import APIView

from .models import PracticeAttempt
from .serializers import AttemptSerializer, EvaluateRequestSerializer
from .services import feedback as feedback_engine
from .services.base import AssessmentError
from .services.ai.factory import get_ai_service
from .services.evaluation import PracticeEvaluationService
from .services.factory import get_pronunciation_service

logger = logging.getLogger(__name__)


class EvaluatePracticeView(APIView):
    """POST /api/practice/evaluate/

    Accepts multipart form data: `word_id`, `profile_id`, `audio`.
    """

    permission_classes = [IsAuthenticated]
    parser_classes = [MultiPartParser, FormParser]

    def post(self, request):
        serializer = EvaluateRequestSerializer(
            data=request.data, context={"request": request}
        )
        serializer.is_valid(raise_exception=True)

        word = serializer.context["word"]
        profile = serializer.context["profile"]
        language = word.lesson.category.language

        service = PracticeEvaluationService(
            get_pronunciation_service(),
            # None unless ENABLE_AI_FEEDBACK is on, so the default path makes
            # no LLM call at all.
            ai_service=get_ai_service(),
        )

        try:
            attempt, result = service.evaluate(
                profile=profile,
                word=word,
                audio_file=serializer.validated_data["audio"],
            )
        except AssessmentError as error:
            # The technical detail is logged; the child sees only the safe
            # message.
            logger.error(
                "Assessment failed for word=%s locale=%s: %s",
                word.pk,
                language.locale,
                error.detail,
            )
            return Response(
                {"detail": error.user_message, "can_retry": error.retryable},
                status=status.HTTP_503_SERVICE_UNAVAILABLE,
            )

        return Response(
            self._build_response(attempt, result, language),
            status=status.HTTP_200_OK,
        )

    def _build_response(self, attempt, result, language):
        """Shapes the result for the client.

        `scores` carries only what was actually measured; a metric the locale
        does not support is present as null so the app can show "not
        measured" rather than invent a value. `available_metrics` tells the
        client which rows to render at all.
        """
        heard_nothing = result is None

        return {
            "attempt_id": attempt.id,
            "reference_text": attempt.reference_text,
            "recognized_text": attempt.recognized_text,
            "language": attempt.language_code,
            "locale": attempt.locale,
            "heard_speech": not heard_nothing,
            "score": attempt.display_score,
            "scores": {
                "pronunciation": attempt.pronunciation_score,
                "accuracy": attempt.accuracy_score,
                "fluency": attempt.fluency_score,
                "completeness": attempt.completeness_score,
                "prosody": attempt.prosody_score,
            },
            "available_metrics": language.available_metrics,
            "error_type": attempt.error_type or None,
            "feedback": attempt.feedback,
            "tips": [] if heard_nothing else feedback_engine.build_tips(result),
            "points_awarded": attempt.points_awarded,
            "profile": {
                "id": attempt.profile_id,
                "points": attempt.profile.points,
                "level": attempt.profile.level_from_points,
                "streak_days": attempt.profile.streak_days,
            },
            "can_retry": True,
        }


class AttemptViewSet(viewsets.ReadOnlyModelViewSet):
    """GET /api/attempts/ and /api/attempts/{id}/

    History for the signed-in account's own children only.
    """

    serializer_class = AttemptSerializer
    permission_classes = [IsAuthenticated]

    def get_queryset(self):
        queryset = (
            PracticeAttempt.objects.filter(profile__owner=self.request.user)
            .select_related("word", "profile")
            .order_by("-created_at", "-id")
        )

        profile_id = self.request.query_params.get("profile")
        if profile_id:
            queryset = queryset.filter(profile_id=profile_id)

        word_id = self.request.query_params.get("word")
        if word_id:
            queryset = queryset.filter(word_id=word_id)

        return queryset
