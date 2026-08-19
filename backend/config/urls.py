"""
Root URL configuration for the "Hear & Speak Together" API.

Every application endpoint is namespaced under `/api/`. Feature routes
(auth, lessons, practice, progress) are added in later phases.
"""

from django.conf import settings
from django.conf.urls.static import static
from django.contrib import admin
from django.urls import include, path

from apps.core.views import api_root

urlpatterns = [
    path("", api_root, name="api-root"),
    path("admin/", admin.site.urls),
    path("api/", include("apps.core.urls")),
    path("api/auth/", include("apps.accounts.urls")),
    path("api/", include("apps.content.urls")),
    path("api/", include("apps.profiles.urls")),
    path("api/", include("apps.practice.urls")),
    path("api/", include("apps.progress.urls")),
]

if settings.DEBUG:
    urlpatterns += static(settings.MEDIA_URL, document_root=settings.MEDIA_ROOT)
