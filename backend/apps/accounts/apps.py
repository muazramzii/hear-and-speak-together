from django.apps import AppConfig


class AccountsConfig(AppConfig):
    """Users, roles and JWT authentication."""

    default_auto_field = "django.db.models.BigAutoField"
    name = "apps.accounts"
    label = "accounts"
    verbose_name = "Accounts"
