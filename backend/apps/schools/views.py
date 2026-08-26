import uuid

from django.contrib.auth import get_user_model
from django.utils import timezone
from rest_framework import mixins, status, viewsets
from rest_framework.decorators import action
from rest_framework.permissions import IsAuthenticated
from rest_framework.response import Response
from rest_framework.views import APIView

from apps.accounts.models import Role
from apps.profiles.models import Profile

from . import services as school_analytics
from .filters import ClassroomFilter
from .models import Classroom, ClassroomMembership, TeacherInvitation
from .permissions import (
    IsClassroomTeacher,
    IsSchoolAdmin,
    IsTeacherOfSchool,
    SchoolScopedQuerySet,
)
from .serializers import (
    ClassroomDetailSerializer,
    ClassroomMembershipSerializer,
    ClassroomMembershipWriteSerializer,
    ClassroomSerializer,
    ClassroomStudentMoveSerializer,
    ClassroomWriteSerializer,
    ClassroomAnalyticsSerializer,
    DailyTrendSerializer,
    PhonemeAnalyticsSerializer,
    SchoolAnalyticsOverviewSerializer,
    SchoolSerializer,
    SchoolWriteSerializer,
    TeacherInvitationAcceptSerializer,
    TeacherInvitationCreateSerializer,
    TeacherInvitationSerializer,
)


class SchoolViewSet(viewsets.ModelViewSet):
    """/api/schools/

    A school is visible to any authenticated account that belongs to it
    (SCHOOL_ADMIN or TEACHER) - `SchoolScopedQuerySet.schools_for_user` is
    the single source of truth for "which school(s) can this account see,"
    so a cross-tenant id is a 404 at the queryset level before any
    permission class even runs, on every action alike. Writes (create,
    update, soft-delete) are further restricted to that school's own
    SCHOOL_ADMIN by `IsSchoolAdmin` - a same-school TEACHER can read but
    not modify.
    """

    permission_classes = [IsAuthenticated]
    pagination_class = None

    def get_queryset(self):
        return SchoolScopedQuerySet.schools_for_user(
            self.request.user
        ).select_related("admin")

    def get_serializer_class(self):
        if self.action in ("create", "update", "partial_update"):
            return SchoolWriteSerializer
        return SchoolSerializer

    def get_permissions(self):
        if self.action in ("create", "update", "partial_update", "destroy"):
            return [IsAuthenticated(), IsSchoolAdmin()]
        return [IsAuthenticated()]

    def create(self, request, *args, **kwargs):
        write = self.get_serializer(data=request.data)
        write.is_valid(raise_exception=True)
        school = write.save(admin=request.user)

        # The admin who creates a school must become one of its staff, or
        # "GET /api/schools/ returns only the authenticated user's school"
        # would have nothing to show its own creator until a second,
        # separate step assigned them to it.
        if request.user.school_id != school.id:
            request.user.school = school
            request.user.save(update_fields=["school"])

        return Response(
            SchoolSerializer(school).data, status=status.HTTP_201_CREATED
        )

    def update(self, request, *args, **kwargs):
        partial = kwargs.pop("partial", False)
        instance = self.get_object()
        write = self.get_serializer(instance, data=request.data, partial=partial)
        write.is_valid(raise_exception=True)
        write.save()
        instance.refresh_from_db()
        return Response(SchoolSerializer(instance).data)

    def destroy(self, request, *args, **kwargs):
        """Soft delete only: flips `is_active` to False. The row is never
        removed - classrooms, profiles and attempts that reference this
        school must keep a valid foreign key to belong to."""
        instance = self.get_object()
        instance.is_active = False
        instance.save(update_fields=["is_active", "updated_at"])
        return Response(status=status.HTTP_204_NO_CONTENT)


class TeacherInvitationViewSet(
    mixins.CreateModelMixin, mixins.ListModelMixin, viewsets.GenericViewSet
):
    """/api/schools/invitations/

    Create and list are SCHOOL_ADMIN-only and scoped to the admin's own
    school via `SchoolScopedQuerySet`, exactly like `SchoolViewSet`. This
    viewset only mixes in create/list (no retrieve/update/destroy route
    exists) - `reset` and `deactivate` are the only ways to change an
    existing invitation, and `accept` (unauthenticated-by-role, open to
    any authenticated account) is the only way a non-admin ever touches
    this model at all.
    """

    permission_classes = [IsAuthenticated, IsSchoolAdmin]
    pagination_class = None

    def get_queryset(self):
        school = self.request.user.school
        if school is None:
            return TeacherInvitation.objects.none()

        base = SchoolScopedQuerySet.invitations_for_school(school).select_related(
            "school", "invited_by"
        )
        if self.action == "list":
            # "List active invitations" - a row past its own expiry is not
            # actually usable anymore even if nothing has explicitly
            # deactivated it yet, so it should not read as "active" here.
            return base.filter(is_active=True, expires_at__gt=timezone.now())
        return base

    def get_serializer_class(self):
        if self.action == "create":
            return TeacherInvitationCreateSerializer
        return TeacherInvitationSerializer

    def create(self, request, *args, **kwargs):
        if request.user.school_id is None:
            return Response(
                {"detail": "You must belong to a school before inviting teachers."},
                status=status.HTTP_400_BAD_REQUEST,
            )

        write = self.get_serializer(data=request.data)
        write.is_valid(raise_exception=True)
        invitation = write.save(
            school=request.user.school, invited_by=request.user
        )

        return Response(
            TeacherInvitationSerializer(invitation).data,
            status=status.HTTP_201_CREATED,
        )

    @action(detail=True, methods=["post"], url_path="reset")
    def reset(self, request, pk=None):
        """Invalidate the current code and issue a new one on the same
        row, keeping `invited_by`/`created_at` as history. Only makes
        sense on an invitation that is still open - resetting one that
        was already accepted or revoked would silently resurrect it."""
        invitation = self.get_object()
        if not invitation.is_active:
            return Response(
                {"detail": "This invitation is not active and cannot be reset."},
                status=status.HTTP_400_BAD_REQUEST,
            )

        invitation.reset_code()
        invitation.save(update_fields=["invitation_code", "expires_at"])
        return Response(TeacherInvitationSerializer(invitation).data)

    @action(detail=True, methods=["post"], url_path="deactivate")
    def deactivate(self, request, pk=None):
        """Soft revoke: the code stops working, the row stays. Safe to
        call on an invitation that is already inactive - it is a no-op,
        not an error."""
        invitation = self.get_object()
        invitation.deactivate()
        invitation.save(update_fields=["is_active"])
        return Response(TeacherInvitationSerializer(invitation).data)

    @action(detail=False, methods=["post"], url_path="accept", permission_classes=[IsAuthenticated])
    def accept(self, request):
        """Any authenticated account may call this - it is how a
        prospective teacher redeems a code an admin gave them, so it
        cannot itself require the SCHOOL_ADMIN role this viewset's other
        actions do.
        """
        serializer = TeacherInvitationAcceptSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        code = serializer.validated_data["invitation_code"]

        try:
            invitation = TeacherInvitation.objects.select_related("school").get(
                invitation_code=code
            )
        except TeacherInvitation.DoesNotExist:
            return Response(
                {"detail": "Invalid invitation code."},
                status=status.HTTP_400_BAD_REQUEST,
            )

        if invitation.accepted_at is not None:
            return Response(
                {"detail": "This invitation has already been accepted."},
                status=status.HTTP_400_BAD_REQUEST,
            )
        if not invitation.is_active:
            return Response(
                {"detail": "This invitation is no longer active."},
                status=status.HTTP_400_BAD_REQUEST,
            )
        if invitation.is_expired:
            return Response(
                {"detail": "This invitation has expired."},
                status=status.HTTP_400_BAD_REQUEST,
            )

        user = request.user
        if user.role not in (Role.STUDENT, Role.TEACHER):
            return Response(
                {
                    "detail": (
                        "This account's role cannot accept a teacher "
                        "invitation."
                    )
                },
                status=status.HTTP_400_BAD_REQUEST,
            )
        # "School assignment absent or valid": no school yet, or already
        # this same school (a harmless re-accept) - anything else would
        # be joining a second school at once.
        if user.school_id is not None and user.school_id != invitation.school_id:
            return Response(
                {"detail": "This account already belongs to a different school."},
                status=status.HTTP_400_BAD_REQUEST,
            )

        invitation.accept(user)

        return Response(
            {
                "school_name": invitation.school.name,
                "role": user.role,
                "accepted_at": invitation.accepted_at,
            }
        )


class ClassroomViewSet(viewsets.ModelViewSet):
    """/api/classrooms/

    Read and write use different tenant boundaries, deliberately:

    - `list`/`retrieve` accept any authenticated staff member of the
      classroom's own school (`IsSchoolAdmin | IsTeacherOfSchool`) for the
      queryset-level, cross-*school* boundary - "never expose another
      school's classroom" - but `retrieve` additionally requires
      `IsSchoolAdmin | IsClassroomTeacher` at the object level, so a
      teacher can see their own school's classroom list (useful context,
      e.g. for the `teacher` filter) without being able to open the
      detail - staff roster included - of a classroom they are not
      actually assigned to.
    - Every write (create, update, soft-delete, staff assignment, student
      transfer) is `IsSchoolAdmin` only, exactly as the brief specifies -
      "Allow a School Admin to manage classrooms."

    Nothing here re-implements a tenant check by hand: every boundary is
    one of the Task 3 permission classes, or `SchoolScopedQuerySet`.
    """

    pagination_class = None
    filterset_class = ClassroomFilter

    def get_queryset(self):
        school = self.request.user.school
        if school is None:
            return Classroom.objects.none()
        return SchoolScopedQuerySet.classrooms_for_school(school).prefetch_related(
            "staff_memberships__teacher"
        )

    def get_serializer_class(self):
        if self.action in ("create", "update", "partial_update"):
            return ClassroomWriteSerializer
        if self.action == "retrieve":
            return ClassroomDetailSerializer
        return ClassroomSerializer

    def get_permissions(self):
        if self.action == "list":
            return [IsAuthenticated(), (IsSchoolAdmin | IsTeacherOfSchool)()]
        if self.action == "retrieve":
            return [IsAuthenticated(), (IsSchoolAdmin | IsClassroomTeacher)()]
        return [IsAuthenticated(), IsSchoolAdmin()]

    def create(self, request, *args, **kwargs):
        write = self.get_serializer(data=request.data)
        write.is_valid(raise_exception=True)
        classroom = write.save(school=request.user.school)
        return Response(
            ClassroomDetailSerializer(classroom).data,
            status=status.HTTP_201_CREATED,
        )

    def update(self, request, *args, **kwargs):
        partial = kwargs.pop("partial", False)
        instance = self.get_object()
        write = self.get_serializer(instance, data=request.data, partial=partial)
        write.is_valid(raise_exception=True)
        write.save()
        instance.refresh_from_db()
        return Response(ClassroomDetailSerializer(instance).data)

    def destroy(self, request, *args, **kwargs):
        """Soft delete only: flips `is_active` to False. The row, its
        memberships and its students' `classroom` links are never
        touched - a deactivated classroom's history stays intact."""
        instance = self.get_object()
        instance.is_active = False
        instance.save(update_fields=["is_active", "updated_at"])
        return Response(status=status.HTTP_204_NO_CONTENT)

    @action(detail=True, methods=["post"], url_path="teachers")
    def add_teacher(self, request, pk=None):
        classroom = self.get_object()
        write = ClassroomMembershipWriteSerializer(data=request.data)
        write.is_valid(raise_exception=True)
        teacher_public_id = write.validated_data["teacher"]
        role = write.validated_data["role"]

        try:
            teacher = get_user_model().objects.get(
                public_id=teacher_public_id, role=Role.TEACHER
            )
        except get_user_model().DoesNotExist:
            return Response(
                {"detail": "No teacher account with that id."},
                status=status.HTTP_400_BAD_REQUEST,
            )

        if teacher.school_id != classroom.school_id:
            return Response(
                {"detail": "This teacher does not belong to this school."},
                status=status.HTTP_400_BAD_REQUEST,
            )
        if ClassroomMembership.objects.filter(
            classroom=classroom, teacher=teacher
        ).exists():
            return Response(
                {"detail": "This teacher is already a member of this classroom."},
                status=status.HTTP_400_BAD_REQUEST,
            )

        ClassroomMembership.objects.create(
            classroom=classroom, teacher=teacher, role=role
        )
        return Response(
            ClassroomMembershipSerializer(
                classroom.staff_memberships.select_related("teacher"), many=True
            ).data,
            status=status.HTTP_201_CREATED,
        )

    @action(
        detail=True,
        methods=["delete"],
        url_path=r"teachers/(?P<teacher_public_id>[^/.]+)",
    )
    def remove_teacher(self, request, pk=None, teacher_public_id=None):
        """Removes the membership only - the teacher's own account is
        never touched by this. Addressed by the teacher's public UUID,
        like every other reference to an account in this API - never the
        integer primary key."""
        classroom = self.get_object()
        try:
            teacher_public_id = uuid.UUID(str(teacher_public_id))
        except ValueError:
            return Response(
                {"detail": "This teacher is not a member of this classroom."},
                status=status.HTTP_404_NOT_FOUND,
            )

        deleted, _ = ClassroomMembership.objects.filter(
            classroom=classroom, teacher__public_id=teacher_public_id
        ).delete()

        if not deleted:
            return Response(
                {"detail": "This teacher is not a member of this classroom."},
                status=status.HTTP_404_NOT_FOUND,
            )

        return Response(
            ClassroomMembershipSerializer(
                classroom.staff_memberships.select_related("teacher"), many=True
            ).data
        )

    @action(detail=True, methods=["post"], url_path="students")
    def add_student(self, request, pk=None):
        """Moves one student into this classroom.

        "Student must belong to same school" only has a meaningful check
        for a student who already belongs to a classroom somewhere - a
        never-yet-enrolled `Profile` has no school to compare against, and
        assigning it here for the first time is exactly what this action
        is for. A student already enrolled in a *different* school's
        classroom is rejected outright: moving them would silently take
        them from a tenant this admin does not administer.
        """
        classroom = self.get_object()
        write = ClassroomStudentMoveSerializer(data=request.data)
        write.is_valid(raise_exception=True)
        profile_id = write.validated_data["profile_id"]

        try:
            profile = Profile.objects.select_related("classroom__school").get(
                pk=profile_id
            )
        except Profile.DoesNotExist:
            return Response(
                {"detail": "No student profile with that id."},
                status=status.HTTP_400_BAD_REQUEST,
            )

        if (
            profile.classroom_id is not None
            and profile.classroom.school_id != classroom.school_id
        ):
            return Response(
                {"detail": "This student belongs to a different school."},
                status=status.HTTP_400_BAD_REQUEST,
            )

        # Captured before the reassignment - Task 6 only updates the
        # pointer, it does not record this anywhere. The previous
        # classroom is returned so the caller has confirmation of what
        # just changed; Task 7 is where an actual transfer-history record
        # gets introduced.
        previous_classroom = profile.classroom

        profile.classroom = classroom
        profile.save(update_fields=["classroom", "updated_at"])

        return Response(
            {
                "previous_classroom": (
                    ClassroomSerializer(previous_classroom).data
                    if previous_classroom is not None
                    else None
                ),
                "classroom": ClassroomDetailSerializer(classroom).data,
            }
        )


class _SchoolAnalyticsView(APIView):
    """Shared base for the four `/api/schools/analytics/...` endpoints.

    SCHOOL_ADMIN-only, and there is no id to guess in any of these URLs -
    the school is always `request.user.school`, never a client-supplied
    parameter, which is what makes "no cross-tenant leakage" true by
    construction rather than by a queryset filter that could be gotten
    wrong. A request from an admin with no school at all (never having
    created one) gets an empty-but-valid response, not an error - Task 4
    already made a `School` the very first thing an admin creates.
    """

    permission_classes = [IsAuthenticated, IsSchoolAdmin]


class SchoolAnalyticsOverviewView(_SchoolAnalyticsView):
    """GET /api/schools/analytics/overview/"""

    def get(self, request):
        school = request.user.school
        if school is None:
            return Response(
                SchoolAnalyticsOverviewSerializer(
                    {
                        "total_students": 0,
                        "total_teachers": 0,
                        "total_classrooms": 0,
                        "active_students_today": 0,
                        "weekly_average_score": None,
                        "monthly_average_score": None,
                    }
                ).data
            )

        data = school_analytics.overview(school)
        return Response(SchoolAnalyticsOverviewSerializer(data).data)


class SchoolAnalyticsClassroomsView(_SchoolAnalyticsView):
    """GET /api/schools/analytics/classrooms/ - already ordered by
    classroom name (`apps.progress.services.analytics.classroom_breakdown`
    sorts before returning)."""

    def get(self, request):
        school = request.user.school
        if school is None:
            return Response([])

        rows = school_analytics.classroom_breakdown(school)
        return Response(ClassroomAnalyticsSerializer(rows, many=True).data)


class SchoolAnalyticsPhonemesView(_SchoolAnalyticsView):
    """GET /api/schools/analytics/phonemes/ - top 10 weakest sounds
    school-wide, worst first."""

    def get(self, request):
        school = request.user.school
        if school is None:
            return Response([])

        rows = school_analytics.weakest_phonemes(school, limit=10)
        return Response(PhonemeAnalyticsSerializer(rows, many=True).data)


class SchoolAnalyticsTrendsView(_SchoolAnalyticsView):
    """GET /api/schools/analytics/trends/ - the last 7 days, zero-filled
    for any day with no activity at all."""

    def get(self, request):
        school = request.user.school
        if school is None:
            return Response([])

        rows = school_analytics.daily_trend(school, days=7)
        return Response(DailyTrendSerializer(rows, many=True).data)
