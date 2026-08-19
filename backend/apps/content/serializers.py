from rest_framework import serializers

from .models import Category, Language, Lesson, Word


class LanguageSerializer(serializers.ModelSerializer):
    """Includes the capability block so the client knows which pronunciation
    metrics are real for this locale and can hide the rest."""

    capabilities = serializers.SerializerMethodField()

    class Meta:
        model = Language
        fields = ["id", "code", "name", "locale", "tts_voice", "capabilities"]

    def get_capabilities(self, language):
        return {
            "pronunciation_assessment": language.supports_pronunciation_assessment,
            "prosody": language.supports_prosody,
            "phoneme_names": language.supports_phoneme_names,
            "syllable_scores": language.supports_syllable_scores,
            "available_metrics": language.available_metrics,
        }


class WordSerializer(serializers.ModelSerializer):
    class Meta:
        model = Word
        fields = [
            "id",
            "text",
            "meaning",
            "example_sentence",
            "image_url",
            "emoji",
            "audio_url",
            "order",
        ]


class WordOptionSerializer(serializers.ModelSerializer):
    """The minimum a Listen or Quiz tile needs to render.

    `emoji` is not optional in practice: a Listen round hides the word, so
    without a distinguishing visual every tile would look the same.
    """

    class Meta:
        model = Word
        fields = ["id", "text", "image_url", "emoji"]


class QuizRoundSerializer(serializers.Serializer):
    """A single multiple-choice round: the prompt plus shuffled options.

    The correct answer's id is included because the round is scored
    server-side on submission; the client uses it only to render feedback
    after the child has already chosen.
    """

    word = WordOptionSerializer(read_only=True)
    options = WordOptionSerializer(many=True, read_only=True)


class LessonSerializer(serializers.ModelSerializer):
    word_count = serializers.IntegerField(read_only=True)

    class Meta:
        model = Lesson
        fields = [
            "id",
            "title",
            "description",
            "difficulty",
            "image_url",
            "order",
            "word_count",
        ]


class LessonDetailSerializer(LessonSerializer):
    words = WordSerializer(many=True, read_only=True)

    class Meta(LessonSerializer.Meta):
        fields = LessonSerializer.Meta.fields + ["words"]


class CategorySerializer(serializers.ModelSerializer):
    lesson_count = serializers.IntegerField(read_only=True)

    class Meta:
        model = Category
        fields = [
            "id",
            "slug",
            "name",
            "description",
            "icon",
            "image_url",
            "order",
            "lesson_count",
        ]


class CategoryDetailSerializer(CategorySerializer):
    lessons = LessonSerializer(many=True, read_only=True)

    class Meta(CategorySerializer.Meta):
        fields = CategorySerializer.Meta.fields + ["lessons"]
