# SkillBridge AI — Architecture

Evidence-based career skill-gap analyzer. Flutter mobile (Android-first) + FastAPI
backend + PostgreSQL + Python AI pipeline.

## Stack

| Layer | Technology |
|---|---|
| Mobile | Flutter 3.47.5 / Dart 3.13.4, Riverpod, Dio, GoRouter, flutter_secure_storage, file_picker, url_launcher, intl |
| Backend | FastAPI, SQLAlchemy 2 (async), Alembic, Pydantic v2, bcrypt + PyJWT |
| Database | PostgreSQL 16 (+pgvector optional), host port 5432 (dev) / 5433 (compose) |
| AI pipeline | Deterministic taxonomy matcher (default), embeddings/LLM optional & disabled by default |
| Storage | Local filesystem (default); S3-compatible abstraction optional |
| CI/CD | GitHub Actions (backend + mobile) |
| Deploy | Docker / Docker Compose |

## Directory layout

```
skillbridge/
├── backend/                 # FastAPI application
│   ├── app/
│   │   ├── ai/              # AI pipeline: taxonomy, extractor, normalizer, matcher, evaluator
│   │   ├── api/v1/          # REST routes (auth, resumes, jobs, analyses, roadmaps, dashboard, users)
│   │   ├── core/            # config, security, storage
│   │   ├── db/              # async session, base, Alembic metadata
│   │   ├── models/          # 11 SQLAlchemy models
│   │   ├── schemas/         # Pydantic v2 request/response schemas
│   │   └── services/        # business logic (resume, job, analysis, roadmap, resources, skill)
│   ├── scripts/             # benchmark runner
│   ├── tests/               # 41 unit + integration tests
│   ├── alembic/             # database migrations
│   ├── .venv/               # venv (gitignored)
│   ├── docker-compose.yml   # db (5433), api, worker
│   └── pyproject.toml
├── mobile/                  # Flutter application
│   ├── lib/
│   │   ├── app/             # router, main
│   │   ├── core/            # config, api_client, errors, theme, formatters
│   │   ├── shared/          # models, widgets, utils
│   │   └── features/        # auth, analysis, dashboard, jobs, profile, resume, roadmap, shell
│   ├── test/                # widget/model smoke tests
│   └── android/             # manifest + network security config
├── datasets/
│   ├── taxonomy/skills.json # curated ~90-skill taxonomy + aliases
│   └── evaluation/          # labeled matcher benchmark + README
├── docs/
│   └── architecture.md      # this file
├── .github/workflows/       # backend-ci.yml, mobile-ci.yml
├── docker-compose.yml       # root compose (db maps 5433)
├── .env / .env.example
└── README.md                # this project's root readme
```

## Data model (11 tables)

```text
users                      refresh_sessions
│ id (PK)                  │ id (PK), user_id FK, token_hash, expires_at, revoked_at
│ email (unique)           │ created_at
│ password_hash
│
├─ resumes                 ├─ jobs
│ id (PK), user_id FK      │ id (PK), user_id FK, title, company, description
│ file_key                 │ status, error_message
│ original_filename        │ created_at
│ status, error_message    │
│ extracted_text           │
│
├─ resume_skills           ├─ job_skills
│ id (PK), resume_id FK    │ id (PK), job_id FK, skill_id FK
│ skill_id FK              │ required, importance, evidence_text
│ evidence_text, confidence│
│
├─ analyses                ├─ roadmaps
│ id (PK), user_id FK      │ id (PK), user_id FK, analysis_id FK
│ resume_id FK, job_id FK  │ created_at
│ status, coverage, model_version│
│ error_message, created_at│
│
├─ analysis_gaps           └─ roadmap_tasks
│ id (PK), analysis_id FK  │ id (PK), roadmap_id FK, skill_id FK
│ skill_id FK              │ title, description, resource_url, status, sort_order
│ match_status, priority   │
│ reason, evidence_text    │
│
skills (taxonomy)
│ id (PK), canonical_name, taxonomy_id, aliases (JSONB), category, description
```

Key design points:
- `refresh_sessions.token_hash` stores SHA-256 of the opaque refresh token; sessions are rotated on refresh.
- Access JWT carries `sid` (session id) validated against a non-revoked `refresh_sessions` row.
- `analysis_gaps.match_status ∈ {matched, related, not_evidenced}`; only `matched` required skills count toward coverage.
- `roadmap_tasks` only generated for `not_evidenced` and `related` gaps (missing/related skills), one task each.

## AI pipeline

```
resume text ──► extract_skills (mock default / LLM) ──► normalized skills (verbatim evidence)
                                                     │
job description ──► extract_skills ──────────────────┘
                                                     │
                                              analyze_gaps (deterministic)
                                                ├─ matched   (direct taxonomy id match)
                                                ├─ related   (RELATED_GUPS adjacency, symmetrized)
                                                └─ not_evidenced
                                                     │
                                              coverage = matched_required / total_required × 100
                                                     │
                                              persist AnalysisGap rows
                                                     │
                                              roadmap: one task per missing/related skill
                                                (curated resource URLs, never LLM-invented)
```

- `mock` extractor is default so the app and tests work fully offline.
- Embeddings disabled by default (`EMBEDDING_ENABLED=false`), `sentence-transformers` lazily imported.
- Evidence spans must be verbatim (whitespace-normalized) substrings of source text.
- `related` is never upgraded to `matched` without direct resume evidence.

## API surface (`/api/v1`)

| Method | Endpoint | Description |
|---|---|---|
| POST | `/auth/register` | register user, returns `{user, tokens}` |
| POST | `/auth/login` | login, returns `{user, tokens}` |
| POST | `/auth/refresh` | rotate access + refresh tokens |
| POST | `/auth/logout` | revoke refresh session |
| GET | `/auth/me` | current user |
| GET/POST | `/resumes` | list / upload PDF resume |
| GET/DELETE | `/resumes/{id}` | resume detail / delete |
| GET/POST | `/jobs` | list / create job description |
| GET | `/jobs/{id}` | job detail |
| POST | `/analyses` | start analysis (202, async) |
| GET | `/analyses` | list analyses |
| GET | `/analyses/{id}` | analysis detail (coverage, matched/missing/related) |
| GET | `/analyses/{id}/roadmap` | 404 until generated |
| POST | `/analyses/{id}/roadmap` | generate roadmap (idempotent) |
| PATCH | `/roadmap-tasks/{id}` | update task status |
| GET | `/dashboard` | aggregate counts + latest coverage |
| GET | `/health` | health check |

All responses use the error envelope `{"error": {"code", "message", "details"}}`. Auth uses bearer access tokens; refresh tokens are opaque and rotated.

## Security

- Passwords hashed with bcrypt (passlib/python-jose dropped: Python 3.14 removed `crypt`).
- JWT access tokens with `sid` claim; refresh tokens opaque, SHA-256-hashed at rest, rotated on use.
- CORS restricted to configured origins.
- PDF validation rejects non-PDF and image-only (scanned) uploads; only text-based PDFs yield verbatim evidence.

## Mobile architecture

- `main.dart` bootstraps auth in `initState`; `routerProvider` builds a `GoRouter` with `StatefulShellRoute.indexedStack` (4 tabs: Home/Resumes/Roles/Profile) and auth redirect via a refresh listenable.
- `authControllerProvider` owns session state; `apiClient.onUnauthorized` triggers logout on 401.
- Detail screens use single-fetch providers + a 1.5s timer invalidation loop while processing (no provider-internal polling).
- `AnalysisDetailScreen`: coverage hero, matched/gaps/related sections with verbatim evidence quotes, roadmap CTA.
- `RoadmapScreen`: GET-by-analysis, 404 empty state with generate CTA, task toggles via PATCH, progress bar, `url_launcher` resources.
- `ProfileScreen`: email, matching disclaimer, version/API info, logout.

## Local development

```bash
# backend
cd backend
.venv/bin/python -m pytest -q        # 41 tests
.venv/bin/ruff check app tests
.venv/bin/python scripts/run_matcher_benchmark.py
.venv/bin/uvicorn app.main:app --host 127.0.0.1 --port 8000

# mobile
cd mobile
flutter analyze
flutter test
flutter build apk --debug
```

DB: container `skillbridge_postgres` on `localhost:5432`; compose maps host `5433` to avoid clashing. App DB `skillbridge_db`, test DB `skillbridge_test`.

## CI

- `.github/workflows/backend-ci.yml`: setup Python, install deps, ruff check, pytest.
- `.github/workflows/mobile-ci.yml`: setup Flutter, `flutter analyze`, `flutter test`.

## Benchmark (documented AI evaluation)

See `datasets/evaluation/`. 26 labeled matcher pairs; the deterministic matcher classifies all correctly
(precision = recall = f1 = 1.0). Embeddings/LLM are optional and not part of the default benchmark.

## Disclaimer

Coverage scores describe documented skill coverage in a resume. They are not a hiring probability or a
verified assessment of ability. A gap means supporting text was not found in this resume, not that you
lack the skill. Resource links are curated, not generated by AI.
