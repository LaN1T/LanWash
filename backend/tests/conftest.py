import os
import sys
import pytest
import pytest_asyncio

# Переопределяем DATABASE_URL ДО импорта приложения
os.environ["DATABASE_URL"] = "sqlite+aiosqlite:///:memory:"
os.environ["JWT_SECRET_KEY"] = "test_secret_key_minimum_32_chars_long"
os.environ["INITIAL_ADMIN_PASSWORD"] = "TestPass123!"

# Добавляем backend в PYTHONPATH
sys.path.insert(0, os.path.join(os.path.dirname(__file__), ".."))

from main import app, lifespan
from database import init_db, AsyncSessionLocal
from db_models import Base
from sqlalchemy.ext.asyncio import create_async_engine

# Отключаем rate limiting для тестов
from core.limiter import limiter
limiter.enabled = False


@pytest.fixture(scope="session")
def event_loop_policy():
    import asyncio
    return asyncio.DefaultEventLoopPolicy()


@pytest_asyncio.fixture
async def db_engine():
    """Создаёт тестовый движок БД и таблицы."""
    from database import engine
    async with engine.begin() as conn:
        await conn.run_sync(Base.metadata.create_all)
    yield engine
    async with engine.begin() as conn:
        await conn.run_sync(Base.metadata.drop_all)


@pytest_asyncio.fixture
async def db_session(db_engine):
    """Создаёт тестовую сессию БД."""
    async with AsyncSessionLocal() as session:
        yield session


@pytest_asyncio.fixture
async def async_client(db_engine):
    """HTTP-клиент для тестирования FastAPI."""
    from httpx import ASGITransport, AsyncClient
    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as client:
        # Инициализируем БД (seed_data)
        await init_db()
        yield client
