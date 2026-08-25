from django.apps import AppConfig


class SchoolsConfig(AppConfig):
    """The multi-tenant school/classroom hierarchy (Phase 6)."""

    default_auto_field = "django.db.models.BigAutoField"
    name = "apps.schools"
    label = "schools"
    verbose_name = "Schools"
