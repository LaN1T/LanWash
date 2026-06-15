# Backend cleanup: single PostgreSQL + layered architecture

## Goal

- Standardize on **one PostgreSQL database** for development, testing and production.
- Remove SQLite fallbacks, local `.db` files and duplicate migration systems.
- Restructure `backend/` into a clean layered layout: `models`, `schemas`, `repositories`, `services`, `routers`, `core`, `db`.
- Introduce a **repository layer** so services no longer contain raw SQL/SQLAlchemy queries.
- Perform a deep project cleanup: delete old specs/plans, run `flutter clean`, remove `.DS_Store` files, tighten `.gitignore`.

## Non-goals

- No new business features.
- No changes to the public API contract (URL paths, request/response shapes stay the same).
- No migration to a different framework (still FastAPI + SQLAlchemy async + Pydantic).

## Phase 0 — Deep project cleanup

1. **Delete old design/plan documents.**
   - Remove everything under `docs/superpowers/specs/` and `docs/superpowers/plans/` except this file.
2. **Remove generated Flutter artifacts.**
   - Run `flutter clean`.
   - Delete `build/`, `.dart_tool/`, `ios/Pods/` if still present after `flutter clean`.
3. **Remove macOS system files.**
   - Delete all `.DS_Store` files tracked or untracked.
4. **Tighten `.gitignore`.**
   - `*.db`, `lanwash*.db`, `.env.local`, `uploads/avatars/*`, `build/`, `.dart_tool/`, `.DS_Store`.
5. **Clean backend runtime artifacts.**
   - Delete `backend/lanwash.db`, `backend/lanwash_debug.db`, `backend/lanwash_debug2.db`, `backend/__pycache__`, `backend/.pytest_cache`, `backend/.ruff_cache`.

## Phase 1 — Single PostgreSQL + migrations + tests

### 1.1 Remove SQLite support

- `backend/database.py`
  - Remove `elif settings.database_url.startswith("sqlite")` branch and `check_same_thread=False`.
  - Engine kwargs for PostgreSQL stay.
- `backend/alembic/env.py`
  - Remove fallback to `sqlite+aiosqlite:///./lanwash.db`.
  - Always read `DATABASE_URL` from environment.
- `backend/tests/conftest.py`
  - Replace forced `sqlite+aiosqlite:///:memory:` with PostgreSQL `lanwash_test`.
- `backend/requirements.txt`
  - Remove `aiosqlite`.

### 1.2 Test database setup

In `conftest.py`:

1. Connect to the Postgres server from `DATABASE_URL`.
2. Compute `lanwash_test` URL by replacing the database name.
3. `CREATE DATABASE lanwash_test` if it does not exist.
4. Run `alembic upgrade head` once per test session.
5. Provide an `async_session` fixture that starts a transaction and rolls it back after each test.

Local test workflow:

```bash
docker compose up -d postgres redis
cd backend && source ../.venv/bin/activate && pytest -q
```

### 1.3 Dev seed data

- Washer accounts (`washer1`, `washer2`, `washer3`) must be created with password `Washer_1312` in non-production environments.
- Admin account continues to use `INITIAL_ADMIN_PASSWORD`.

### 1.4 Consolidate migrations

- Delete `backend/migrations/*.sql` and `backend/migrations/apply_migration.py`.
- Verify that `alembic upgrade head` produces a schema matching `db_models.py`.
- Keep `database.py` behaviour:
  - Production: run `alembic upgrade head` via subprocess.
  - Development/testing: `Base.metadata.create_all` + `seed_data` for speed.

## Phase 2 — Backend folder structure

Target layout:

```
backend/
├── app/
│   ├── __init__.py
│   ├── app.py              # FastAPI factory
│   ├── lifespan.py         # startup / shutdown
│   ├── middleware.py       # CORS, security headers, request id, metrics limit
│   └── routers.py          # include_routers
├── core/
│   ├── config.py
│   ├── limiter.py
│   ├── cache.py
│   ├── redis_client.py
│   ├── security.py
│   ├── security_headers.py
│   ├── websocket_manager.py   # moved from services/
│   └── ...
├── db/
│   ├── __init__.py
│   ├── engine.py           # create_async_engine
│   ├── session.py          # AsyncSessionLocal, get_db
│   ├── init.py             # init_db, run_migrations, seed_data
│   └── dependencies.py     # FastAPI Depends(get_db)
├── models/                 # SQLAlchemy ORM (was db_models.py)
│   ├── __init__.py
│   ├── base.py
│   ├── user.py
│   ├── appointment.py
│   ├── service.py
│   ├── wash_type.py
│   └── ...
├── schemas/                # Pydantic (was models.py)
│   ├── __init__.py
│   ├── auth.py
│   ├── appointments.py
│   ├── services.py
│   └── ...
├── repositories/           # new DAO layer
│   ├── __init__.py
│   ├── base.py
│   ├── user_repository.py
│   ├── appointment_repository.py
│   └── ...
├── services/               # business logic
├── routers/                # FastAPI endpoints
├── tasks/                  # arq background jobs
├── bot/                    # Telegram bot
├── scripts/                # seed, clean
├── alembic/
└── tests/
```

Rules for this phase:

- Only move/rename files; no logic changes.
- Keep imports working via `__init__.py` re-exports.
- Update `alembic/env.py` import path for `Base`.
- Update `main.py` callers to import from new locations.

## Phase 3 — Repository layer

### 3.1 Base repository

```python
class BaseRepository:
    def __init__(self, session: AsyncSession):
        self._session = session

    async def get(self, model_cls, id):
        return await self._session.get(model_cls, id)

    async def add(self, instance):
        self._session.add(instance)
        await self._session.flush()
        return instance

    async def delete(self, instance):
        await self._session.delete(instance)
```

### 3.2 Domain repositories

Create one repository per aggregate root:

- `UserRepository`
- `AppointmentRepository`
- `ServiceRepository`
- `WashTypeRepository`
- `ShiftRepository`
- `SupportChatRepository`
- ...

Each repository encapsulates SQLAlchemy queries for its domain.

### 3.3 Services use repositories

Refactor services to accept repositories in `__init__`:

```python
class AuthService:
    def __init__(self, db: AsyncSession, user_repo: UserRepository):
        self._db = db
        self._user_repo = user_repo
```

FastAPI dependencies:

```python
def get_user_repo(db: AsyncSession = Depends(get_db)) -> UserRepository:
    return UserRepository(db)
```

Start with small services, then tackle large ones (`appointments`, `shifts`).

## Verification

- `pytest -q` passes on `lanwash_test`.
- `ruff check backend --select E501,I001` passes.
- `docker compose up --build` starts backend successfully.
- `flutter clean` removes generated artifacts.
- `git status` shows no unexpected untracked build/cache files.

## Rollout order

1. Phase 0 cleanup.
2. Phase 1 DB consolidation + test setup.
3. Phase 2 folder restructure.
4. Phase 3 repository layer (incrementally, domain by domain).
5. Final verification and push.
