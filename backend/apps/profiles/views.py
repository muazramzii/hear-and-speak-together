from rest_framework import status, viewsets
from rest_framework.permissions import IsAuthenticated
from rest_framework.response import Response

from .models import Profile
from .serializers import ProfileSerializer, ProfileWriteSerializer


class ProfileViewSet(viewsets.ModelViewSet):
    """/api/profiles/

    A user only ever sees and edits their own profiles. The queryset is
    filtered by owner rather than checked per object, so there is no route by
    which one account can reach another's children.
    """

    permission_classes = [IsAuthenticated]
    pagination_class = None

    def get_queryset(self):
        return (
            Profile.objects.filter(owner=self.request.user)
            .select_related("practice_language")
            .order_by("created_at")
        )

    def get_serializer_class(self):
        if self.action in ("create", "update", "partial_update"):
            return ProfileWriteSerializer
        return ProfileSerializer

    def create(self, request, *args, **kwargs):
        write = self.get_serializer(data=request.data)
        write.is_valid(raise_exception=True)
        profile = write.save()

        # Answer with the read shape so the client gets level and streak
        # fields without a second request.
        return Response(
            ProfileSerializer(profile).data, status=status.HTTP_201_CREATED
        )

    def update(self, request, *args, **kwargs):
        partial = kwargs.pop("partial", False)
        instance = self.get_object()
        write = self.get_serializer(instance, data=request.data, partial=partial)
        write.is_valid(raise_exception=True)
        write.save()
        instance.refresh_from_db()
        return Response(ProfileSerializer(instance).data)
