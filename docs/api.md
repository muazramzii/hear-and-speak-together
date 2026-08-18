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

## Not yet implemented

Languages, categories, lessons, words, practice evaluation, attempts,
progress, dashboard, achievements and the parent/teacher student endpoints are
planned for later phases and are documented here once they exist.
