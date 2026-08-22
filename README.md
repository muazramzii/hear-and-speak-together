# Hear & Speak Together

A bilingual (English / Bahasa Melayu) mobile speech-learning application that
helps children practise listening and speaking. Children hear a target word,
record themselves saying it, and receive a pronunciation score with friendly,
age-appropriate feedback.

> **Status: feature-complete through Phase 10.**
> Authentication, bilingual content, self-hosted speech recognition and
> pronunciation scoring, four learning modes, analytics, achievements and a
> parent/teacher dashboard are all built and tested — see
> [docs/pronunciation-engine.md](docs/pronunciation-engine.md) for how
> pronunciation is scored.

To see it running, follow [Backend setup](#backend-setup), then
`python manage.py seed_data`, `seed_achievements` and `seed_demo`, and sign in
as `demo@hearspeak.test` / `HearSpeak!2026`.

---

## Architecture

| Layer | Technology |
| --- | --- |
| Mobile client | Flutter (Dart), Riverpod, Dio, go_router |
| API | Django + Django REST Framework |
| Database | PostgreSQL |
| Authentication | JWT (`djangorestframework-simplejwt`), `flutter_secure_storage` |
| Speech recognition | Self-hosted Whisper (`faster-whisper`), server-side only |
| Pronunciation scoring | Custom deterministic Python engine (phonetic-feature distance, no ML, no LLM) |
| Feedback | Deterministic rules, with an optional LLM layer |
| Analytics | Rule-based, in Django — no ML, no LLM |

Recognition and scoring both run **only** on the Django server. The Flutter
app never holds a speech key and never talks to a speech provider directly —
it uploads audio to Django, and everything after that happens in-process.
There is no paid API anywhere in this pipeline.

```
Flutter  ──HTTPS──>  Django REST API  ──>  Whisper (self-hosted)  ──>  PronunciationEngine
                          │
                          └──>  PostgreSQL
```

---

## Repository layout

```
hear and speak/
├── backend/                 Django REST API
│   ├── config/              settings, root URLs, WSGI/ASGI
│   ├── apps/
│   │   ├── core/            health check, API root, seed_demo
│   │   ├── accounts/        custom User, JWT auth, role permissions
│   │   ├── content/         languages, categories, lessons, words
│   │   ├── profiles/        learner profiles and share codes
│   │   ├── practice/        speech assessment, feedback, quiz results
│   │   └── progress/        analytics, achievements, supervisor access
│   ├── requirements.txt
│   └── .env.example         copy to .env and fill in
├── mobile/                  Flutter application
│   └── lib/
│       ├── core/            constants, theme, networking, secure storage
│       ├── models/          plain data classes
│       ├── repositories/    all API access lives here
│       ├── providers/       Riverpod state controllers
│       ├── routes/          go_router configuration
│       ├── widgets/         shared UI components
│       └── features/        one folder per screen area
└── docs/                    project documentation
```

---

## Prerequisites

- Python 3.12+
- PostgreSQL 14+ (developed against 18)
- Flutter 3.29+ with the Dart 3.7 SDK

---

## Backend setup

```bash
cd backend
python -m venv .venv
```

Activate the virtual environment (`.venv\Scripts\activate` on Windows,
`source .venv/bin/activate` elsewhere), then:

```bash
pip install -r requirements.txt
```

Create the database and its role:

```bash
psql -U postgres -c "CREATE ROLE hear_speak_user WITH LOGIN PASSWORD 'choose-a-password' CREATEDB;"
```

```bash
psql -U postgres -c "CREATE DATABASE hear_speak_db OWNER hear_speak_user;"
```

Copy `backend/.env.example` to `backend/.env` and fill in at minimum
`SECRET_KEY` and `DATABASE_URL`. Generate a secret key with:

```bash
python -c "import secrets; print(secrets.token_urlsafe(50))"
```

Then migrate and run:

```bash
python manage.py migrate
```

```bash
python manage.py runserver 0.0.0.0:8000
```

Verify the API:

```bash
curl http://127.0.0.1:8000/api/health/
```

```json
{
  "status": "ok",
  "message": "Hear & Speak Together API is running",
  "database": "connected"
}
```

---

## Mobile setup

```bash
cd mobile
flutter pub get
```

The API host is supplied at build time, because it differs per run target:

| Target | `API_BASE_URL` |
| --- | --- |
| Android emulator | `http://10.0.2.2:8000/api` (the default) |
| iOS simulator | `http://127.0.0.1:8000/api` |
| Physical device | `http://<your-LAN-IP>:8000/api` |
| Web (browser) | `http://127.0.0.1:8000/api` |

Android emulator:

```bash
flutter run
```

Browser, for quick checks without an emulator:

```bash
flutter run -d chrome --web-port=3000 --dart-define=API_BASE_URL=http://127.0.0.1:8000/api
```

When running against a physical device or a non-default web port, add that
origin to `CORS_ALLOWED_ORIGINS` in `backend/.env` and add the host to
`ALLOWED_HOSTS`.

---

## Security notes

- `.env` is git-ignored; only `.env.example` is committed.
- `SECRET_KEY`, `DATABASE_URL` and `AI_API_KEY` are read from the environment
  and never hardcoded.
- Plain HTTP is permitted on Android for development hosts only
  (`10.0.2.2`, `localhost`, `127.0.0.1`) via
  `android/app/src/main/res/xml/network_security_config.xml`. Everything else,
  including production, must use HTTPS.

---

## Documentation

| Document | What it covers |
| --- | --- |
| [architecture.md](docs/architecture.md) | Design decisions and why each was made |
| [pronunciation-engine.md](docs/pronunciation-engine.md) | How pronunciation is scored: self-hosted Whisper plus a custom engine |
| [database.md](docs/database.md) | Schema, and why it is shaped this way |
| [api.md](docs/api.md) | Every endpoint, with request and response shapes |
| [development.md](docs/development.md) | Day-to-day commands and environment variables |
| [testing.md](docs/testing.md) | What is tested, and what is not |
| [deployment.md](docs/deployment.md) | Going live, and production hardening |

**Start with [pronunciation-engine.md](docs/pronunciation-engine.md)** if you
want the single most important design decision: why speech recognition and
pronunciation scoring are two separate stages, and why a language model is
never the source of the score.

---

## Tests

**333 tests** — 236 backend, 97 Flutter. All run offline and call no paid API.

```bash
cd backend && .venv\Scripts\python.exe manage.py test
```

```bash
cd mobile && flutter test
```
