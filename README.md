# SkillBridge AI

Evidence-based career skill-gap analyzer: Flutter mobile + FastAPI backend + PostgreSQL + Python AI
pipeline. Upload a text-based PDF resume, add a target role, and get an explainable gap report plus a
personalized learning roadmap with curated resources.

## MVP scope

- Auth (JWT access + opaque, rotated refresh tokens)
- Resume PDF upload + text-based skill extraction (verbatim evidence only)
- Job description input + required/preferred skill extraction
- Deterministic skill-gap matching + coverage = matched_required / total_required × 100
- Gap report: matched (with evidence), missing, related (never counted as matched)
- Personalized roadmap: one task per missing/related skill, priority-ordered, curated resource URLs
- Progress tracking (task completion) + dashboard
- Excluded: multiple resumes, scraping, mock interviews, GitHub verification, push notifications

## Stack

- Mobile: Flutter 3.47.5, Riverpod, Dio, GoRouter, secure storage, file_picker, url_launcher
- Backend: FastAPI, SQLAlchemy 2 async, Alembic, Pydantic v2, bcrypt + PyJWT
- DB: PostgreSQL 16 (pgvector optional)
- AI: deterministic taxonomy matcher (default, offline); embeddings/LLM optional & disabled by default

## Repository layout

```
backend/          FastAPI app, AI pipeline, migrations, 41 tests
mobile/           Flutter app (Android-first)
datasets/         taxonomy (curated skills) + evaluation benchmark
docs/             architecture.md
.github/workflows/ CI for backend + mobile
docker-compose.yml
.env / .env.example
README.md
```

## Quick start

### Backend

```bash
cd backend
.venv/bin/python -m pytest -q          # 41 passed
.venv/bin/ruff check app tests
.venv/bin/python scripts/run_matcher_benchmark.py   # documented AI benchmark
.venv/bin/uvicorn app.main:app --host 127.0.0.1 --port 8000
```

Health: `http://127.0.0.1:8000/health` → `{"status":"ok"}`
API docs: `http://127.0.0.1:8000/docs`

Dev DB: `localhost:5432` (container `skillbridge_postgres`); compose maps host `5433`.

### Mobile

```bash
cd mobile
flutter analyze
flutter test
flutter build apk --debug
```

Default API base: `http://10.0.2.2:8000/api/v1` (Android emulator). Cleartext is allowed for
`10.0.2.2`/`localhost`/`127.0.0.1` in debug builds via `android/app/src/main/res/xml/network_security_config.xml`.

## Key design decisions

- **Deterministic first**: aliases resolve through a curated taxonomy before any AI; `mock` extractor is default.
- **Evidence must be verbatim**: each match quotes an exact span from the resume; paraphrases are discarded.
- **Related is not matched**: adjacent experience is surfaced separately and never counted toward coverage.
- **Absence is not proof**: a gap means supporting text was not found, not that you lack the skill.
- Refresh tokens are SHA-256-hashed, stored in `refresh_sessions`, rotated on refresh; access JWT `sid` validated against a non-revoked session.
- Roadmap resource URLs are curated (`app/services/resources.py`); the LLM never invents links.

## Benchmark (documented AI evaluation)

`datasets/evaluation/matcher_labels.yaml` holds 26 labeled `(required skill, resume skill, expected status)`
pairs. The deterministic matcher classifies all correctly: precision = recall = f1 = 1.0.
See `datasets/evaluation/README.md` and `backend/scripts/run_matcher_benchmark.py`.

## CI

- `.github/workflows/backend-ci.yml` — Python setup, ruff, pytest.
- `.github/workflows/mobile-ci.yml` — Flutter setup, analyze, test.

## Deliverables

- APK: `mobile/build/app/outputs/flutter-apk/app-debug.apk`
- Backend health endpoint: `GET /health` (deployed with the API)
- Architecture diagram + schema: `docs/architecture.md`
- Tests: backend `tests/` (41 passed), mobile `test/`
- Documented AI benchmark: `datasets/evaluation/`
