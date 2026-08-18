"""Read-only content APIs.

Lesson content is authored in the admin, never by the app, so these are all
`ReadOnly` viewsets. Content is filtered by language on every list endpoint -
a Malay learner must never be shown English words.
"""

import random

from django.db.models import Count, Prefetch
from rest_framework import viewsets
from rest_framework.decorators import action
from rest_framework.exceptions import NotFound
from rest_framework.permissions import IsAuthenticated
from rest_framework.response import Response

from .models import Category, Language, Lesson, Word
from .serializers import (
    CategoryDetailSerializer,
    CategorySerializer,
    LanguageSerializer,
    LessonDetailSerializer,
    LessonSerializer,
    WordOptionSerializer,
    WordSerializer,
)


class LanguageViewSet(viewsets.ReadOnlyModelViewSet):
    """GET /api/languages/ - the languages on offer and what Azure can
    measure for each."""

    serializer_class = LanguageSerializer
    permission_classes = [IsAuthenticated]
    pagination_class = None
    queryset = Language.objects.filter(is_active=True)
    lookup_field = "code"


class LanguageFilteredMixin:
    """Resolves `?language=en` into a Language, defaulting sensibly.

    Order of preference: an explicit query parameter, then the requesting
    user's own preference, then English.
    """

    def get_language(self):
        code = self.request.query_params.get("language")

        if code:
            language = Language.objects.filter(code=code, is_active=True).first()
            if language is None:
                raise NotFound(f"Unknown or inactive language '{code}'.")
            return language

        user_code = getattr(self.request.user, "preferred_language", None)
        language = Language.objects.filter(code=user_code, is_active=True).first()
        return language or Language.objects.filter(is_active=True).first()


class CategoryViewSet(LanguageFilteredMixin, viewsets.ReadOnlyModelViewSet):
    """GET /api/categories/ and /api/categories/{id}/"""

    permission_classes = [IsAuthenticated]
    pagination_class = None

    def get_serializer_class(self):
        return (
            CategoryDetailSerializer
            if self.action == "retrieve"
            else CategorySerializer
        )

    def get_queryset(self):
        queryset = (
            Category.objects.filter(is_active=True)
            .select_related("language")
            .annotate(lesson_count=Count("lessons", distinct=True))
            .order_by("order", "id")
        )

        if self.action == "retrieve":
            return queryset.prefetch_related(
                Prefetch(
                    "lessons",
                    queryset=Lesson.objects.filter(is_active=True).annotate(
                        word_count=Count("words", distinct=True)
                    ),
                )
            )

        return queryset.filter(language=self.get_language())


class LessonViewSet(LanguageFilteredMixin, viewsets.ReadOnlyModelViewSet):
    """GET /api/lessons/ and /api/lessons/{id}/"""

    permission_classes = [IsAuthenticated]

    def get_serializer_class(self):
        return (
            LessonDetailSerializer
            if self.action == "retrieve"
            else LessonSerializer
        )

    def get_queryset(self):
        queryset = (
            Lesson.objects.filter(is_active=True)
            .select_related("category", "category__language")
            .annotate(word_count=Count("words", distinct=True))
            # Explicit and total. Annotating can leave the queryset without a
            # deterministic order, and unordered pagination can repeat or skip
            # rows between pages.
            .order_by("category__order", "order", "id")
        )

        if self.action == "retrieve":
            return queryset.prefetch_related(
                Prefetch(
                    "words", queryset=Word.objects.filter(is_active=True)
                )
            )

        category_id = self.request.query_params.get("category")
        if category_id:
            return queryset.filter(category_id=category_id)

        return queryset.filter(category__language=self.get_language())


class WordViewSet(viewsets.ReadOnlyModelViewSet):
    """GET /api/words/{id}/ plus the quiz-round generator."""

    serializer_class = WordSerializer
    permission_classes = [IsAuthenticated]
    queryset = Word.objects.filter(is_active=True).select_related(
        "lesson", "lesson__category", "lesson__category__language"
    )

    @action(detail=True, methods=["get"], url_path="quiz-round")
    def quiz_round(self, request, pk=None):
        """GET /api/words/{id}/quiz-round/

        Builds one multiple-choice round for the Listen and Quiz modes.
        Options are shuffled server-side so their order carries no hint.
        """
        word = self.get_object()
        options = word.quiz_options(count=4)

        if len(options) < 2:
            raise NotFound(
                "Not enough vocabulary in this category to build a quiz round."
            )

        shuffled = options[:]
        random.shuffle(shuffled)

        return Response(
            {
                "word": WordOptionSerializer(word).data,
                "options": WordOptionSerializer(shuffled, many=True).data,
                "correct_option_id": word.id,
            }
        )
