from django.urls import path
from rest_framework.routers import DefaultRouter

from . import quiz_views, views

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
    *router.urls,
]
