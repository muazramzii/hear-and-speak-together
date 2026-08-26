from django.urls import path
from rest_framework.routers import DefaultRouter

from . import views

app_name = "schools"

router = DefaultRouter()
# Registered before "schools": the school detail route is
# `schools/(?P<pk>...)/` , and DRF/Django match URL patterns in
# registration order - registering "schools" first would let that
# pattern swallow `/api/schools/invitations/` by treating "invitations"
# as a school's pk before this router entry ever gets a chance to match.
router.register(
    "schools/invitations", views.TeacherInvitationViewSet, basename="invitation"
)
router.register("schools", views.SchoolViewSet, basename="school")
router.register("classrooms", views.ClassroomViewSet, basename="classroom")

# Plain APIViews, not router-registered: none of these are a CRUD resource
# collection, and each has more path segments after "schools/" than the
# school detail route's `(?P<pk>[^/.]+)/$` can ever match (it requires
# exactly one segment immediately followed by end-of-string), so there is
# no ordering hazard here the way there was with "schools/invitations"
# above - verified by resolving each path directly, not just assumed.
analytics_urlpatterns = [
    path(
        "schools/analytics/overview/",
        views.SchoolAnalyticsOverviewView.as_view(),
        name="school-analytics-overview",
    ),
    path(
        "schools/analytics/classrooms/",
        views.SchoolAnalyticsClassroomsView.as_view(),
        name="school-analytics-classrooms",
    ),
    path(
        "schools/analytics/phonemes/",
        views.SchoolAnalyticsPhonemesView.as_view(),
        name="school-analytics-phonemes",
    ),
]

urlpatterns = router.urls + analytics_urlpatterns
