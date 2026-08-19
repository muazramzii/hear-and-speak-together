from rest_framework import serializers

from apps.content.models import Language

from .models import Avatar, Profile


class ProfileSerializer(serializers.ModelSerializer):
    """Read shape. Level and progress-to-next-level are derived, not stored
    twice, so they can never disagree with `points`."""

    language_code = serializers.CharField(
        source="practice_language.code", read_only=True
    )
    language_name = serializers.CharField(
        source="practice_language.name", read_only=True
    )
    level = serializers.IntegerField(source="level_from_points", read_only=True)
    points_into_level = serializers.IntegerField(read_only=True)
    points_to_next_level = serializers.IntegerField(read_only=True)

    class Meta:
        model = Profile
        fields = [
            "id",
            "name",
            "avatar",
            "language_code",
            "language_name",
            "level",
            "points",
            "points_into_level",
            "points_to_next_level",
            "streak_days",
            "last_practised_on",
            "share_code",
            "created_at",
        ]
        read_only_fields = fields


class ProfileWriteSerializer(serializers.ModelSerializer):
    """Create/update shape. `owner` is never accepted from the client - it is
    always taken from the authenticated user."""

    avatar = serializers.ChoiceField(
        choices=Avatar.choices, default=Avatar.BOY_1
    )
    practice_language = serializers.SlugRelatedField(
        slug_field="code",
        queryset=Language.objects.filter(is_active=True),
    )

    class Meta:
        model = Profile
        fields = ["id", "name", "avatar", "practice_language"]

    def validate_name(self, value):
        name = value.strip()
        if not name:
            raise serializers.ValidationError("Please enter a name.")

        owner = self.context["request"].user
        clashes = Profile.objects.filter(owner=owner, name__iexact=name)
        if self.instance:
            clashes = clashes.exclude(pk=self.instance.pk)
        if clashes.exists():
            raise serializers.ValidationError(
                "You already have a profile with this name."
            )
        return name

    def create(self, validated_data):
        validated_data["owner"] = self.context["request"].user
        return super().create(validated_data)
