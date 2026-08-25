from django.utils import timezone
from rest_framework import mixins, status, viewsets
from rest_framework.decorators import action
from rest_framework.permissions import IsAuthenticated
from rest_framework.response import Response

from apps.accounts.models import Role

from .models import TeacherInvitation
from .permissions import IsSchoolAdmin, SchoolScopedQuerySet
from .serializers import (
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
