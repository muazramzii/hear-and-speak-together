# Database

PostgreSQL. Every table below is created by Django migrations; there is no
hand-written SQL in the project.

---

## Why relational

The data is highly relational — attempts belong to words, words to lessons,
lessons to categories, categories to a language — and almost every screen is an
aggregate over that structure: average score per category, distinct words above
a threshold, completion per lesson. That is what SQL is for.

---

## Schema overview

```
User (the login)
 └─ Profile (the learner)          one account, several children
     ├─ PracticeAttempt            one spoken attempt, scored by Azure
     ├─ QuizSession                one finished Listen/Quiz run
     ├─ LessonProgress             standing in one lesson
     └─ ProfileAchievement         badges earned

Language
 └─ Category
     └─ Lesson
         └─ Word ──┐
                   └─ distractors (self-referential M2M)

StudentLink   supervisor (User) ──> Profile
Achievement   the badge catalogue
```

---

## User and Profile — the important distinction

A **User** is the *login*. A **Profile** is the *learner*.

One family account holds several children, each with their own level, points
and streak. Everything that records learning attaches to a `Profile`, never to
a `User`, so a sibling's practice can never land on the wrong child's record.

`User` is a custom model keyed by **email** — no separate username, because
asking a child to remember both is friction with no benefit.

| Field | Notes |
| --- | --- |
| `email` | Unique, lowercased on save |
| `role` | `STUDENT` / `PARENT` / `TEACHER` |
| `preferred_language` | Default content language for the account |

`Profile` adds `share_code`: eight characters from a 31-symbol alphabet that
excludes `0/O` and `1/I/L`, because the code gets read aloud. It is how a
teacher links to a learner.

**Derived, not stored:** `level` comes from `points // 100 + 1`, and
`completion_percentage` from the word counts. Storing them again would create a
second source of truth that can disagree with the first.

---

## Language — capability flags

`Language` carries what Azure can actually measure for its locale:
`supports_prosody`, `supports_phoneme_names`, `supports_syllable_scores`, plus
`capabilities_verified_on`.

These are **verified facts, not guesses** — Azure supports prosody assessment
for `en-US` only. See [azure-speech.md](azure-speech.md). Enabling a flag Azure
does not support would make the app display a score that was never measured.

---

## Content

Content is authored **per language**, not translated at runtime. The Malay
"Haiwan" lesson holds real Malay words — `kucing`, `gajah`, `kereta api` — not
machine translations of the English list. A translated word is frequently the
wrong word to teach, and it gives the speech assessor a reference text nobody
actually says. A test asserts English words never appear in the Malay set.

`Category.slug` is the stable cross-language key, so English "animals" and
Malay "animals" are recognisably the same theme without sharing a row.

`Word.distractors` is a self-referential many-to-many holding the wrong answers
offered in Listen and Quiz. Modelling them as relations to *real words* rather
than free text means every option is genuine vocabulary in the correct language
and comes with its own image.

`Word.emoji` is a **playability requirement, not decoration.** A Listen round
hides the word and shows four pictures. With no illustration and no emoji every
tile falls back to the same placeholder icon, and the question can only be
guessed. The seed data gives all 62 words an emoji, keyed by category and
position so `cat` and `kucing` share 🐱. A test asserts no word is left without
a visual, and another asserts the four options in a round are distinct.

The client's fallback order is illustration → emoji → generic icon, so real
artwork simply takes precedence once it is supplied.

---

## PracticeAttempt vs QuizSession

Deliberately separate tables.

A `PracticeAttempt` is a **spoken** attempt with Azure scores. A `QuizSession`
is a tally of taps on pictures. Folding the second into the first would mean a
pronunciation column that is meaningless for half the rows, and it would
corrupt the score averages the analytics rest on.

Every score column on `PracticeAttempt` is **nullable on purpose**. A `null`
means *not measured for this locale* — for example prosody on `ms-MY`. It must
never be read as zero.

Attempts are an audit trail of what a child said and what Azure returned, so
the Django admin marks them read-only and disallows adding them by hand.

---

## LessonProgress

Maintained as attempts arrive, because the dashboard reads it far more often
than practice writes it. But it is **recomputed** from the attempts each time,
never incremented: an increment that runs twice, or not at all, silently
corrupts the record, whereas a recount is always right.

---

## StudentLink

Lets a teacher follow a learner they do not own. Parents already own their
children's profiles and need no link.

Access is enforced by **filtering the queryset**, not by a per-object check, so
another family's child returns `404` rather than `403` — a `403` would confirm
the profile exists.

---

## Migrations

```bash
python manage.py makemigrations
```

```bash
python manage.py migrate
```

Two migrations are hand-written and worth knowing about:

- `profiles/0002_profile_share_code` — adding a **unique** column to a
  populated table needs three steps: add nullable, backfill unique values,
  then apply the constraint. Doing it in one step would write the same default
  into every row and violate the constraint.
- `practice/0002_quizsession` — written by hand for the same reason the
  autodetector could not be used non-interactively.

Check for drift with:

```bash
python manage.py makemigrations --check --dry-run
```

---

## Seeding

```bash
python manage.py seed_data
```

```bash
python manage.py seed_achievements
```

Both are idempotent — existing rows are updated in place, so re-seeding never
destroys a learner's progress. Together they create 2 languages, 12 categories,
12 lessons, 62 words with distractor links, and 6 achievements.

`seed_data --reset` deletes content first. It also deletes the attempts that
reference those words, so it is not for a database with real learner data.
