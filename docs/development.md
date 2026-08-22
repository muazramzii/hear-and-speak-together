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
| `SPEECH_PROVIDER` | Phase 10 | `whisper` or `mock`. Default `mock`. |
| `WHISPER_MODEL_SIZE` | Phase 10 | `base` by default; larger models trade a slower first download for accuracy. |
| `WHISPER_DEVICE` | Phase 10 | `cpu` by default; `cuda` if a GPU is available. |
| `WHISPER_COMPUTE_TYPE` | Phase 10 | `int8` by default. |
| `PRONUNCIATION_WEIGHT_SIMILARITY` / `_CONFIDENCE` / `_COMPLETENESS` | Phase 10 | Score weights; must sum to 1.0. |
| `AI_PROVIDER` | Phase 5 | `gemini`, `openai`, or `mock`. |
| `AI_API_KEY` | Phase 5 | Optional feedback layer. |
| `ENABLE_AI_FEEDBACK` | Phase 5 | Cost control. Default `False`. |
| `STORE_AUDIO` | Phase 4 | Cost control. Default `False`. |

See [pronunciation-engine.md](pronunciation-engine.md) for what each Whisper
and scoring-weight setting actually does.

English's grapheme-to-phoneme step (`g2p_en`) needs two NLTK resources on
first use. Fetch them ahead of time so the first real practice attempt is not
also the first download:

```bash
python -c "import nltk; nltk.download('averaged_perceptron_tagger_eng'); nltk.download('cmudict')"
```

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

Both suites are fully offline. Whisper and any LLM provider are reached only
through service abstractions that are replaced with mock implementations
under test, so running the suite never loads a real speech model, never
incurs an API charge, and never requires a key. This is a hard rule, not a
convenience.

---

## Static analysis

```bash
flutter analyze
```

```bash
python manage.py check
```

---

## Adding illustrations

Words fall back to an emoji when no illustration is set. To add real artwork
without 62 admin edits, work through a CSV:

```bash
python manage.py import_word_images --template words.csv
```

That writes one row per word — `language`, `category`, `word`, `emoji`,
`image_url` — already filled in with what is there now. Put your URLs in the
`image_url` column, then preview:

```bash
python manage.py import_word_images words.csv --dry-run
```

```bash
python manage.py import_word_images words.csv
```

Behaviour worth knowing:

- **Blank cells are left alone**, not cleared. A partly filled sheet only
  updates what it fills in, so re-importing a stale template is a no-op.
- **Unmatched or invalid rows are reported, never silently skipped.** A row
  quietly ignored would mean an illustration you believe is live but which
  never appears.
- **An ambiguous word is refused, not guessed.** If a word exists in both
  languages, add a `language` column rather than let the command attach the
  picture to the wrong learner's word.
- The file is read as `utf-8-sig`, so a sheet saved from Excel imports
  correctly instead of mangling the first column and every emoji.

Once an `image_url` is set it takes precedence over the emoji automatically —
no client change needed.

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
- **Gives every attempt the same score fields, regardless of language.**
  There is no per-locale metric to withhold in this architecture — a test
  asserts English and Malay demo attempts carry the same shape.

Override the account with `--email` and `--password`.

---

## Cost control while developing

- Keep `ENABLE_AI_FEEDBACK=False` unless you are specifically testing the
  feedback layer — it is the only piece of this pipeline with a per-call
  cost.
- Keep `STORE_AUDIO=False` so practice recordings are not persisted.
- Keep `SPEECH_PROVIDER=mock` unless you are specifically testing real
  recognition — the real Whisper model adds noticeable latency on CPU and,
  on a cold cache, a slow first download (see
  [pronunciation-engine.md](pronunciation-engine.md)).
- Never trigger a speech assessment from a widget's `build()` method — it
  runs on every rebuild.
- Use the mock services for anything other than deliberate integration checks.
