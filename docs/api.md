# API reference

Base URL: `/api`

All request and response bodies are JSON. Authenticated endpoints expect:

```
Authorization: Bearer <access token>
```

---

## Health

### `GET /api/health/`

Public. Reports whether the API is running and whether it can reach PostgreSQL.

```json
{
  "status": "ok",
  "message": "Hear & Speak Together API is running",
  "database": "connected"
}
```

Returns `503` with `"status": "degraded"` and `"database": "unavailable"` when
the database cannot be reached.

---

## Authentication

JWT via `djangorestframework-simplejwt`. Access tokens last 60 minutes,
refresh tokens 7 days, and refresh tokens rotate on use.

### `POST /api/auth/register/`

Public. Creates an account and signs the user in immediately, so the client
does not have to post the credentials a second time.

Request:

```json
{
  "name": "Amir Rahman",
  "email": "amir@example.com",
  "password": "TeaCup!2026",
  "password_confirm": "TeaCup!2026",
  "role": "STUDENT",
  "preferred_language": "ms"
}
```

`role` is one of `STUDENT`, `PARENT`, `TEACHER` (default `STUDENT`).
`preferred_language` is `en` or `ms` (default `en`).

Response `201`:

```json
{
  "user": {
    "id": 1,
    "name": "Amir Rahman",
    "email": "amir@example.com",
    "role": "STUDENT",
    "preferred_language": "ms",
    "created_at": "2026-08-18T15:42:11.104Z"
  },
  "access": "<jwt>",
  "refresh": "<jwt>"
}
```

Errors `400` — per-field, in DRF's standard shape:

```json
{ "email": ["An account with this email already exists."] }
```

Password strength is enforced by Django's configured validators, so short,
common or entirely numeric passwords are rejected. `is_staff` and
`is_superuser` are not accepted here and can only be granted from the admin.

### `POST /api/auth/login/`

Public. Email matching is case-insensitive.

Request:

```json
{ "email": "amir@example.com", "password": "TeaCup!2026" }
```

Response `200`: the same shape as register — `user`, `access`, `refresh`.

Returns `401` for a wrong password, an unknown email, or a deactivated
account. The three are deliberately indistinguishable so the endpoint cannot
be used to discover which addresses have accounts.

### `POST /api/auth/refresh/`

Public. Exchanges a refresh token for a new access token.

Request:

```json
{ "refresh": "<jwt>" }
```

Response `200`:

```json
{ "access": "<jwt>", "refresh": "<jwt>" }
```

Because rotation is enabled, a **new refresh token comes back too** and the
client must store it. Continuing to use the old one will fail.

Returns `401` for an expired or malformed token.

### `GET /api/auth/me/`

Authenticated. Returns the signed-in user. The user is always taken from the
token, never from a URL parameter, so one account can never read another.

```json
{
  "id": 1,
  "name": "Amir Rahman",
  "email": "amir@example.com",
  "role": "STUDENT",
  "preferred_language": "ms",
  "created_at": "2026-08-18T15:42:11.104Z"
}
```

### `PATCH /api/auth/me/`

Authenticated. Updates the display name and practice language.

```json
{ "name": "Amir R.", "preferred_language": "en" }
```

`email` and `role` are **not** editable here — both have security or
data-ownership consequences and are admin-only. Sending them is ignored rather
than rejected. The full user object is returned.

---

## Roles and permissions

| Role | Meaning |
| --- | --- |
| `STUDENT` | The learner. Practises words and records attempts. |
| `PARENT` | Monitors linked students. |
| `TEACHER` | Monitors linked students. |

Two permission classes back these, in `apps/accounts/permissions.py`:
`IsStudent`, and `IsParentOrTeacher` for the shared monitoring views. No
endpoint is gated on them yet — the practice and dashboard APIs that use them
arrive in later phases.

---

## Error shapes

| Status | Meaning |
| --- | --- |
| `400` | Validation failed. Body maps field names to message lists. |
| `401` | Missing, invalid or expired token; or wrong sign-in credentials. |
| `403` | Authenticated, but the role is not allowed. |
| `404` | No such resource. |
| `503` | A dependency (currently the database) is unavailable. |

The Flutter client converts all of these into `ApiException`, whose `message`
is always safe to display to a child. Raw server wording is never shown.

---

## Content

All content endpoints require authentication and are read-only — lessons are
authored in the Django admin, never by the app.

### `GET /api/languages/`

Returns each active language **with its Azure capability block**. The client
must use this to decide which pronunciation metrics to display.

```json
[
  {
    "id": 1, "code": "en", "name": "English", "locale": "en-US",
    "tts_voice": "en-US-AnaNeural",
    "capabilities": {
      "pronunciation_assessment": true,
      "prosody": true,
      "phoneme_names": true,
      "syllable_scores": true,
      "available_metrics": ["accuracy", "fluency", "completeness", "pronunciation", "prosody"]
    }
  },
  {
    "id": 2, "code": "ms", "name": "Bahasa Melayu", "locale": "ms-MY",
    "tts_voice": "ms-MY-YasminNeural",
    "capabilities": {
      "pronunciation_assessment": true,
      "prosody": false,
      "phoneme_names": false,
      "syllable_scores": false,
      "available_metrics": ["accuracy", "fluency", "completeness", "pronunciation"]
    }
  }
]
```

**Why this endpoint matters.** Azure documents prosody assessment as `en-US`
only, and returns phoneme *names* only for `en-US` — for other locales just a
phoneme score, with no phoneme identity. The app therefore must not render an
intonation result for a Malay word: Azure never measured one. Rendering a
plausible-looking value would be fabricating data.

Verified against Microsoft Learn on 2026-08-19; the date is stored on each
row as `capabilities_verified_on`.

### `GET /api/categories/` · `GET /api/categories/{id}/`

Not paginated. Filtered by language: `?language=en|ms`. When omitted, the
signed-in user's `preferred_language` is used, falling back to the first
active language. An unknown code returns `404`.

The detail response embeds the category's lessons.

### `GET /api/lessons/` · `GET /api/lessons/{id}/`

Paginated (`results`, `count`, `next`, `previous`). Accepts `?language=` or
`?category={id}`. The detail response embeds the full word list.

### `GET /api/words/{id}/`

A single vocabulary item. `text` is the reference text used for scripted
pronunciation assessment.

### `GET /api/words/{id}/quiz-round/`

Builds one multiple-choice round for the **Listen** and **Quiz** modes.

```json
{
  "word": { "id": 7, "text": "kucing", "image_url": "" },
  "options": [ { "id": 9, "text": "anjing" }, { "id": 7, "text": "kucing" } ],
  "correct_option_id": 7
}
```

Options are shuffled server-side, so their order carries no hint. Wrong
answers come from hand-picked distractors where set, topped up from the same
category otherwise, so a round can always be built and every option is real
vocabulary in the right language.

---

## Profiles

A **User** is the login. A **Profile** is the learner. One family account can
hold several children, each with their own level, points and streak — this is
what the "Pilih Profil" screen selects between.

### `GET /api/profiles/`

Not paginated. Returns only profiles owned by the signed-in user. The queryset
is filtered by owner, so another account's children are unreachable — a
request for someone else's profile id returns `404`, not `403`.

```json
[
  {
    "id": 1, "name": "Ali", "avatar": "BOY_1",
    "language_code": "ms", "language_name": "Bahasa Melayu",
    "level": 3, "points": 230,
    "points_into_level": 30, "points_to_next_level": 70,
    "streak_days": 7, "last_practised_on": "2026-08-18"
  }
]
```

### `POST /api/profiles/` · `PATCH /api/profiles/{id}/` · `DELETE /api/profiles/{id}/`

Accepts `name`, `avatar`, and `practice_language` (a language **code**, not an
id). `owner` is never read from the request — it always comes from the token.

`points`, `level` and `streak_days` are **read-only over the API**. They are
maintained by the practice flow; letting a client post them would make the
whole progress system trivially forgeable.

Level is derived (`points // 100 + 1`) rather than stored twice, so it can
never disagree with the point total.

---

## Not yet implemented

Practice evaluation, attempts, progress, dashboard, achievements and the
parent/teacher student endpoints arrive in later phases and are documented
here once they exist.
