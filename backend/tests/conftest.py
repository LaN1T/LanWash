import os
import sys
from datetime import datetime

import pytest
import pytest_asyncio

# Переопределяем DATABASE_URL ДО импорта приложения
os.environ["DATABASE_URL"] = "sqlite+aiosqlite:///:memory:"
os.environ["JWT_SECRET_KEY"] = "test_secret_key_minimum_32_chars_long"
os.environ["INITIAL_ADMIN_PASSWORD"] = "TestPass123!"
os.environ["FCM_ENCRYPTION_KEY"] = "zM1-xb7fhoXQAbRzvCGSyMeZb37IdYLS2GN_zBUrFYw="

# Добавляем backend в PYTHONPATH
sys.path.insert(0, os.path.join(os.path.dirname(__file__), ".."))


# Отключаем rate limiting для тестов
from core.limiter import limiter
from database import AsyncSessionLocal, init_db
from db_models import Base, User
from main import app

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
