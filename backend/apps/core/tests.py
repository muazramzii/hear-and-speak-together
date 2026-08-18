"""Phase 1 tests: the health endpoint and baseline project configuration."""

from unittest.mock import patch

from django.conf import settings
from django.test import TestCase
from django.urls import reverse


class HealthEndpointTests(TestCase):
    """GET /api/health/ must be public and report real database state."""

    def test_health_returns_ok_when_database_is_reachable(self):
        response = self.client.get(reverse("core:health"))

        self.assertEqual(response.status_code, 200)
        body = response.json()
        self.assertEqual(body["status"], "ok")
        self.assertEqual(body["message"], "Hear & Speak Together API is running")
        self.assertEqual(body["database"], "connected")

    def test_health_requires_no_authentication(self):
        """The client calls this before a user has ever logged in."""
        response = self.client.get("/api/health/")

        self.assertNotIn(response.status_code, (401, 403))

    def test_health_reports_degraded_when_database_is_unreachable(self):
        with patch(
            "apps.core.views._database_is_reachable", return_value=False
        ):
            response = self.client.get(reverse("core:health"))

        self.assertEqual(response.status_code, 503)
        body = response.json()
        self.assertEqual(body["status"], "degraded")
        self.assertEqual(body["database"], "unavailable")


class ConfigurationTests(TestCase):
    """Guard rails that keep secrets out of the repository."""

    def test_postgresql_backend_is_configured(self):
        engine = settings.DATABASES["default"]["ENGINE"]
        self.assertIn("postgresql", engine)

    def test_secret_key_is_not_a_hardcoded_placeholder(self):
        self.assertTrue(settings.SECRET_KEY)
        self.assertNotIn("django-insecure", settings.SECRET_KEY)

    def test_jwt_signing_key_tracks_secret_key(self):
        self.assertEqual(settings.SIMPLE_JWT["SIGNING_KEY"], settings.SECRET_KEY)

    def test_drf_defaults_to_authenticated_access(self):
        """Only endpoints that opt out (like health) may be public."""
        self.assertIn(
            "rest_framework.permissions.IsAuthenticated",
            settings.REST_FRAMEWORK["DEFAULT_PERMISSION_CLASSES"],
        )
