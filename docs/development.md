# Development guide

Day-to-day commands and the environment this project expects.

---

## Verified toolchain

Phase 1 was built and validated against:

| Tool | Version |
| --- | --- |
| Python | 3.12.10 |
| Django | 5.2.17 |
| Django REST Framework | 3.18.0 |
| psycopg | 3.3.4 (binary) |
| PostgreSQL | 18.4 |
| Flutter | 3.29.2 (stable) |
| Dart | 3.7.2 |

---

## Running the backend

From `backend/`, with the virtual environment active:

```bash
python manage.py runserver 0.0.0.0:8000
```

Binding to `0.0.0.0` rather than `127.0.0.1` matters: the Android emulator
reaches the host through `10.0.2.2`, and a physical device reaches it through
the machine's LAN IP. Neither can see a loopback-only server.

Add whichever host you use to `ALLOWED_HOSTS` in `backend/.env`.

---

## Running the mobile app

The API base URL is a compile-time constant supplied with `--dart-define`,
so no build ever ships with the wrong host baked in.

Android emulator (uses the default, no flag needed):

```bash
flutter run
```

Browser, useful when no emulator is running:

```bash
flutter run -d chrome --web-port=3000 --dart-define=API_BASE_URL=http://127.0.0.1:8000/api
```

Physical Android device on the same Wi-Fi:

```bash
flutter run --dart-define=API_BASE_URL=http://192.168.1.10:8000/api
```

Replace the IP with your machine's. Remember to add both the IP to
`ALLOWED_HOSTS` and, for web builds, the browser origin to
`CORS_ALLOWED_ORIGINS`.

---

## Environment variables

`backend/.env` is git-ignored. `backend/.env.example` is the committed
template — keep them in sync whenever a new setting is introduced.

| Variable | Used from | Notes |
| --- | --- | --- |
| `SECRET_KEY` | Phase 1 | Also signs JWTs. Required. |
| `DEBUG` | Phase 1 | `False` in production. |
| `ALLOWED_HOSTS` | Phase 1 | Comma-separated. |
| `DATABASE_URL` | Phase 1 | `postgres://user:pass@host:port/db`. Required. |
| `CORS_ALLOWED_ORIGINS` | Phase 1 | Comma-separated. Web/tooling only. |
| `AZURE_SPEECH_KEY` | Phase 3 | Server-side only, never in the app. |
| `AZURE_SPEECH_REGION` | Phase 3 | e.g. `southeastasia`. |
| `AI_PROVIDER` | Phase 5 | `gemini`, `openai`, or `mock`. |
| `AI_API_KEY` | Phase 5 | Optional feedback layer. |
| `ENABLE_AI_FEEDBACK` | Phase 5 | Cost control. Default `False`. |
| `STORE_AUDIO` | Phase 4 | Cost control. Default `False`. |

Generate a fresh secret key with:

```bash
python -c "import secrets; print(secrets.token_urlsafe(50))"
```

---

## Tests

```bash
python manage.py test
```

```bash
flutter test
```

Both suites are fully offline. Azure AI Speech and any LLM provider are
reached only through service abstractions that are replaced with mock
implementations under test, so running the suite never incurs an API charge
and never requires a key. This is a hard rule, not a convenience.

---

## Static analysis

```bash
flutter analyze
```

```bash
python manage.py check
```

---

## Demo data

To walk through the app without practising a dozen words by hand first:

```bash
python manage.py seed_data
```

```bash
python manage.py seed_achievements
```

```bash
python manage.py seed_demo
```

That creates `demo@hearspeak.test` / `HearSpeak!2026` — a **parent** account, so
the supervisor view is reachable too — with two learners:

| Learner | Language | History |
| --- | --- | --- |
| Ali | Bahasa Melayu | 20 attempts, average 75, 294 points |
| Sofia | English | 27 attempts, average 79, 343 points |

Both have a 5-day streak, earned badges, and two deliberately weak words each
so the weak-word analytics have something real to flag.

It is idempotent: re-running rebuilds the same history rather than piling more
on top, so the figures stay predictable for a walkthrough or screenshots.

Two things it does deliberately:

- **Refuses to run with `DEBUG=False`.** The password is written in the source,
  so the command will not touch a production database without `--force`.
- **Never gives a Malay attempt a prosody score.** Azure does not assess
  prosody for `ms-MY`, and demo data must not imply a measurement the real
  system cannot make. A test asserts this.

Override the account with `--email` and `--password`.

---

## Cost control while developing

- Keep `ENABLE_AI_FEEDBACK=False` unless you are specifically testing the
  feedback layer.
- Keep `STORE_AUDIO=False` so practice recordings are not persisted.
- Never trigger a speech assessment from a widget's `build()` method — it
  runs on every rebuild and each call costs money.
- Use the mock services for anything other than deliberate integration checks.
