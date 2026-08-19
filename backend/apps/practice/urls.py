from django.urls import path
from rest_framework.routers import DefaultRouter

from . import views

app_name = "practice"

router = DefaultRouter()
router.register("attempts", views.AttemptViewSet, basename="attempt")

urlpatterns = [
    path(
        "practice/evaluate/",
        views.EvaluatePracticeView.as_view(),
        name="evaluate",
    ),
    *router.urls,
]
