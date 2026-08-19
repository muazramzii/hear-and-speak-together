from rest_framework import status, viewsets
from rest_framework.decorators import action
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

    @action(detail=True, methods=["post"], url_path="regenerate-code")
    def regenerate_code(self, request, pk=None):
        """POST /api/profiles/{id}/regenerate-code/

        Issues a new share code, so a code that has been passed around can no
        longer be used to make new links. Teachers already linked keep their
        access - revoking that is a separate, deliberate action.
        """
        profile = self.get_object()
        profile.regenerate_share_code()
        profile.save(update_fields=["share_code", "updated_at"])

        return Response(ProfileSerializer(profile).data)
