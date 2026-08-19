from django.contrib import admin

from .models import Achievement, LessonProgress, ProfileAchievement, StudentLink


@admin.register(Achievement)
class AchievementAdmin(admin.ModelAdmin):
    list_display = ["code", "name", "name_ms", "icon", "points", "order"]
    ordering = ["order"]
    search_fields = ["code", "name", "name_ms"]


@admin.register(ProfileAchievement)
class ProfileAchievementAdmin(admin.ModelAdmin):
    list_display = ["profile", "achievement", "earned_at"]
    list_filter = ["achievement", "earned_at"]
    search_fields = ["profile__name"]
    list_select_related = ["profile", "achievement"]
    readonly_fields = ["earned_at"]


@admin.register(LessonProgress)
class LessonProgressAdmin(admin.ModelAdmin):
    list_display = [
        "profile",
        "lesson",
        "completed_words",
        "total_words",
        "percentage",
        "average_score",
        "last_accessed",
    ]
    list_filter = ["lesson__category", "last_accessed"]
    search_fields = ["profile__name", "lesson__title"]
    list_select_related = ["profile", "lesson"]
    # Recalculated from attempts; editing by hand would be overwritten on the
    # next practice anyway.
    readonly_fields = [f.name for f in LessonProgress._meta.fields]

    @admin.display(description="Complete")
    def percentage(self, record):
        return f"{record.completion_percentage}%"


@admin.register(StudentLink)
class StudentLinkAdmin(admin.ModelAdmin):
    list_display = ["supervisor", "profile", "created_at"]
    search_fields = ["supervisor__email", "profile__name"]
    list_select_related = ["supervisor", "profile"]
    autocomplete_fields = ["supervisor"]
