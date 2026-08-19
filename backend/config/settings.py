"""
Django settings for the "Hear & Speak Together" backend.

All environment-specific values are loaded from a `.env` file (see
`.env.example`). No secret is ever hardcoded in this module.
"""

import os
from datetime import timedelta
from pathlib import Path

import dj_database_url
from django.core.exceptions import ImproperlyConfigured
from dotenv import load_dotenv

# ---------------------------------------------------------------------------
# Paths & environment loading
# ---------------------------------------------------------------------------
BASE_DIR = Path(__file__).resolve().parent.parent

load_dotenv(BASE_DIR / ".env")


def env_str(name, default=None, *, required=False):
    value = os.getenv(name, default)
    if required and not value:
        raise ImproperlyConfigured(
            "Missing required environment variable "
            + name
            + ". Copy .env.example to .env and fill it in."
        )
    return value


def env_bool(name, default=False):
    raw = os.getenv(name)
    if raw is None:
        return default
    return raw.strip().lower() in {"1", "true", "yes", "on"}


def env_list(name, default=""):
    raw = os.getenv(name, default) or ""
    return [item.strip() for item in raw.split(",") if item.strip()]


# ---------------------------------------------------------------------------
# Core security settings
# ---------------------------------------------------------------------------
SECRET_KEY = env_str("SECRET_KEY", required=True)
DEBUG = env_bool("DEBUG", default=False)
ALLOWED_HOSTS = env_list("ALLOWED_HOSTS", "localhost,127.0.0.1")

# ---------------------------------------------------------------------------
# Applications
# ---------------------------------------------------------------------------
DJANGO_APPS = [
    "django.contrib.admin",
    "django.contrib.auth",
    "django.contrib.contenttypes",
    "django.contrib.sessions",
    "django.contrib.messages",
    "django.contrib.staticfiles",
]

THIRD_PARTY_APPS = [
    "rest_framework",
    "corsheaders",
    "django_filters",
]

LOCAL_APPS = [
    "apps.core",
    "apps.accounts",
    "apps.content",
    "apps.profiles",
    "apps.practice",
    "apps.progress",
]

INSTALLED_APPS = DJANGO_APPS + THIRD_PARTY_APPS + LOCAL_APPS

MIDDLEWARE = [
    "corsheaders.middleware.CorsMiddleware",
    "django.middleware.security.SecurityMiddleware",
    # Serves the admin's CSS and JS in production. Must sit directly after
    # SecurityMiddleware and before everything else.
    "whitenoise.middleware.WhiteNoiseMiddleware",
    "django.contrib.sessions.middleware.SessionMiddleware",
    "django.middleware.common.CommonMiddleware",
    "django.middleware.csrf.CsrfViewMiddleware",
    "django.contrib.auth.middleware.AuthenticationMiddleware",
    "django.contrib.messages.middleware.MessageMiddleware",
    "django.middleware.clickjacking.XFrameOptionsMiddleware",
]

ROOT_URLCONF = "config.urls"

TEMPLATES = [
    {
        "BACKEND": "django.template.backends.django.DjangoTemplates",
        "DIRS": [],
        "APP_DIRS": True,
        "OPTIONS": {
            "context_processors": [
                "django.template.context_processors.request",
                "django.contrib.auth.context_processors.auth",
                "django.contrib.messages.context_processors.messages",
            ],
        },
    },
]

WSGI_APPLICATION = "config.wsgi.application"
ASGI_APPLICATION = "config.asgi.application"

# ---------------------------------------------------------------------------
# Database (PostgreSQL)
# ---------------------------------------------------------------------------
DATABASES = {
    "default": dj_database_url.parse(
        env_str("DATABASE_URL", required=True),
        conn_max_age=600,
    )
}

# ---------------------------------------------------------------------------
# Authentication
# Children, parents and teachers share one email-keyed user model.
# ---------------------------------------------------------------------------
AUTH_USER_MODEL = "accounts.User"

# ---------------------------------------------------------------------------
# Password validation
# ---------------------------------------------------------------------------
AUTH_PASSWORD_VALIDATORS = [
    {"NAME": "django.contrib.auth.password_validation.UserAttributeSimilarityValidator"},
    {"NAME": "django.contrib.auth.password_validation.MinimumLengthValidator"},
    {"NAME": "django.contrib.auth.password_validation.CommonPasswordValidator"},
    {"NAME": "django.contrib.auth.password_validation.NumericPasswordValidator"},
]

# ---------------------------------------------------------------------------
# Internationalisation
# ---------------------------------------------------------------------------
LANGUAGE_CODE = "en-us"
TIME_ZONE = "Asia/Kuala_Lumpur"
USE_I18N = True
USE_TZ = True

# ---------------------------------------------------------------------------
# Static & media files
# ---------------------------------------------------------------------------
STATIC_URL = "static/"
STATIC_ROOT = BASE_DIR / "staticfiles"

# Compressed, hash-named static files so the admin loads correctly behind a
# CDN or a plain host. Only used once `collectstatic` has run.
STORAGES = {
    "default": {
        "BACKEND": "django.core.files.storage.FileSystemStorage",
    },
    "staticfiles": {
        "BACKEND": (
            "django.contrib.staticfiles.storage.StaticFilesStorage"
            if DEBUG
            else "whitenoise.storage.CompressedManifestStaticFilesStorage"
        ),
    },
}
MEDIA_URL = "media/"
MEDIA_ROOT = BASE_DIR / "media"

DEFAULT_AUTO_FIELD = "django.db.models.BigAutoField"

# ---------------------------------------------------------------------------
# Django REST Framework
# ---------------------------------------------------------------------------
REST_FRAMEWORK = {
    "DEFAULT_AUTHENTICATION_CLASSES": (
        "rest_framework_simplejwt.authentication.JWTAuthentication",
    ),
    "DEFAULT_PERMISSION_CLASSES": (
        "rest_framework.permissions.IsAuthenticated",
    ),
    "DEFAULT_FILTER_BACKENDS": (
        "django_filters.rest_framework.DjangoFilterBackend",
    ),
    "DEFAULT_PAGINATION_CLASS": "rest_framework.pagination.PageNumberPagination",
    "PAGE_SIZE": 20,
}

# ---------------------------------------------------------------------------
# Simple JWT
# The dependency is wired up in Phase 1; auth endpoints arrive in Phase 2.
# ---------------------------------------------------------------------------
SIMPLE_JWT = {
    "ACCESS_TOKEN_LIFETIME": timedelta(minutes=60),
    "REFRESH_TOKEN_LIFETIME": timedelta(days=7),
    "ROTATE_REFRESH_TOKENS": True,
    "BLACKLIST_AFTER_ROTATION": False,
    "AUTH_HEADER_TYPES": ("Bearer",),
    "SIGNING_KEY": SECRET_KEY,
}

# ---------------------------------------------------------------------------
# CORS
# Native Flutter clients send no Origin header and are unaffected by CORS.
# These entries exist for Flutter Web and browser-based tooling.
# ---------------------------------------------------------------------------
CORS_ALLOWED_ORIGINS = env_list("CORS_ALLOWED_ORIGINS")
CORS_ALLOW_CREDENTIALS = True

# ---------------------------------------------------------------------------
# Speech / AI configuration (consumed from Phase 3 onwards).
# Read here so credentials stay server-side and stay out of the mobile app.
# ---------------------------------------------------------------------------
AZURE_SPEECH_KEY = env_str("AZURE_SPEECH_KEY", default="")
AZURE_SPEECH_REGION = env_str("AZURE_SPEECH_REGION", default="")

# Which pronunciation assessment implementation to use: "azure" or "mock".
# Defaults to mock so a fresh checkout, and the entire test suite, never
# spends money or needs a key.
SPEECH_PROVIDER = env_str("SPEECH_PROVIDER", default="mock")

AI_PROVIDER = env_str("AI_PROVIDER", default="mock")
AI_API_KEY = env_str("AI_API_KEY", default="")
# Blank falls back to the provider's default model (see ai/factory.py).
AI_MODEL = env_str("AI_MODEL", default="")

ENABLE_AI_FEEDBACK = env_bool("ENABLE_AI_FEEDBACK", default=False)
STORE_AUDIO = env_bool("STORE_AUDIO", default=False)

# ---------------------------------------------------------------------------
# Production hardening
#
# Applied only when DEBUG is off, so local development over plain HTTP still
# works. Every value is overridable, because the right setting depends on how
# the app is fronted (a reverse proxy terminating TLS needs different handling
# from a direct deployment).
# ---------------------------------------------------------------------------
if not DEBUG:
    SECURE_SSL_REDIRECT = env_bool("SECURE_SSL_REDIRECT", default=True)

    # Tells Django a request arrived over HTTPS when TLS is terminated by a
    # proxy. Without it, SECURE_SSL_REDIRECT sees plain HTTP and loops.
    # Only safe when a proxy actually sets this header - a direct deployment
    # should leave it off, since a client could otherwise forge it.
    if env_bool("BEHIND_TLS_PROXY", default=True):
        SECURE_PROXY_SSL_HEADER = ("HTTP_X_FORWARDED_PROTO", "https")

    # Deliberately one hour, not a year. HSTS is hard to undo - browsers
    # remember it - so a short window is the safe default for a first
    # deployment. Raise it once HTTPS is proven to work on the real domain.
    SECURE_HSTS_SECONDS = int(env_str("SECURE_HSTS_SECONDS", default="3600"))
    SECURE_HSTS_INCLUDE_SUBDOMAINS = env_bool(
        "SECURE_HSTS_INCLUDE_SUBDOMAINS", default=False
    )
    SECURE_HSTS_PRELOAD = env_bool("SECURE_HSTS_PRELOAD", default=False)

    SESSION_COOKIE_SECURE = True
    CSRF_COOKIE_SECURE = True
    SECURE_CONTENT_TYPE_NOSNIFF = True
    X_FRAME_OPTIONS = "DENY"

# ---------------------------------------------------------------------------
# Logging
# Technical detail goes to the server log; never secrets, tokens or audio.
# ---------------------------------------------------------------------------
LOGGING = {
    "version": 1,
    "disable_existing_loggers": False,
    "formatters": {
        "verbose": {
            "format": "[{asctime}] {levelname} {name}: {message}",
            "style": "{",
        },
    },
    "handlers": {
        "console": {
            "class": "logging.StreamHandler",
            "formatter": "verbose",
        },
    },
    "root": {
        "handlers": ["console"],
        "level": "INFO",
    },
    "loggers": {
        "django.db.backends": {
            "handlers": ["console"],
            "level": "WARNING",
            "propagate": False,
        },
        "apps": {
            "handlers": ["console"],
            "level": "DEBUG" if DEBUG else "INFO",
            "propagate": False,
        },
    },
}
