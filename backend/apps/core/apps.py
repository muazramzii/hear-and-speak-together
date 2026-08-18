from django.apps import AppConfig


class CoreConfig(AppConfig):
    """Cross-cutting concerns: health checks and shared utilities."""

    default_auto_field = "django.db.models.BigAutoField"
    name = "apps.core"
    label = "core"
    verbose_name = "Core"
