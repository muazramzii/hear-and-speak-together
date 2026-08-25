from rest_framework import status, viewsets
from rest_framework.permissions import IsAuthenticated
from rest_framework.response import Response

from .permissions import IsSchoolAdmin, SchoolScopedQuerySet
from .serializers import SchoolSerializer, SchoolWriteSerializer


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
