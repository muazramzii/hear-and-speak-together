"""Progress, achievements, recommendations and the supervisor dashboard."""

from django.shortcuts import get_object_or_404
from rest_framework.permissions import IsAuthenticated
from rest_framework.response import Response
from rest_framework.views import APIView

from apps.accounts.permissions import IsParentOrTeacher
from apps.profiles.access import accessible_profiles
from apps.profiles.models import Profile

from .models import StudentLink
from .services import achievements as achievement_service
from .services import analytics


def _get_profile_or_404(user, profile_id):
    return get_object_or_404(accessible_profiles(user), pk=profile_id)


def _resolve_profile(request):
    """The profile a learner-facing endpoint is about.

    `?profile=` selects one explicitly; otherwise the account's first profile
    is used, which is the common single-child case.
    """
    profile_id = request.query_params.get("profile")
    if profile_id:
        return _get_profile_or_404(request.user, profile_id)

    profile = accessible_profiles(request.user).order_by("created_at").first()
    if profile is None:
        return None
    return profile


class ProgressView(APIView):
    """GET /api/progress/ - the learner's own progress screen."""

    permission_classes = [IsAuthenticated]

    def get(self, request):
        profile = _resolve_profile(request)
        if profile is None:
            return Response({"detail": "No profile found."}, status=404)

        return Response(
            {
                "profile": {"id": profile.id, "name": profile.name},
                "summary": analytics.overall_summary(profile),
                "lessons": analytics.lesson_progress_list(profile),
                "categories": analytics.category_performance(profile),
                "weak_words": analytics.weak_words(profile),
                "recent_attempts": analytics.recent_attempts(profile),
                "trend": analytics.improvement_trend(profile),
                "phonemes": {
                    "weak": analytics.weak_phonemes(profile),
                    "strong": analytics.strong_phonemes(profile),
                },
                "weekly_comparison": analytics.weekly_comparison(profile),
            }
        )


class LessonProgressView(APIView):
    """GET /api/progress/{lesson_id}/"""

    permission_classes = [IsAuthenticated]

    def get(self, request, lesson_id):
        profile = _resolve_profile(request)
        if profile is None:
            return Response({"detail": "No profile found."}, status=404)

        records = {
            item["lesson_id"]: item
            for item in analytics.lesson_progress_list(profile)
        }
        record = records.get(int(lesson_id))

        if record is None:
            # Not an error - the child simply has not started this lesson.
            return Response(
                {
                    "lesson_id": int(lesson_id),
                    "completed_words": 0,
                    "total_words": 0,
                    "completion_percentage": 0,
                    "average_score": None,
                    "attempts": 0,
                    "started": False,
                }
            )

        return Response({**record, "started": True})


class DashboardView(APIView):
    """GET /api/dashboard/ - the home summary."""

    permission_classes = [IsAuthenticated]

    def get(self, request):
        profile = _resolve_profile(request)
        if profile is None:
            return Response({"detail": "No profile found."}, status=404)

        return Response(
            {
                "profile": {
                    "id": profile.id,
                    "name": profile.name,
                    "language_code": profile.practice_language.code,
                },
                "summary": analytics.overall_summary(profile),
                "recent_attempts": analytics.recent_attempts(profile, limit=3),
                "recommendations": analytics.recommendations(profile),
            }
        )


class AchievementsView(APIView):
    """GET /api/achievements/ - the full catalogue, earned flags included."""

    permission_classes = [IsAuthenticated]

    def get(self, request):
        profile = _resolve_profile(request)
        if profile is None:
            return Response({"detail": "No profile found."}, status=404)

        return Response(
            achievement_service.earned_list(
                profile, language_code=profile.practice_language.code
            )
        )


class RecommendationsView(APIView):
    """GET /api/recommendations/ - what to practise next."""

    permission_classes = [IsAuthenticated]

    def get(self, request):
        profile = _resolve_profile(request)
        if profile is None:
            return Response({"detail": "No profile found."}, status=404)

        return Response(analytics.recommendations(profile))


class StudentListView(APIView):
    """GET /api/students/ - the learners a parent or teacher can monitor."""

    permission_classes = [IsAuthenticated, IsParentOrTeacher]

    def get(self, request):
        profiles = accessible_profiles(request.user)

        return Response(
            [
                {
                    "id": profile.id,
                    "name": profile.name,
                    "avatar": profile.avatar,
                    "language_code": profile.practice_language.code,
                    "level": profile.level_from_points,
                    "points": profile.points,
                    "streak_days": profile.streak_days,
                    "summary": analytics.overall_summary(profile),
                }
                for profile in profiles
            ]
        )


class LinkStudentView(APIView):
    """POST /api/students/link/ - a teacher follows a learner by share code.

    Deliberately code-based rather than "search for a student": a supervisor
    must never be able to discover learners they were not given access to.
    """

    permission_classes = [IsAuthenticated, IsParentOrTeacher]

    def post(self, request):
        code = (request.data.get("share_code") or "").strip().upper()
        if not code:
            return Response({"share_code": ["Please enter a code."]}, status=400)

        profile = Profile.objects.filter(share_code=code).first()
        if profile is None:
            # Same message whether the code is wrong or simply unused, so the
            # endpoint cannot be used to probe for valid codes.
            return Response(
                {"share_code": ["That code is not valid."]}, status=400
            )

        if profile.owner_id == request.user.id:
            return Response(
                {"share_code": ["This learner is already yours."]}, status=400
            )

        link, created = StudentLink.objects.get_or_create(
            supervisor=request.user, profile=profile
        )

        return Response(
            {
                "linked": True,
                "already_linked": not created,
                "profile": {
                    "id": profile.id,
                    "name": profile.name,
                    "avatar": profile.avatar,
                },
            },
            status=201 if created else 200,
        )


class UnlinkStudentView(APIView):
    """DELETE /api/students/{id}/link/ - stop following a learner."""

    permission_classes = [IsAuthenticated, IsParentOrTeacher]

    def delete(self, request, profile_id):
        deleted, _ = StudentLink.objects.filter(
            supervisor=request.user, profile_id=profile_id
        ).delete()

        if not deleted:
            return Response({"detail": "No such link."}, status=404)
        return Response(status=204)


class StudentProgressView(APIView):
    """GET /api/students/{id}/progress/ - one learner, in full."""

    permission_classes = [IsAuthenticated, IsParentOrTeacher]

    def get(self, request, profile_id):
        profile = _get_profile_or_404(request.user, profile_id)

        return Response(
            {
                "profile": {
                    "id": profile.id,
                    "name": profile.name,
                    "avatar": profile.avatar,
                    "language_code": profile.practice_language.code,
                },
                "summary": analytics.overall_summary(profile),
                "lessons": analytics.lesson_progress_list(profile),
                "categories": analytics.category_performance(profile),
                "weak_words": analytics.weak_words(profile),
                "recent_attempts": analytics.recent_attempts(profile, limit=10),
                "trend": analytics.improvement_trend(profile),
                "recommendations": analytics.recommendations(profile),
                "phonemes": {
                    "weak": analytics.weak_phonemes(profile),
                    "strong": analytics.strong_phonemes(profile),
                },
                "weekly_comparison": analytics.weekly_comparison(profile),
            }
        )
