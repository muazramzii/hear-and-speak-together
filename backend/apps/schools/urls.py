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

urlpatterns = router.urls
