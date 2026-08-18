"""
Root URL configuration for the "Hear & Speak Together" API.

Every application endpoint is namespaced under `/api/`. Feature routes
(auth, lessons, practice, progress) are added in later phases.
"""

from django.conf import settings
from django.conf.urls.static import static
from django.contrib import admin
from django.urls import include, path

urlpatterns = [
    path("admin/", admin.site.urls),
    path("api/", include("apps.core.urls")),
]

if settings.DEBUG:
    urlpatterns += static(settings.MEDIA_URL, document_root=settings.MEDIA_ROOT)
