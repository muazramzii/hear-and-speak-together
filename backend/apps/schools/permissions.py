"""Centralized tenant/authorization checks for the School/Classroom hierarchy.

Every check here is meant to be composed into a view's `permission_classes`
- nothing in this module is meant to be called from inside a view body -
so that "does this teacher belong to this classroom" has exactly one
implementation to get right, audit, and test. `SchoolScopedQuerySet` is the
read-side counterpart: a permission class answers yes/no for one already-
fetched object, a queryset helper narrows a whole listing to what a user
may see in the first place. Future school-scoped views should use both
rather than writing `filter(school=...)` inline in more than one place.

Nothing here touches `apps.profiles.access.accessible_profiles` - the
existing Parent-owns / Teacher-has-a-StudentLink rule. That mechanism is
frozen; this module only adds the new School/Classroom-scoped rules on top
of it, for accounts that belong to a school.
"""

from django.contrib.auth import get_user_model
from rest_framework.permissions import BasePermission

from apps.accounts.models import Role
from apps.practice.models import PracticeAttempt
from apps.profiles.models import Profile

from .models import Classroom, ClassroomMembership, School, TeacherInvitation


def _is_authenticated(request):
    return bool(request.user and request.user.is_authenticated)


def _resolve_classroom(obj):
    """Best-effort: find the `Classroom` an arbitrary domain object belongs
    to. Understands `Classroom` itself, anything with a `.classroom`
    attribute (`Profile`), and anything with a `.profile` attribute
    (`PracticeAttempt`)."""
    if isinstance(obj, Classroom):
        return obj
    classroom = getattr(obj, "classroom", None)
    if isinstance(classroom, Classroom):
        return classroom
    profile = getattr(obj, "profile", None)
    if profile is not None:
        return getattr(profile, "classroom", None)
    return None


def _resolve_school(obj):
    """Best-effort: find the `School` an arbitrary domain object belongs
    to - `School`, `User` and `Classroom` carry it directly; `Profile` and
    `PracticeAttempt` only carry it transitively, through their
    classroom."""
    if isinstance(obj, School):
        return obj
    school = getattr(obj, "school", None)
    if isinstance(school, School):
        return school
    classroom = _resolve_classroom(obj)
    return classroom.school if classroom else None


class IsSchoolAdmin(BasePermission):
    """Allow only SCHOOL_ADMIN accounts, and only for the school they
    themselves administer.

    Role-only requests (no specific object - e.g. "list my school's
    classrooms") pass at `has_permission` and rely on a view/queryset to
    scope the result to `request.user.school`. Requests against a
    specific object (a `School`, `Classroom`, `Profile`, ...) are also
    checked at the object level, so a SCHOOL_ADMIN of School B is denied
    on anything belonging to School A.
    """

    message = "Only that school's admin account can do this."

    def has_permission(self, request, view):
        return bool(_is_authenticated(request) and request.user.role == Role.SCHOOL_ADMIN)

    def has_object_permission(self, request, view, obj):
        school = _resolve_school(obj)
        return bool(school and school.admin_id == request.user.id)


class IsTeacherOfSchool(BasePermission):
    """Allow a TEACHER only when their own `User.school` matches the
    school `obj` belongs to. This is the coarse, school-wide check -
    it does not look at classroom membership at all. Use
    `IsClassroomTeacher` when access should be limited to a specific
    classroom rather than anything in the school.
    """

    message = "You do not belong to this school."

    def has_permission(self, request, view):
        return bool(_is_authenticated(request) and request.user.role == Role.TEACHER)

    def has_object_permission(self, request, view, obj):
        school = _resolve_school(obj)
        return bool(
            school
            and request.user.school_id is not None
            and request.user.school_id == school.id
        )


class IsClassroomTeacher(BasePermission):
    """Allow a TEACHER only if they hold a `ClassroomMembership` row for
    the classroom `obj` belongs to. Any membership role qualifies - lead
    teacher, assistant and therapist are all "a member of this classroom"
    for access purposes; the `role` field is about the classroom's staff
    listing, not about narrowing who may view it.

    This is always a real database query against `ClassroomMembership` -
    never an id comparison against a field cached on the request or the
    object - so a stale `User.school`/membership can never grant access
    that was actually revoked.
    """

    message = "You are not a member of this classroom."

    def has_permission(self, request, view):
        return bool(_is_authenticated(request) and request.user.role == Role.TEACHER)

    def has_object_permission(self, request, view, obj):
        classroom = _resolve_classroom(obj)
        if classroom is None:
            return False
        return ClassroomMembership.objects.filter(
            classroom=classroom, teacher=request.user
        ).exists()


class SchoolScopedQuerySet:
    """Reusable listing scopes for the School/Classroom hierarchy.

    Stateless, dependency-free helpers rather than a custom `Manager` -
    keeping them out of the models means a school-scoped listing can be
    built from any of them without every model needing to know about
    tenancy. A view should call one of these instead of re-deriving the
    same `filter(...__classroom__school=...)` chain in more than one
    place.
    """

    @staticmethod
    def schools_for_user(user):
        """The single `School` a SCHOOL_ADMIN or TEACHER belongs to -
        empty for anyone with no `User.school` set (including every
        PARENT/STUDENT account, which this hierarchy does not apply to).
        A list/detail endpoint calls this rather than trusting a client-
        supplied id, so "return only the authenticated user's school" has
        exactly one implementation."""
        if user.school_id is None:
            return School.objects.none()
        return School.objects.filter(id=user.school_id)

    @staticmethod
    def users_for_school(school):
        return get_user_model().objects.filter(school=school)

    @staticmethod
    def invitations_for_school(school):
        return TeacherInvitation.objects.filter(school=school)

    @staticmethod
    def classrooms_for_school(school):
        return Classroom.objects.filter(school=school)

    @staticmethod
    def profiles_for_school(school):
        return Profile.objects.filter(classroom__school=school)

    @staticmethod
    def attempts_for_school(school):
        return PracticeAttempt.objects.filter(profile__classroom__school=school)

    @staticmethod
    def classrooms_for_teacher(teacher):
        """Only classrooms this teacher has a membership row for - not
        every classroom in their school."""
        return Classroom.objects.filter(
            staff_memberships__teacher=teacher
        ).distinct()

    @staticmethod
    def profiles_for_teacher(teacher):
        return Profile.objects.filter(
            classroom__staff_memberships__teacher=teacher
        ).distinct()

    @staticmethod
    def attempts_for_teacher(teacher):
        return PracticeAttempt.objects.filter(
            profile__classroom__staff_memberships__teacher=teacher
        ).distinct()
