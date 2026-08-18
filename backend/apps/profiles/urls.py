from rest_framework.routers import DefaultRouter

from . import views

app_name = "profiles"

router = DefaultRouter()
router.register("profiles", views.ProfileViewSet, basename="profile")

urlpatterns = router.urls
