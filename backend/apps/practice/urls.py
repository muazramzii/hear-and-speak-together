from django.urls import path
from rest_framework.routers import DefaultRouter

from . import debug_views, quiz_views, views

app_name = "practice"

router = DefaultRouter()
router.register("attempts", views.AttemptViewSet, basename="attempt")

urlpatterns = [
    path(
        "practice/evaluate/",
        views.EvaluatePracticeView.as_view(),
        name="evaluate",
    ),
    path(
        "practice/quiz-result/",
        quiz_views.QuizResultView.as_view(),
        name="quiz-result",
    ),
    # Developer-only pronunciation sandbox (Phase 2). Gated on `is_staff`,
    # not part of the child-facing flow.
    path(
        "dev/pronunciation-debug/",
        debug_views.PronunciationDebugView.as_view(),
        name="pronunciation-debug",
    ),
    path(
        "dev/pronunciation-test-words/",
        debug_views.PronunciationTestWordsView.as_view(),
        name="pronunciation-test-words",
    ),
    *router.urls,
]
