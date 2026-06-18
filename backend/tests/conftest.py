import os
import sys
from datetime import datetime
from urllib.parse import urlparse, urlunparse

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

os.environ["JWT_SECRET_KEY"] = "test_secret_key_minimum_32_chars_long"
os.environ["INITIAL_ADMIN_PASSWORD"] = "TestPass123!"
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
        # Use SQLite as-is (in-memory or file). No per-test DB rewrite needed.
        return settings.database_url
    return urlunparse(parsed._replace(path="/lanwash_test"))


# Create the test engine at module import time and patch the database module
# *before* the FastAPI app is imported. This makes app startup (lifespan/init_db)
# and all database sessions point to the disposable test database.
from sqlalchemy.pool import AsyncAdaptedQueuePool, NullPool

# In-memory SQLite loses its data when the connection is closed. NullPool
# opens a brand-new connection for every request, so the schema created by
# create_all and the seed data inserted afterwards end up in different empty
# databases. Pin the pool size to a single connection for in-memory SQLite;
# for PostgreSQL keep NullPool to avoid stale connections.
_db_url = _get_test_database_url()
_is_sqlite_memory = _db_url.startswith("sqlite+aiosqlite:///:memory:")
_poolclass = AsyncAdaptedQueuePool if _is_sqlite_memory else NullPool

_create_engine_kwargs = {
    "echo": False,
    "future": True,
    "poolclass": _poolclass,
}
if _is_sqlite_memory:
    _create_engine_kwargs["pool_size"] = 1
    _create_engine_kwargs["max_overflow"] = 0
    _create_engine_kwargs["connect_args"] = {"check_same_thread": False}

_test_engine = create_async_engine(_db_url, **_create_engine_kwargs)

import db.engine as _db_engine_module
import db.init as _db_init_module
import db.session as _db_session_module
from db.init import init_db as _orig_init_db

_db_engine_module.engine = _test_engine
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

from main import app

limiter.enabled = False

# Disable Prometheus instrumentation during tests: some versions of
# prometheus-fastapi-instrumentator trip over Starlette's IncludedRouter
# (AttributeError: '_IncludedRouter' object has no attribute 'path').
from prometheus_fastapi_instrumentator.middleware import (
    PrometheusInstrumentatorMiddleware,
)


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
        createdAt=datetime.now().isoformat(),
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
        createdAt=datetime.now().isoformat(),
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
