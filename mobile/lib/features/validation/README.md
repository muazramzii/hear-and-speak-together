# Validation (Phase 4.5)

Real-user usability evaluation for the Bachelor's FYP thesis (Chapter 4) -
SUS scoring, a post-study questionnaire, an observer sheet, timing/
statistical analysis, CSV import/export, charts, and a PDF report.

This module is deliberately isolated from the production app:

- It does not read from or write to any production model, repository, or
  backend table (`Profile`, `ProgressReport`, etc.). Evaluation data lives
  only in the CSV files this module reads and writes.
- It does not modify Flutter UI, the Django backend, Whisper, the
  Pronunciation Engine, the Parent Dashboard, the database schema, or any
  API - per the Phase 4.5 brief, all of those are frozen.
- Participant count, role, and age group are never hardcoded - the study
  design suggests groups (children, parents, teachers/therapists) but the
  code must work for any roster size or makeup.

See `backend/docs/validation/` for the CSV templates and the Chapter 4
Markdown package this module's output feeds into.
