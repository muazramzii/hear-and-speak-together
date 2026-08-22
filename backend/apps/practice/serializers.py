from rest_framework import serializers

from apps.content.models import Word
from apps.profiles.models import Profile

from .models import PracticeAttempt

# A short word recording. Anything much larger is either a mistake or a
# needlessly long clip for the recognition model to process.
MAX_AUDIO_BYTES = 5 * 1024 * 1024


class EvaluateRequestSerializer(serializers.Serializer):
    """Validates a practice submission before any paid API call is made."""

    word_id = serializers.IntegerField()
    profile_id = serializers.IntegerField()
    audio = serializers.FileField()

    def validate_audio(self, value):
        if value.size == 0:
            raise serializers.ValidationError("The recording is empty.")
        if value.size > MAX_AUDIO_BYTES:
            raise serializers.ValidationError(
                "That recording is too long. Please record a single word."
            )
        return value

    def validate_profile_id(self, value):
        user = self.context["request"].user
        # Scoped to the requesting user, so one account cannot log attempts
        # against another family's child.
        profile = Profile.objects.filter(pk=value, owner=user).first()
        if profile is None:
            raise serializers.ValidationError("Unknown profile.")
        self.context["profile"] = profile
        return value

    def validate_word_id(self, value):
        word = (
            Word.objects.filter(pk=value, is_active=True)
            .select_related("lesson__category__language")
            .first()
        )
        if word is None:
            raise serializers.ValidationError("Unknown word.")
        self.context["word"] = word
        return value


class AttemptSerializer(serializers.ModelSerializer):
    """Full attempt record, used by history endpoints."""

    score = serializers.IntegerField(source="display_score", read_only=True)
    word_text = serializers.CharField(source="word.text", read_only=True)

    class Meta:
        model = PracticeAttempt
        fields = [
            "id",
            "word",
            "word_text",
            "language_code",
            "locale",
            "reference_text",
            "recognized_text",
            "score",
            "similarity_score",
            "confidence_score",
            "pronunciation_score",
            "completeness_score",
            "errors",
            "feedback",
            "points_awarded",
            "created_at",
        ]
        read_only_fields = fields
