"""Recording the outcome of a Listen or Quiz session."""

import logging

from rest_framework import serializers, status
from rest_framework.permissions import IsAuthenticated
from rest_framework.response import Response
from rest_framework.views import APIView

from apps.content.models import Lesson
from apps.profiles.models import Profile

from .quiz_models import QuizMode, QuizSession

logger = logging.getLogger(__name__)

# One star per correct answer, matching the "+10" shown after each round.
POINTS_PER_CORRECT = 10


class QuizResultSerializer(serializers.Serializer):
    profile_id = serializers.IntegerField()
    lesson_id = serializers.IntegerField()
    mode = serializers.ChoiceField(choices=QuizMode.choices)
    correct_count = serializers.IntegerField(min_value=0)
    total_rounds = serializers.IntegerField(min_value=1)

    def validate_profile_id(self, value):
        profile = Profile.objects.filter(
            pk=value, owner=self.context["request"].user
        ).first()
        if profile is None:
            raise serializers.ValidationError("Unknown profile.")
        self.context["profile"] = profile
        return value

    def validate_lesson_id(self, value):
        lesson = Lesson.objects.filter(pk=value, is_active=True).first()
        if lesson is None:
            raise serializers.ValidationError("Unknown lesson.")
        self.context["lesson"] = lesson
        return value

    def validate(self, attrs):
        if attrs["correct_count"] > attrs["total_rounds"]:
            # A client claiming more correct answers than questions is either
            # broken or forging points.
            raise serializers.ValidationError(
                {"correct_count": "Cannot exceed the number of rounds."}
            )

        lesson = self.context["lesson"]
        available = lesson.words.filter(is_active=True).count()
        if attrs["total_rounds"] > max(available, 1):
            raise serializers.ValidationError(
                {"total_rounds": "More rounds than this lesson has words."}
            )
        return attrs


class QuizResultView(APIView):
    """POST /api/practice/quiz-result/

    Quiz rounds are scored on the device - the correct answer is known there,
    so re-checking every tap server-side would add round trips for no
    security benefit. What the server does enforce is that the *reported*
    result is possible: no more correct answers than rounds, and no more
    rounds than the lesson has words. That bounds how much a forged request
    could inflate a score.
    """

    permission_classes = [IsAuthenticated]

    def post(self, request):
        serializer = QuizResultSerializer(
            data=request.data, context={"request": request}
        )
        serializer.is_valid(raise_exception=True)

        profile = serializer.context["profile"]
        lesson = serializer.context["lesson"]
        data = serializer.validated_data

        points = data["correct_count"] * POINTS_PER_CORRECT

        session = QuizSession.objects.create(
            profile=profile,
            lesson=lesson,
            mode=data["mode"],
            correct_count=data["correct_count"],
            total_rounds=data["total_rounds"],
            points_awarded=points,
        )

        profile.award_points(points)
        profile.register_practice()
        profile.save(
            update_fields=[
                "points",
                "level",
                "streak_days",
                "last_practised_on",
                "updated_at",
            ]
        )

        new_achievements = self._award_achievements(profile)

        return Response(
            {
                "session_id": session.id,
                "correct_count": session.correct_count,
                "total_rounds": session.total_rounds,
                "accuracy_percentage": session.accuracy_percentage,
                "points_awarded": points,
                "profile": {
                    "id": profile.id,
                    "points": profile.points,
                    "level": profile.level_from_points,
                    "streak_days": profile.streak_days,
                },
                "new_achievements": new_achievements,
            },
            status=status.HTTP_201_CREATED,
        )

    def _award_achievements(self, profile):
        """Never let an analytics failure lose a recorded session."""
        from apps.progress.services import achievements

        try:
            earned = achievements.evaluate(profile)
        except Exception:
            logger.exception("Could not evaluate achievements for %s", profile.pk)
            return []

        return [
            {
                "code": item.code,
                "name": item.localised_name(profile.practice_language.code),
                "description": item.localised_description(
                    profile.practice_language.code
                ),
                "icon": item.icon,
            }
            for item in earned
        ]
