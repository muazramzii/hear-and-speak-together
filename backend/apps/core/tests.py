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


class ApiRootTests(TestCase):
    """GET / must be a helpful signpost rather than a raw 404."""

    def test_root_is_public(self):
        response = self.client.get("/")

        self.assertEqual(response.status_code, 200)

    def test_root_lists_the_entry_points(self):
        body = self.client.get("/").json()

        self.assertEqual(body["name"], "Hear & Speak Together API")
        self.assertIn("version", body)
        for key in (
            "health",
            "authentication",
            "languages",
            "categories",
            "lessons",
            "profiles",
            "admin",
        ):
            self.assertIn(key, body["endpoints"])

    def test_advertised_urls_are_absolute(self):
        endpoints = self.client.get("/").json()["endpoints"]

        for url in endpoints.values():
            self.assertTrue(url.startswith("http"), url)

    def test_the_advertised_health_url_actually_works(self):
        """A signpost pointing at a broken door is worse than no signpost."""
        health_url = self.client.get("/").json()["endpoints"]["health"]

        response = self.client.get(health_url)

        self.assertEqual(response.status_code, 200)


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
