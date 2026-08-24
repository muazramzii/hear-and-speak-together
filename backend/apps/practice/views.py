"""Practice endpoints."""

import logging

from rest_framework import status, viewsets
from rest_framework.parsers import FormParser, MultiPartParser
from rest_framework.permissions import IsAuthenticated
from rest_framework.response import Response
from rest_framework.views import APIView

from apps.profiles.access import accessible_profiles

from .models import PracticeAttempt
from .serializers import AttemptSerializer, EvaluateRequestSerializer
from .services.ai.factory import get_ai_service
from .services.base import AssessmentError
from .services.evaluation import PracticeEvaluationService
from .services.factory import get_recognition_service

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
            get_recognition_service(),
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
            self._build_response(attempt),
            status=status.HTTP_200_OK,
        )

    def _build_response(self, attempt):
        heard_nothing = attempt.pronunciation_score is None

        return {
            "attempt_id": attempt.id,
            "reference": attempt.reference_text,
            "recognized": attempt.recognized_text,
            "language": attempt.language_code,
            "locale": attempt.locale,
            "heard_speech": not heard_nothing,
            "score": attempt.display_score,
            "similarity": attempt.similarity_score,
            "confidence": attempt.confidence_score,
            "completeness": attempt.completeness_score,
            "errors": attempt.errors,
            "feedback": attempt.feedback,
            "points_awarded": attempt.points_awarded,
            "profile": {
                "id": attempt.profile_id,
                "points": attempt.profile.points,
                "level": attempt.profile.level_from_points,
                "streak_days": attempt.profile.streak_days,
            },
            # Achievements unlocked by this attempt, so the app can celebrate
            # immediately rather than waiting for the rewards screen.
            "new_achievements": [
                {
                    "code": achievement.code,
                    "name": achievement.localised_name(attempt.language_code),
                    "description": achievement.localised_description(
                        attempt.language_code
                    ),
                    "icon": achievement.icon,
                }
                for achievement in getattr(
                    attempt, "newly_earned_achievements", []
                )
            ],
            "can_retry": True,
        }


class AttemptViewSet(viewsets.ReadOnlyModelViewSet):
    """GET /api/attempts/ and /api/attempts/{id}/

    History for every profile the signed-in account may look at - their own
    children, plus anything a `StudentLink` has shared with them, the same
    visibility rule the parent/teacher progress endpoints use.
    """

    serializer_class = AttemptSerializer
    permission_classes = [IsAuthenticated]

    def get_queryset(self):
        queryset = (
            PracticeAttempt.objects.filter(
                profile__in=accessible_profiles(self.request.user)
            )
            .select_related("word", "profile")
            .order_by("-created_at", "-id")
        )

        params = self.request.query_params

        profile_id = params.get("profile")
        if profile_id:
            queryset = queryset.filter(profile_id=profile_id)

        word_id = params.get("word")
        if word_id:
            queryset = queryset.filter(word_id=word_id)

        language = params.get("language")
        if language:
            queryset = queryset.filter(language_code=language)

        category_id = params.get("category")
        if category_id:
            queryset = queryset.filter(word__lesson__category_id=category_id)

        date_from = params.get("date_from")
        if date_from:
            queryset = queryset.filter(created_at__date__gte=date_from)

        date_to = params.get("date_to")
        if date_to:
            queryset = queryset.filter(created_at__date__lte=date_to)

        # "Result" filters on the same pass mark the app uses everywhere else
        # to decide a word is learned (see `Profile`/`PracticeAttempt`).
        result = params.get("result")
        if result == "pass":
            queryset = queryset.filter(pronunciation_score__gte=75)
        elif result == "fail":
            queryset = queryset.filter(pronunciation_score__lt=75)

        return queryset
