"""Phase 6 Task 7: school-wide analytics.

Every score, phoneme, and completion calculation is delegated to
`apps.progress.services.analytics` - the same module Parent/Teacher Mode's
per-learner analytics already runs on - so a school-wide figure and an
individual learner's figure are always computed the same way. This module
only adds what is genuinely new: the school/classroom tenant boundary, and
the handful of structural counts (students, teachers, classrooms) that
have nothing to do with pronunciation scoring at all.
"""

from apps.accounts.models import Role
from apps.profiles.models import Profile
from apps.progress.services import analytics as progress_analytics

from .permissions import SchoolScopedQuerySet


def _active_profiles_for_school(school):
    """Students in a currently-active classroom only.

    Deliberately not `SchoolScopedQuerySet.profiles_for_school` (Task 3's
    helper, used elsewhere for classroom detail/student-count and left
    unchanged here): that one has no opinion about a classroom's own
    `is_active` flag, because none of its existing callers needed one.
    School-wide analytics does - a deactivated classroom's former
    students should not keep inflating a school's live numbers.
    """
    return Profile.objects.filter(classroom__school=school, classroom__is_active=True)


def overview(school):
    """Headline numbers for `GET /api/schools/analytics/overview/`."""
    profiles = _active_profiles_for_school(school)
    classrooms = SchoolScopedQuerySet.classrooms_for_school(school).filter(
        is_active=True
    )
    teachers = SchoolScopedQuerySet.users_for_school(school).filter(
        role=Role.TEACHER
    )

    summary = progress_analytics.group_score_summary(profiles)

    return {
        "total_students": profiles.count(),
        "total_teachers": teachers.count(),
        "total_classrooms": classrooms.count(),
        **summary,
    }


def classroom_breakdown(school):
    """Per-classroom rows for `GET /api/schools/analytics/classrooms/`."""
    classrooms = SchoolScopedQuerySet.classrooms_for_school(school).filter(
        is_active=True
    )
    return progress_analytics.classroom_breakdown(classrooms)


def weakest_phonemes(school, limit=10):
    """Top weakest sounds for `GET /api/schools/analytics/phonemes/`."""
    profiles = _active_profiles_for_school(school)
    return progress_analytics.weakest_phonemes_for_profiles(profiles, limit=limit)


def daily_trend(school, days=7):
    """Day-by-day rows for `GET /api/schools/analytics/trends/`."""
    profiles = _active_profiles_for_school(school)
    return progress_analytics.daily_trend_for_profiles(profiles, days=days)
