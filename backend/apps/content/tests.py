"""Phase 3 tests: bilingual content, language capabilities and quiz rounds."""

from django.contrib.auth import get_user_model
from django.core.management import call_command
from django.test import TestCase
from django.urls import reverse
from rest_framework.test import APITestCase

from .models import Category, Language, Lesson, Word

User = get_user_model()


def seed():
    call_command("seed_data", verbosity=0)


class AuthenticatedAPITestCase(APITestCase):
    """Content is only served to signed-in users."""

    def setUp(self):
        self.user = User.objects.create_user(
            email="amir@example.com", name="Amir", password="TeaCup!2026"
        )
        login = self.client.post(
            reverse("accounts:login"),
            {"email": "amir@example.com", "password": "TeaCup!2026"},
            format="json",
        )
        self.client.credentials(
            HTTP_AUTHORIZATION=f"Bearer {login.json()['access']}"
        )


class SeedDataTests(TestCase):
    def test_seed_creates_both_languages_with_content(self):
        seed()

        self.assertEqual(Language.objects.count(), 2)
        self.assertEqual(Category.objects.filter(language__code="en").count(), 6)
        self.assertEqual(Category.objects.filter(language__code="ms").count(), 6)
        self.assertTrue(Word.objects.filter(lesson__category__language__code="ms").exists())

    def test_seed_is_idempotent(self):
        seed()
        counts = (Language.objects.count(), Category.objects.count(), Word.objects.count())

        seed()

        self.assertEqual(
            (Language.objects.count(), Category.objects.count(), Word.objects.count()),
            counts,
        )

    def test_malay_content_is_authored_not_translated(self):
        """The Malay list must contain real Malay words, not English ones."""
        seed()
        malay_words = set(
            Word.objects.filter(
                lesson__category__language__code="ms"
            ).values_list("text", flat=True)
        )

        self.assertIn("kucing", malay_words)
        self.assertIn("gajah", malay_words)
        self.assertIn("kereta api", malay_words)
        # An English word leaking into the Malay set would mean the content
        # was translated at runtime rather than authored.
        self.assertNotIn("cat", malay_words)
        self.assertNotIn("elephant", malay_words)

    def test_seed_links_distractors(self):
        seed()
        word = Word.objects.filter(text="kucing").first()

        self.assertGreaterEqual(word.distractors.count(), 3)
        self.assertNotIn(word.pk, word.distractors.values_list("pk", flat=True))


class LanguageCapabilityTests(TestCase):
    """The capability flags must reflect Azure's documented behaviour.

    Azure supports prosody assessment for en-US only, and returns phoneme
    *names* only for en-US. Getting this wrong would make the app display a
    score that was never measured.
    """

    def setUp(self):
        seed()

    def test_english_supports_prosody(self):
        english = Language.objects.get(code="en")

        self.assertTrue(english.supports_prosody)
        self.assertIn("prosody", english.available_metrics)

    def test_malay_does_not_support_prosody(self):
        malay = Language.objects.get(code="ms")

        self.assertFalse(malay.supports_prosody)
        self.assertNotIn("prosody", malay.available_metrics)

    def test_malay_does_not_expose_phoneme_names(self):
        malay = Language.objects.get(code="ms")

        self.assertFalse(malay.supports_phoneme_names)
        self.assertFalse(malay.supports_syllable_scores)

    def test_both_locales_support_core_assessment(self):
        for code in ("en", "ms"):
            language = Language.objects.get(code=code)
            self.assertTrue(language.supports_pronunciation_assessment)
            for metric in ("accuracy", "fluency", "completeness", "pronunciation"):
                self.assertIn(metric, language.available_metrics)

    def test_capabilities_record_when_they_were_verified(self):
        self.assertIsNotNone(Language.objects.get(code="ms").capabilities_verified_on)


class LanguageAPITests(AuthenticatedAPITestCase):
    def setUp(self):
        super().setUp()
        seed()

    def test_requires_authentication(self):
        self.client.credentials()
        response = self.client.get("/api/languages/")

        self.assertEqual(response.status_code, 401)

    def test_lists_active_languages_with_capabilities(self):
        response = self.client.get("/api/languages/")

        self.assertEqual(response.status_code, 200)
        by_code = {item["code"]: item for item in response.json()}
        self.assertEqual(by_code["en"]["locale"], "en-US")
        self.assertEqual(by_code["ms"]["locale"], "ms-MY")

    def test_capability_block_reports_prosody_per_locale(self):
        response = self.client.get("/api/languages/")
        by_code = {item["code"]: item for item in response.json()}

        self.assertTrue(by_code["en"]["capabilities"]["prosody"])
        self.assertFalse(by_code["ms"]["capabilities"]["prosody"])
        self.assertNotIn(
            "prosody", by_code["ms"]["capabilities"]["available_metrics"]
        )

    def test_inactive_languages_are_hidden(self):
        Language.objects.filter(code="ms").update(is_active=False)

        codes = [item["code"] for item in self.client.get("/api/languages/").json()]

        self.assertNotIn("ms", codes)


class CategoryAPITests(AuthenticatedAPITestCase):
    def setUp(self):
        super().setUp()
        seed()

    def test_defaults_to_the_users_preferred_language(self):
        self.user.preferred_language = "ms"
        self.user.save()

        response = self.client.get("/api/categories/")

        names = [item["name"] for item in response.json()]
        self.assertIn("Haiwan", names)
        self.assertNotIn("Animals", names)

    def test_language_query_parameter_overrides_the_preference(self):
        self.user.preferred_language = "ms"
        self.user.save()

        response = self.client.get("/api/categories/?language=en")

        names = [item["name"] for item in response.json()]
        self.assertIn("Animals", names)
        self.assertNotIn("Haiwan", names)

    def test_unknown_language_is_rejected(self):
        response = self.client.get("/api/categories/?language=zz")

        self.assertEqual(response.status_code, 404)

    def test_detail_includes_lessons(self):
        category = Category.objects.get(language__code="en", slug="animals")

        response = self.client.get(f"/api/categories/{category.id}/")

        self.assertEqual(response.status_code, 200)
        self.assertGreaterEqual(len(response.json()["lessons"]), 1)


class LessonAPITests(AuthenticatedAPITestCase):
    def setUp(self):
        super().setUp()
        seed()

    def test_lists_lessons_for_the_selected_language_only(self):
        response = self.client.get("/api/lessons/?language=ms")

        titles = [item["title"] for item in response.json()["results"]]
        self.assertIn("Haiwan Di Sekeliling Kita", titles)
        self.assertNotIn("Animals Around Us", titles)

    def test_detail_includes_words_with_meanings(self):
        lesson = Lesson.objects.get(title="Haiwan Di Sekeliling Kita")

        response = self.client.get(f"/api/lessons/{lesson.id}/")

        body = response.json()
        words = {word["text"]: word["meaning"] for word in body["words"]}
        self.assertIn("gajah", words)
        # The meaning is written in the target language, for immersion.
        self.assertIn("belalai", words["gajah"])

    def test_word_count_is_reported(self):
        response = self.client.get("/api/lessons/?language=en")
        first = response.json()["results"][0]

        self.assertGreater(first["word_count"], 0)


class QuizRoundTests(AuthenticatedAPITestCase):
    def setUp(self):
        super().setUp()
        seed()

    def test_returns_the_word_and_multiple_options(self):
        word = Word.objects.get(text="kucing")

        response = self.client.get(f"/api/words/{word.id}/quiz-round/")

        self.assertEqual(response.status_code, 200)
        body = response.json()
        self.assertEqual(body["word"]["text"], "kucing")
        self.assertEqual(len(body["options"]), 4)
        self.assertEqual(body["correct_option_id"], word.id)

    def test_the_correct_answer_is_among_the_options(self):
        word = Word.objects.get(text="gajah")

        body = self.client.get(f"/api/words/{word.id}/quiz-round/").json()

        option_ids = [option["id"] for option in body["options"]]
        self.assertIn(word.id, option_ids)

    def test_options_never_mix_languages(self):
        word = Word.objects.get(text="kucing")

        body = self.client.get(f"/api/words/{word.id}/quiz-round/").json()

        option_ids = [option["id"] for option in body["options"]]
        languages = set(
            Word.objects.filter(id__in=option_ids).values_list(
                "lesson__category__language__code", flat=True
            )
        )
        self.assertEqual(languages, {"ms"})

    def test_options_are_distinct(self):
        word = Word.objects.get(text="anjing")

        body = self.client.get(f"/api/words/{word.id}/quiz-round/").json()

        option_ids = [option["id"] for option in body["options"]]
        self.assertEqual(len(option_ids), len(set(option_ids)))


class QuizFallbackTests(TestCase):
    """A lesson too small to supply distractors must still produce a round."""

    def setUp(self):
        self.language = Language.objects.create(
            code="en", name="English", locale="en-US"
        )
        self.category = Category.objects.create(
            language=self.language, slug="tiny", name="Tiny"
        )
        self.lesson_a = Lesson.objects.create(category=self.category, title="A")
        self.lesson_b = Lesson.objects.create(category=self.category, title="B")

        self.word = Word.objects.create(lesson=self.lesson_a, text="solo")
        for text in ("alpha", "beta", "gamma"):
            Word.objects.create(lesson=self.lesson_b, text=text)

    def test_fills_options_from_the_wider_category(self):
        options = self.word.quiz_options(count=4)

        self.assertEqual(len(options), 4)
        self.assertEqual(options[0], self.word)
        self.assertNotIn(self.word, options[1:])
