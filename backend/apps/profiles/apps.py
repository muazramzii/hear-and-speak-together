from django.apps import AppConfig


class ProfilesConfig(AppConfig):
    """Learner profiles owned by an account."""

    default_auto_field = "django.db.models.BigAutoField"
    name = "apps.profiles"
    label = "profiles"
    verbose_name = "Profiles"
