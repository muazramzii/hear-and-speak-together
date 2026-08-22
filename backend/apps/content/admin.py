from django.contrib import admin

from .models import Category, Language, Lesson, Word


class WordInline(admin.TabularInline):
    """Words are edited in the context of their lesson - that is how content
    authors actually think about them."""

    model = Word
    extra = 1
    fields = ["order", "text", "meaning", "image_url", "audio_url", "is_active"]
    ordering = ["order"]


class LessonInline(admin.TabularInline):
    model = Lesson
    extra = 0
    fields = ["order", "title", "difficulty", "is_active"]
    ordering = ["order"]
    show_change_link = True


@admin.register(Language)
class LanguageAdmin(admin.ModelAdmin):
    list_display = ["name", "code", "locale", "tts_voice", "is_active"]
    list_filter = ["is_active"]
    search_fields = ["name", "code", "locale"]


@admin.register(Category)
class CategoryAdmin(admin.ModelAdmin):
    list_display = ["name", "language", "slug", "order", "lesson_count", "is_active"]
    list_filter = ["language", "is_active"]
    search_fields = ["name", "slug"]
    prepopulated_fields = {"slug": ["name"]}
    ordering = ["language", "order"]
    inlines = [LessonInline]

    @admin.display(description="Lessons")
    def lesson_count(self, category):
        return category.lessons.count()


@admin.register(Lesson)
class LessonAdmin(admin.ModelAdmin):
    list_display = [
        "title",
        "category",
        "language_code",
        "difficulty",
        "order",
        "word_count",
        "is_active",
    ]
    list_filter = ["category__language", "difficulty", "is_active", "category"]
    search_fields = ["title", "description"]
    ordering = ["category", "order"]
    inlines = [WordInline]
    list_select_related = ["category", "category__language"]

    @admin.display(description="Language", ordering="category__language__code")
    def language_code(self, lesson):
        return lesson.category.language.code

    @admin.display(description="Words")
    def word_count(self, lesson):
        return lesson.words.count()


@admin.register(Word)
class WordAdmin(admin.ModelAdmin):
    list_display = ["text", "lesson", "language_code", "order", "is_active"]
    list_filter = ["lesson__category__language", "is_active", "lesson__category"]
    search_fields = ["text", "meaning"]
    ordering = ["lesson", "order"]
    filter_horizontal = ["distractors"]
    list_select_related = ["lesson", "lesson__category", "lesson__category__language"]

    @admin.display(description="Language")
    def language_code(self, word):
        return word.lesson.category.language.code
