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

Returns each active language.

```json
[
  { "id": 1, "code": "en", "name": "English", "locale": "en-US", "tts_voice": "en-US-AnaNeural" },
  { "id": 2, "code": "ms", "name": "Bahasa Melayu", "locale": "ms-MY", "tts_voice": "ms-MY-YasminNeural" }
]
```

There is no per-language capability block. The pronunciation engine measures
the same three metrics (similarity, confidence, completeness) for every
supported language, so there is nothing locale-dependent for the client to
discover — see [pronunciation-engine.md](pronunciation-engine.md).

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

## Practice

### `POST /api/practice/evaluate/`

Authenticated. **Multipart form data**, not JSON.

| Field | Type | Notes |
| --- | --- | --- |
| `word_id` | int | Must be an active word |
| `profile_id` | int | Must belong to the signed-in account |
| `audio` | file | Non-empty, max 5 MB. 16 kHz mono WAV preferred |

Response `200`:

```json
{
  "attempt_id": 12,
  "reference": "bola",
  "recognized": "bola",
  "language": "ms",
  "locale": "ms-MY",
  "heard_speech": true,
  "score": 88,
  "similarity": 90.0,
  "confidence": 85.0,
  "completeness": 100.0,
  "errors": [],
  "feedback": "Syabas! Sebutan anda hampir tepat.",
  "points_awarded": 7,
  "profile": { "id": 1, "points": 237, "level": 3, "streak_days": 7 },
  "new_achievements": [],
  "can_retry": true
}
```

`score` is the single weighted headline number
(`0.5 × similarity + 0.3 × confidence + 0.2 × completeness`, clamped 0-100).
`similarity`, `confidence` and `completeness` are the same three metrics for
every language — there is no `null`-for-locale case in this architecture, and
no prosody metric anywhere, because nothing in the pipeline has an acoustic
signal to derive one from. `errors` is a structured list of
`{"type", "expected", "detected"}` objects describing what a phoneme-level
alignment actually found (e.g. `missing_ending`, `wrong_consonant`) — see
[pronunciation-engine.md](pronunciation-engine.md).

`heard_speech: false` means the recording contained nothing recognisable.
That is a normal outcome, not an error: the attempt is still stored (useful
information for a parent), `score` is `null`, and 0 points are awarded.

Returns `503` with `{"detail": "...", "can_retry": true}` when assessment is
unavailable. The `detail` is always safe to show a child — the technical
reason is logged server-side only.

`400` for an empty/oversized recording, an unknown word, or a profile the
caller does not own. Validation happens **before** the recording is handed to
Whisper.

### `GET /api/attempts/` · `GET /api/attempts/{id}/`

Paginated history, scoped to the signed-in account's own children. Filter with
`?profile={id}` or `?word={id}`. Another account's attempt returns `404`.

---

## Feedback: two layers

**Layer 1 — deterministic.** Always present, no model call, no cost. A score
band maps to one sentence in the practice language (`Syabas!` / `Great job!`).

**Layer 2 — optional LLM.** Off by default (`ENABLE_AI_FEEDBACK=False`). When
enabled, `AI_PROVIDER` selects `gemini`, `openai` or `mock`, and the model
rewrites layer 1 into warmer wording.

The LLM **never produces or adjusts a score**. Pronunciation scoring is a
deterministic calculation over similarity, confidence and completeness,
performed entirely in Python; an LLM only sees text and could not measure it.
Every failure path — timeout, quota, bad key, unexpected payload, unusable
output, even an unhandled exception — falls back to layer 1. No attempt can
fail because a provider is down, and no LLM call is made when nothing was
heard.

The prompt carries only the word, language, similarity/confidence scores and
the top error type. No name, no email, no account id, no audio.

---

## School Analytics

Phase 6 (multi-tenant schools), Task 7. SCHOOL_ADMIN-only, and the school is
always the caller's own (`request.user.school`) — none of these URLs take an
id, so there is nothing to guess or leak another school's data through.
Every figure is computed by `apps.progress.services.analytics`'s existing,
per-learner-tested aggregation logic run over a group of profiles instead of
one — a school's average score and a single learner's average score are the
same calculation, not two implementations that could quietly disagree.

A student in a deactivated classroom, and everything they attempted, is
excluded from all four endpoints below — a soft-deleted classroom's history
stays in the database (classroom deactivation is a soft delete, never a row
removal) but stops inflating the school's *live* numbers.

An admin with no school yet (has not completed the Task 4 "create a school"
step) gets a valid, empty response from every endpoint below — zeros and
empty lists — never an error.

### `GET /api/schools/analytics/overview/`

```json
{
  "total_students": 42,
  "total_teachers": 6,
  "total_classrooms": 4,
  "active_students_today": 11,
  "weekly_average_score": 78,
  "monthly_average_score": 74
}
```

`weekly_average_score`/`monthly_average_score` are `null` when there is no
scored attempt in that window at all, not `0` — a school that hasn't
practised yet has no average, rather than a misleadingly bad one.

### `GET /api/schools/analytics/classrooms/`

Ordered by classroom name. `completion_rate` is the average of
`LessonProgress.completion_percentage` across the classroom's students — the
same derived figure a parent's per-lesson progress list already shows, not a
new definition of "complete."

```json
[
  {
    "classroom_id": 3, "classroom_name": "Classroom Alpha",
    "teacher_count": 1, "student_count": 12,
    "average_pronunciation_score": 81, "completion_rate": 64.5
  }
]
```

### `GET /api/schools/analytics/phonemes/`

Top 10 weakest sounds school-wide, worst `error_rate` first. Reuses the exact
substitution-rate definition and `MIN_PHONEME_OCCURRENCES` threshold the
per-learner "weak phonemes" feature already uses — a sound only appears once
it has a trustworthy sample size across the school, not after one unlucky
recording.

Optional `?classroom_id=` (Task 9's classroom report) narrows the same
calculation to one classroom's students. A `classroom_id` that doesn't exist,
or belongs to another school, returns an empty list rather than an error or
another tenant's data.

```json
[
  { "phoneme": "th", "error_rate": 62, "total_occurrences": 18, "affected_students": 9 }
]
```

### `GET /api/schools/analytics/trends/`

The last 7 days by default, oldest first. Every day appears even with zero
attempts — unlike a single learner's own trend chart (where a quiet day is
omitted as uninformative), a school-wide chart is read by an admin looking
for drop-offs, so a quiet day is exactly what this endpoint must surface.

Optional `?days=` (1–90, Task 9's Last 30 days / This month report filters)
widens the window — the underlying calculation already supports any day
count, so this is a plain pass-through, not a new aggregation. Optional
`?classroom_id=` (Task 9's classroom report) scopes the same window to one
classroom's students; combine both to get a longer, classroom-scoped trend.

```json
[
  { "date": "2026-08-20", "attempts": 0, "average_score": 0 },
  { "date": "2026-08-21", "attempts": 14, "average_score": 79 }
]
```

---

## Not yet implemented

School, Classroom and Teacher Invitation management (Phase 6, Tasks 4–6) and
the parent/teacher student endpoints arrive from earlier Phase 6 work and are
documented here once this reference catches up to them.
