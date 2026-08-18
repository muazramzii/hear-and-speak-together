from django.contrib import admin

from .models import Profile


@admin.register(Profile)
class ProfileAdmin(admin.ModelAdmin):
    list_display = [
        "name",
        "owner",
        "practice_language",
        "level",
        "points",
        "streak_days",
        "last_practised_on",
    ]
    list_filter = ["practice_language", "avatar", "created_at"]
    search_fields = ["name", "owner__email", "owner__name"]
    # Level is derived from points, and the streak is maintained by the
    # practice flow. Editing either by hand would desynchronise them.
    readonly_fields = ["level", "created_at", "updated_at"]
    list_select_related = ["owner", "practice_language"]
    autocomplete_fields = ["owner"]
