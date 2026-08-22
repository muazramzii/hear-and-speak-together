# Deployment

The project runs locally without any of this. Read it when you are ready to put
the API somewhere a phone can reach it.

---

## What needs hosting

| Piece | Where it goes |
| --- | --- |
| Django API | A Python host with enough CPU/RAM to run Whisper (Render, Railway, Fly.io, a VPS) |
| PostgreSQL | A managed database, or the same host |
| Flutter app | An APK you install or distribute |
| Whisper | Runs inside the Django process — no separate service, but the host needs the disk space and RAM for the model weights |

The mobile app is not "deployed"; it is built. Speech recognition is not
"deployed" either — it is part of the Django API itself. Only the API needs
a home, and it needs enough resources to hold a Whisper model in memory and
run inference on CPU (or GPU, if `WHISPER_DEVICE=cuda` is available on the
host).

---

## Before anything else

**Generate a new `SECRET_KEY` for production.** The development one has been on
your machine and must not follow the app into production.

```bash
python -c "import secrets; print(secrets.token_urlsafe(50))"
```

**Never commit `.env`.** The repository is public. `AI_API_KEY` belongs only
in the host's environment-variable settings, never in `.env.example`, tests,
or documentation. There is no speech-provider key to protect — recognition
runs entirely on infrastructure this project already controls.

---

## Production environment

```
SECRET_KEY=<a fresh one>
DEBUG=False
ALLOWED_HOSTS=api.yourdomain.com
DATABASE_URL=postgres://user:password@host:5432/dbname
CORS_ALLOWED_ORIGINS=https://yourdomain.com

SPEECH_PROVIDER=whisper
WHISPER_MODEL_SIZE=base
WHISPER_DEVICE=cpu
WHISPER_COMPUTE_TYPE=int8

AI_PROVIDER=mock
ENABLE_AI_FEEDBACK=False
STORE_AUDIO=False
```

The first request after deploy that actually needs Whisper will download and
cache the model weights, which can be slow on an unauthenticated connection
(see [pronunciation-engine.md](pronunciation-engine.md)) — consider warming
this up deliberately (e.g. a one-off `manage.py shell` call that loads the
model) rather than letting a child's first real attempt be the first
download.

`DEBUG=False` is the switch that matters. With it off, `config/settings.py`
applies the security settings below automatically.

---

## Security settings

Applied only when `DEBUG=False`, so local development over plain HTTP still
works:

| Setting | Default | Why |
| --- | --- | --- |
| `SECURE_SSL_REDIRECT` | `True` | Plain HTTP redirects to HTTPS |
| `SECURE_PROXY_SSL_HEADER` | on when `BEHIND_TLS_PROXY=True` | Lets Django see through a TLS-terminating proxy |
| `SECURE_HSTS_SECONDS` | `3600` | One hour, not a year — see below |
| `SESSION_COOKIE_SECURE` | `True` | Cookies over HTTPS only |
| `CSRF_COOKIE_SECURE` | `True` | Same |
| `SECURE_CONTENT_TYPE_NOSNIFF` | `True` | No MIME sniffing |
| `X_FRAME_OPTIONS` | `DENY` | No framing |

**Two of these need thought rather than copying.**

`BEHIND_TLS_PROXY` defaults to `True` because most managed hosts terminate TLS
at a proxy. If you deploy *without* one, set it to `False` — otherwise a client
could forge the `X-Forwarded-Proto` header and make Django believe an insecure
request was secure.

`SECURE_HSTS_SECONDS` is deliberately one hour. HSTS is hard to undo: browsers
remember it, so a mistake locks users out of a domain for the full duration.
Raise it to `31536000` (a year) only once HTTPS is proven on the real domain.

Verify with:

```bash
python manage.py check --deploy
```

With `DEBUG=False` this drops from five warnings to **two**, and both remaining
ones are deliberate:

| Warning | Why it is left |
| --- | --- |
| `security.W005` HSTS `includeSubDomains` | Django's own text says *"only set this to True if you are certain that all subdomains should be served exclusively via SSL."* On a shared host, enabling it can break sibling subdomains. |
| `security.W021` HSTS preload | Submitting to the browser preload list is effectively irreversible. |

Both are opt-in once you are sure:

```
SECURE_HSTS_INCLUDE_SUBDOMAINS=True
SECURE_HSTS_PRELOAD=True
SECURE_HSTS_SECONDS=31536000
```

---

## Deploy steps

```bash
pip install -r requirements.txt
```

```bash
python manage.py migrate
```

```bash
python manage.py collectstatic --noinput
```

```bash
python manage.py seed_data
```

```bash
python manage.py seed_achievements
```

```bash
python manage.py createsuperuser
```

Then run it under a real WSGI server — `manage.py runserver` is a development
tool and must not be used in production:

```bash
gunicorn config.wsgi:application --bind 0.0.0.0:8000
```

`gunicorn` and `whitenoise` are both in `requirements.txt`. WhiteNoise is wired
into `MIDDLEWARE` and serves the admin's CSS and JS, with compressed,
hash-named files in production — so the admin does not arrive unstyled.

---

## Building the app

Point the build at the deployed API. The URL is compile-time, so no build can
ship with the wrong host by accident:

```bash
flutter build apk --release --dart-define=API_BASE_URL=https://api.yourdomain.com/api
```

The output lands in `build/app/outputs/flutter-apk/app-release.apk`.

**Once the API is on HTTPS, the cleartext exception can go.** Development hosts
are permitted plain HTTP in
`android/app/src/main/res/xml/network_security_config.xml`; a production build
should not carry that allowance.

A release build also needs a signing key. An unsigned debug APK is fine for a
demonstration; the Play Store is not.

---

## Costs

| Service | Notes |
| --- | --- |
| Speech recognition | No per-call cost — Whisper runs on the API host's own CPU/RAM, already being paid for |
| PostgreSQL | Free tiers exist on most hosts |
| API host | Free tiers usually sleep when idle; expect a slow first request, and a Whisper host needs more RAM than a typical free tier offers |
| LLM feedback | Off by default. Leave it off unless demonstrating it — it is the only piece of this pipeline with a genuine per-call cost |

The controls that keep this near zero — mock providers by default,
on-device TTS, no stored audio — are described in
[pronunciation-engine.md](pronunciation-engine.md).

---

## Before a demo

1. Set `SPEECH_PROVIDER=whisper` and practise one real word well before the
   demo, not the night before. **This is the step most likely to surprise
   you**: the first real transcription on a cold cache can trigger a slow
   model download (see [pronunciation-engine.md](pronunciation-engine.md)).
2. Confirm the APK reaches the deployed API, not `localhost`.
3. Seed content and create at least one profile with practice history, so the
   progress screens are not empty.
4. If the host sleeps when idle, wake it first — and remember a cold Whisper
   model adds to that wake-up time.
