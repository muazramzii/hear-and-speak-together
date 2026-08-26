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


_EMPTY_OVERVIEW = {
    "total_students": 0,
    "total_teachers": 0,
    "total_classrooms": 0,
    "active_students_today": 0,
    "weekly_average_score": None,
    "monthly_average_score": None,
}


def overview(school):
    """Headline numbers for `GET /api/schools/analytics/overview/`.

    `school=None` (an admin who has not completed the Task 4 "create a
    school" step yet) returns this same zeroed shape rather than the
    view having to know and duplicate it - one source of truth for what
    "no data yet" looks like.
    """
    if school is None:
        return dict(_EMPTY_OVERVIEW)

    profiles = _active_profiles_for_school(school)
    classrooms = SchoolScopedQuerySet.classrooms_for_school(school).filter(
        is_active=True
    )
    teachers = SchoolScopedQuerySet.users_for_school(school).filter(
        role=Role.TEACHER, is_active=True
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
    if school is None:
        return []

    classrooms = SchoolScopedQuerySet.classrooms_for_school(school).filter(
        is_active=True
    )
    return progress_analytics.classroom_breakdown(classrooms)


def _profiles_for_scope(school, classroom_id=None):
    """Students in scope: one classroom, tenant-checked, or the whole school.

    `classroom_id` is client-supplied (Task 9's per-classroom report), so
    it is resolved through `SchoolScopedQuerySet.classrooms_for_school`
    rather than a bare lookup by id - a classroom id that doesn't exist,
    or belongs to a different school, silently yields no profiles rather
    than another tenant's data.
    """
    if classroom_id is not None:
        classroom = (
            SchoolScopedQuerySet.classrooms_for_school(school)
            .filter(id=classroom_id)
            .first()
        )
        if classroom is None:
            return Profile.objects.none()
        return Profile.objects.filter(classroom=classroom)

    return _active_profiles_for_school(school)


def weakest_phonemes(school, limit=10, classroom_id=None):
    """Top weakest sounds for `GET /api/schools/analytics/phonemes/`.

    `classroom_id` narrows the same calculation to one classroom's
    students (Task 9's classroom report) - the underlying
    `weakest_phonemes_for_profiles` already accepts any profile queryset.
    """
    if school is None:
        return []

    profiles = _profiles_for_scope(school, classroom_id)
    return progress_analytics.weakest_phonemes_for_profiles(profiles, limit=limit)


def daily_trend(school, days=7, classroom_id=None):
    """Day-by-day rows for `GET /api/schools/analytics/trends/`.

    `days` and `classroom_id` both narrow the same calculation
    (`daily_trend_for_profiles` already accepts any day count and any
    profile queryset) - Task 9's date-range filters and classroom report
    reuse this exactly rather than duplicating trend math client-side.
    """
    if school is None:
        return []

    profiles = _profiles_for_scope(school, classroom_id)
    return progress_analytics.daily_trend_for_profiles(profiles, days=days)
