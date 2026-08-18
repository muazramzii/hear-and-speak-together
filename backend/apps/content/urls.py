from rest_framework.routers import DefaultRouter

from . import views

app_name = "content"

router = DefaultRouter()
router.register("languages", views.LanguageViewSet, basename="language")
router.register("categories", views.CategoryViewSet, basename="category")
router.register("lessons", views.LessonViewSet, basename="lesson")
router.register("words", views.WordViewSet, basename="word")

urlpatterns = router.urls
