# Hear & Speak Together

A bilingual (English / Bahasa Melayu) mobile speech-learning application that
helps children practise listening and speaking. Children hear a target word,
record themselves saying it, and receive a pronunciation score with friendly,
age-appropriate feedback.

> **Status: feature-complete through Phase 8.**
> Authentication, bilingual content, Azure pronunciation assessment, four
> learning modes, analytics, achievements and a parent/teacher dashboard are
> all built and tested. **The Azure integration has not yet been run against a
> real Azure subscription** — see [docs/azure-speech.md](docs/azure-speech.md).

---

## Architecture

| Layer | Technology |
| --- | --- |
| Mobile client | Flutter (Dart), Riverpod, Dio, go_router |
| API | Django + Django REST Framework |
| Database | PostgreSQL |
| Authentication | JWT (`djangorestframework-simplejwt`), `flutter_secure_storage` |
| Pronunciation assessment | Azure AI Speech, server-side only |
| Feedback | Deterministic rules, with an optional LLM layer |
| Analytics | Rule-based, in Django — no ML, no LLM |

Azure and LLM credentials live **only** on the Django server. The Flutter app
never holds a speech or AI key; it uploads audio to Django, and Django talks to
Azure on its behalf.

```
Flutter  ──HTTPS──>  Django REST API  ──>  Azure AI Speech
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
│   │   ├── core/            health check + shared utilities
│   │   └── accounts/        custom User, JWT auth, role permissions
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

## Tests

Backend:

```bash
cd backend && .venv\Scripts\python.exe manage.py test
```

Mobile:

```bash
cd mobile && flutter test
```

Neither suite makes a network call to Azure or to any LLM provider, so tests
run offline and cost nothing.

---

## Security notes

- `.env` is git-ignored; only `.env.example` is committed.
- `SECRET_KEY`, `DATABASE_URL`, `AZURE_SPEECH_KEY` and `AI_API_KEY` are read
  from the environment and never hardcoded.
- Plain HTTP is permitted on Android for development hosts only
  (`10.0.2.2`, `localhost`, `127.0.0.1`) via
  `android/app/src/main/res/xml/network_security_config.xml`. Everything else,
  including production, must use HTTPS.

---

## Documentation

| Document | What it covers |
| --- | --- |
| [architecture.md](docs/architecture.md) | Design decisions and why each was made |
| [azure-speech.md](docs/azure-speech.md) | How pronunciation is scored, and the locale limits |
| [database.md](docs/database.md) | Schema, and why it is shaped this way |
| [api.md](docs/api.md) | Every endpoint, with request and response shapes |
| [development.md](docs/development.md) | Day-to-day commands and environment variables |
| [testing.md](docs/testing.md) | What is tested, and what is not |
| [deployment.md](docs/deployment.md) | Going live, and production hardening |

**Start with [azure-speech.md](docs/azure-speech.md)** if you want the single
most important design decision: why an acoustic service scores pronunciation
and a language model never does.

---

## Tests

**303 tests** — 210 backend, 93 Flutter. All run offline and call no paid API.

```bash
cd backend && .venv\Scripts\python.exe manage.py test
```

```bash
cd mobile && flutter test
```
