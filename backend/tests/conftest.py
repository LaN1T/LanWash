import os
import sys
from datetime import datetime
from urllib.parse import urlparse, urlunparse

import pytest
import pytest_asyncio

# Load the project-root .env (PostgreSQL credentials) before importing app settings.
# This overrides a possible backend/.env that still points to SQLite.
from dotenv import load_dotenv

ROOT_DIR = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
load_dotenv(os.path.join(ROOT_DIR, ".env"), override=True)


def _resolve_local_database_url(url: str) -> str:
    """Rewrite a Docker Compose service hostname (db) to localhost."""
    parsed = urlparse(url)
    if parsed.hostname != "db":
        return url
    port = parsed.port or 5432
    netloc = parsed.netloc
    if "@" in netloc:
        userinfo, hostport = netloc.rsplit("@", 1)
        hostport = hostport.replace(f"db:{port}", f"localhost:{port}", 1)
        netloc = f"{userinfo}@{hostport}"
    else:
        netloc = netloc.replace(f"db:{port}", f"localhost:{port}", 1)
    return urlunparse(parsed._replace(netloc=netloc))


raw_db_url = os.environ.get("DATABASE_URL")
if raw_db_url:
    os.environ["DATABASE_URL"] = _resolve_local_database_url(raw_db_url)

os.environ["JWT_SECRET_KEY"] = (
    "test-secret-key-with-at-least-43-characters-for-url-safe-token"
)
os.environ["INITIAL_ADMIN_PASSWORD"] = "TestPass123!"
os.environ.setdefault("DEV_WASHER_PASSWORD", "DevWasher123!")
os.environ.setdefault(
    "FCM_ENCRYPTION_KEY", "zM1-xb7fhoXQAbRzvCGSyMeZb37IdYLS2GN_zBUrFYw="
)

# Добавляем backend в PYTHONPATH
sys.path.insert(0, os.path.join(os.path.dirname(__file__), ".."))

from sqlalchemy.ext.asyncio import AsyncSession, async_sessionmaker, create_async_engine
from sqlalchemy.orm import sessionmaker

from core.config import get_settings

settings = get_settings()


def _get_test_database_url() -> str:
    parsed = urlparse(settings.database_url)
    if parsed.scheme.startswith("sqlite"):
        # Use a temporary file database with NullPool. The file keeps the seeded
        # schema visible across fresh per-test connections, while NullPool avoids
        # stale connections left behind by transaction errors.
        return "sqlite+aiosqlite:///./lanwash_test.db"
    return urlunparse(parsed._replace(path="/lanwash_test"))


# Create the test engine at module import time and patch the database module
# *before* the FastAPI app is imported. This makes app startup (lifespan/init_db)
# and all database sessions point to the disposable test database.
from sqlalchemy.pool import NullPool

_db_url = _get_test_database_url()
_poolclass = NullPool

_create_engine_kwargs = {
    "echo": False,
    "future": True,
    "poolclass": _poolclass,
}

_test_engine = create_async_engine(_db_url, **_create_engine_kwargs)

import db.engine as _db_engine_module
import db.init as _db_init_module
import db.session as _db_session_module
from db.init import init_db as _orig_init_db

_db_engine_module.engine = _test_engine
_db_session_module.async_engine = _test_engine
_db_session_module.AsyncSessionLocal = sessionmaker(
    _test_engine, class_=AsyncSession, expire_on_commit=False
)


async def _noop_init_db():
    """No-op replacement for init_db during app lifespan in tests."""
    return


_db_init_module.init_db = _noop_init_db

# Imports that must happen after env vars / patches are in place
# Patch @atomic so tests can share a rolled-back connection-level transaction
# across requests.  When a transaction is already active the decorator creates
# a savepoint; otherwise it behaves like the original decorator.
import core.transaction as _transaction_module
from core.limiter import limiter
from models import Base, User

_orig_atomic = _transaction_module.atomic


def _test_atomic(func):
    from functools import wraps

    @wraps(func)
    async def wrapper(self, *args, **kwargs):
        if self._db.in_transaction():
            async with self._db.begin_nested():
                return await func(self, *args, **kwargs)
        async with self._db.begin():
            return await func(self, *args, **kwargs)

    return wrapper


_transaction_module.atomic = _test_atomic

# Disable Prometheus instrumentation during tests: some versions of
# prometheus-fastapi-instrumentator trip over Starlette's IncludedRouter
# (AttributeError: '_IncludedRouter' object has no attribute 'path').
from prometheus_fastapi_instrumentator.middleware import (
    PrometheusInstrumentatorMiddleware,
)

from main import app


def _safe_get_handler(self, request):
    return "unknown", False


PrometheusInstrumentatorMiddleware._get_handler = _safe_get_handler

import asyncpg
from httpx import ASGITransport, AsyncClient


@pytest_asyncio.fixture(scope="session", autouse=True)
async def _create_test_database():
    """Ensure the disposable test database exists (PostgreSQL only)."""
    test_url = _get_test_database_url()
    if urlparse(test_url).scheme.startswith("sqlite"):
        parsed = urlparse(test_url)
        # SQLite path is the part after the third slash.
        db_path = parsed.path
        if db_path and os.path.exists(db_path):
            os.remove(db_path)
        return
    # Connect to the maintenance 'postgres' DB using the same encoded credentials.
    admin_dsn = test_url.replace("postgresql+asyncpg://", "postgresql://").replace(
        "/lanwash_test", "/postgres"
    )
    conn = await asyncpg.connect(admin_dsn)
    try:
        exists = await conn.fetchval(
            "SELECT 1 FROM pg_database WHERE datname = 'lanwash_test'"
        )
        if not exists:
            await conn.execute("CREATE DATABASE lanwash_test")
    finally:
        await conn.close()


@pytest_asyncio.fixture(scope="session", autouse=True)
async def _seed_test_db(_create_test_database):
    """Recreate tables and seed reference data once per test session."""
    async with _test_engine.begin() as conn:
        await conn.run_sync(Base.metadata.drop_all, checkfirst=True)
        await conn.run_sync(Base.metadata.create_all)
    await _orig_init_db()


@pytest_asyncio.fixture(scope="session")
async def test_engine():
    """Session-scoped async engine for the test database."""
    yield _test_engine


@pytest_asyncio.fixture
async def db_session(test_engine) -> AsyncSession:
    """Create a test session wrapped in a transaction that is rolled back."""
    async with test_engine.connect() as conn:
        trans = await conn.begin()
        session_maker = async_sessionmaker(
            bind=conn,
            expire_on_commit=False,
            join_transaction_mode="create_savepoint",
        )
        session = session_maker()

        # Prevent test code and endpoint code from committing the connection-level
        # transaction. This keeps each test isolated even when fixtures/tests call
        # ``await db_session.commit()``. Only flush to the savepoint; the outer
        # transaction is rolled back after the test.
        async def _test_commit():
            await session.flush()

        session.commit = _test_commit

        try:
            yield session
        finally:
            await session.close()
            await trans.rollback()


@pytest_asyncio.fixture
async def db(db_session):
    """Alias for db_session to keep existing tests compatible."""
    return db_session


@pytest_asyncio.fixture
async def async_client(db_session):
    """HTTP-клиент для тестирования FastAPI."""
    from db.session import get_db

    async def _override_get_db():
        yield db_session

    app.dependency_overrides[get_db] = _override_get_db
    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as client:
        yield client
    app.dependency_overrides.pop(get_db, None)


@pytest_asyncio.fixture
async def admin_token(async_client):
    """Токен администратора (из seed_data)."""
    response = await async_client.post(
        "/api/auth/login",
        json={
            "username": "admin",
            "password": os.getenv("INITIAL_ADMIN_PASSWORD"),
        },
    )
    assert response.status_code == 200
    return response.json()["access_token"]


@pytest_asyncio.fixture
async def washer_token(async_client, db_session):
    """Токен мойщика (создаётся напрямую в БД с role='washer')."""
    from services.auth_service import get_password_hash

    user = User(
        username="washer_test",
        passwordHash=get_password_hash("TestPass123!"),
        role="washer",
        displayName="Washer Test",
        createdAt=datetime.now(),
    )
    db_session.add(user)
    await db_session.commit()

    response = await async_client.post(
        "/api/auth/login",
        json={
            "username": "washer_test",
            "password": "TestPass123!",
        },
    )
    assert response.status_code == 200
    return response.json()["access_token"]


@pytest_asyncio.fixture
async def client_token(async_client):
    """Токен обычного клиента (создаётся на лету)."""
    await async_client.post(
        "/api/auth/register",
        json={
            "username": "client_test",
            "password": "TestPass123!",
            "displayName": "Client Test",
        },
    )
    response = await async_client.post(
        "/api/auth/login",
        json={
            "username": "client_test",
            "password": "TestPass123!",
        },
    )
    assert response.status_code == 200
    return response.json()["access_token"]


@pytest_asyncio.fixture
async def other_washer_token(async_client, db_session):
    """Токен другого мойщика (не назначенного на записи)."""
    from services.auth_service import get_password_hash

    user = User(
        username="other_washer",
        passwordHash=get_password_hash("TestPass123!"),
        role="washer",
        displayName="Other Washer",
        createdAt=datetime.now(),
    )
    db_session.add(user)
    await db_session.commit()

    response = await async_client.post(
        "/api/auth/login",
        json={
            "username": "other_washer",
            "password": "TestPass123!",
        },
    )
    assert response.status_code == 200
    return response.json()["access_token"]


@pytest.fixture(autouse=True)
def _reset_rate_limit_state():
    """Clear in-memory rate-limit and brute-force state between tests."""
    from core.brute_force import _IN_MEMORY

    _IN_MEMORY.clear()
    if hasattr(limiter, "_storage") and hasattr(limiter._storage, "reset"):
        limiter._storage.reset()
    yield
