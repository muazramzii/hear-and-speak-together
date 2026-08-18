from django.apps import AppConfig


class ContentConfig(AppConfig):
    """Languages, categories, lessons and vocabulary."""

    default_auto_field = "django.db.models.BigAutoField"
    name = "apps.content"
    label = "content"
    verbose_name = "Content"
