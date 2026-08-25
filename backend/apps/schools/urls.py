from rest_framework.routers import DefaultRouter

from . import views

app_name = "schools"

router = DefaultRouter()
router.register("schools", views.SchoolViewSet, basename="school")

urlpatterns = router.urls
