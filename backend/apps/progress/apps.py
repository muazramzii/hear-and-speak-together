from django.apps import AppConfig


class ProgressConfig(AppConfig):
    """Learning analytics, achievements and supervisor access."""

    default_auto_field = "django.db.models.BigAutoField"
    name = "apps.progress"
    label = "progress"
    verbose_name = "Progress"
