from django.urls import path

from . import views

app_name = "progress"

urlpatterns = [
    path("progress/", views.ProgressView.as_view(), name="progress"),
    path(
        "progress/<int:lesson_id>/",
        views.LessonProgressView.as_view(),
        name="lesson-progress",
    ),
    path("dashboard/", views.DashboardView.as_view(), name="dashboard"),
    path(
        "achievements/", views.AchievementsView.as_view(), name="achievements"
    ),
    path(
        "recommendations/",
        views.RecommendationsView.as_view(),
        name="recommendations",
    ),
    path("students/", views.StudentListView.as_view(), name="students"),
    path(
        "students/<int:profile_id>/progress/",
        views.StudentProgressView.as_view(),
        name="student-progress",
    ),
]
