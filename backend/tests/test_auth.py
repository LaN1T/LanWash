import hashlib
import hmac
import json
import time
from datetime import datetime
from urllib.parse import urlencode

import pytest
import pytest_asyncio

from core.config import get_settings
from models import User
from schemas import TelegramRegisterRequest, UserResponse
from services.auth_service import (
    AuthService,
    InvalidCredentialsError,
    TelegramAlreadyLinkedError,
    TelegramNotLinkedError,
    UsernameAlreadyExistsError,
)

TEST_BOT_TOKEN = "test_bot_token"


def make_test_init_data(telegram_id: str) -> str:
    """Build a valid Telegram WebApp initData string for tests."""
    params = {
        "user": json.dumps({"id": telegram_id}, separators=(",", ":")),
        "auth_date": str(int(time.time())),
    }
    data_check_string = "\n".join(f"{k}={v}" for k, v in sorted(params.items()))
    secret_key = hmac.new(
        b"WebAppData", TEST_BOT_TOKEN.encode(), hashlib.sha256
    ).digest()
    params["hash"] = hmac.new(
        secret_key, data_check_string.encode(), hashlib.sha256
    ).hexdigest()
    return urlencode(params)


@pytest.fixture(autouse=True)
def _set_test_telegram_bot_token(monkeypatch):
    """Ensure initData verification uses the test bot token."""
    monkeypatch.setattr(get_settings(), "telegram_bot_token", TEST_BOT_TOKEN)


@pytest_asyncio.fixture
async def test_user(db_session):
    """Pre-created user for Telegram linking tests."""
    from services.auth_service import get_password_hash

    user = User(
        username="linktestuser",
        passwordHash=get_password_hash("CorrectPassword123!"),
        role="client",
        displayName="Link Test",
        createdAt=datetime.now(),
    )
    db_session.add(user)
    await db_session.commit()
    return user


class TestRegister:
    @pytest.mark.asyncio
    async def test_register_success(self, async_client):
        response = await async_client.post(
            "/api/auth/register",
            json={
                "username": "testuser",
                "password": "TestPass123!",
                "displayName": "Тест",
                "phone": "+79990000000",
                "carModel": "Toyota",
                "carNumber": "А123БВ777",
            },
        )
        assert response.status_code == 200
        data = response.json()
        assert "user" in data
        assert data["user"]["username"] == "testuser"
        assert data["user"]["role"] == "client"
        assert "access_token" in data

    @pytest.mark.asyncio
    async def test_register_weak_password(self, async_client):
        response = await async_client.post(
            "/api/auth/register",
            json={
                "username": "weakuser",
                "password": "123",
                "displayName": "Weak",
            },
        )
        # Pydantic валидация срабатывает раньше кастомной — возвращает 422
        assert response.status_code == 422

    @pytest.mark.asyncio
    async def test_register_duplicate_username(self, async_client):
        # Первая регистрация
        await async_client.post(
            "/api/auth/register",
            json={
                "username": "dupuser",
                "password": "TestPass123!",
                "displayName": "First",
            },
        )
        # Вторая регистрация с тем же username
        response = await async_client.post(
            "/api/auth/register",
            json={
                "username": "dupuser",
                "password": "TestPass123!",
                "displayName": "Second",
            },
        )
        assert response.status_code == 400
        assert "Регистрация не удалась" in response.json()["detail"]

    @pytest.mark.asyncio
    async def test_register_honeypot_rejected(self, async_client):
        response = await async_client.post(
            "/api/auth/register",
            json={
                "username": "honeypotuser",
                "password": "TestPass123!",
                "displayName": "Honeypot",
                "website": "http://spam.example.com",
            },
        )
        assert response.status_code == 400
        assert "Регистрация не удалась" in response.json()["detail"]


class TestLogin:
    @pytest.mark.asyncio
    async def test_login_success(self, async_client):
        # Регистрация
        await async_client.post(
            "/api/auth/register",
            json={
                "username": "logintest",
                "password": "TestPass123!",
                "displayName": "Login Test",
            },
        )
        # Логин
        response = await async_client.post(
            "/api/auth/login",
            json={
                "username": "logintest",
                "password": "TestPass123!",
            },
        )
        assert response.status_code == 200
        data = response.json()
        assert data["user"]["username"] == "logintest"
        assert "access_token" in data
        assert data["token_type"] == "bearer"

    @pytest.mark.asyncio
    async def test_login_wrong_password(self, async_client):
        # Регистрация
        await async_client.post(
            "/api/auth/register",
            json={
                "username": "wrongpass",
                "password": "TestPass123!",
                "displayName": "Wrong Pass",
            },
        )
        # Логин с неверным паролем
        response = await async_client.post(
            "/api/auth/login",
            json={
                "username": "wrongpass",
                "password": "WrongPass123!",
            },
        )
        assert response.status_code == 401
        assert "Неверный логин или пароль" in response.json()["detail"]

    @pytest.mark.asyncio
    async def test_login_nonexistent_user(self, async_client):
        response = await async_client.post(
            "/api/auth/login",
            json={
                "username": "nonexistent",
                "password": "AnyPass123!",
            },
        )
        assert response.status_code == 401
        assert "Неверный логин или пароль" in response.json()["detail"]


class TestProfile:
    @pytest.mark.asyncio
    async def test_update_profile(self, async_client):
        # Регистрация и логин
        reg = await async_client.post(
            "/api/auth/register",
            json={
                "username": "profiletest",
                "password": "TestPass123!",
                "displayName": "Before",
            },
        )
        token = reg.json()["access_token"]

        # Обновление профиля
        user_id = reg.json()["user"]["id"]
        response = await async_client.put(
            f"/api/auth/profile/{user_id}",
            headers={"Authorization": f"Bearer {token}"},
            json={"displayName": "After", "phone": "+79991112233"},
        )
        assert response.status_code == 200
        data = response.json()
        assert data["displayName"] == "After"
        assert data["phone"] == "+79991112233"

    @pytest.mark.asyncio
    async def test_update_profile_email(self, async_client):
        reg = await async_client.post(
            "/api/auth/register",
            json={
                "username": "emailtest",
                "password": "TestPass123!",
                "displayName": "Email Test",
            },
        )
        token = reg.json()["access_token"]
        user_id = reg.json()["user"]["id"]

        response = await async_client.put(
            f"/api/auth/profile/{user_id}",
            headers={"Authorization": f"Bearer {token}"},
            json={"email": "email@test.com"},
        )
        assert response.status_code == 200
        assert response.json()["email"] == "email@test.com"

    @pytest.mark.asyncio
    async def test_update_profile_unauthorized(self, async_client):
        response = await async_client.put(
            "/api/auth/profile/1",
            json={
                "displayName": "Hacker",
            },
        )
        assert response.status_code == 401


class TestProtectedEndpoints:
    @pytest.mark.asyncio
    async def test_washers_without_auth(self, async_client):
        response = await async_client.get("/api/auth/washers")
        assert response.status_code == 401

    @pytest.mark.asyncio
    async def test_washers_with_auth(self, async_client):
        # Регистрация
        reg = await async_client.post(
            "/api/auth/register",
            json={
                "username": "washercheck",
                "password": "TestPass123!",
                "displayName": "Washer Check",
            },
        )
        token = reg.json()["access_token"]
        response = await async_client.get(
            "/api/auth/washers",
            headers={"Authorization": f"Bearer {token}"},
        )
        assert response.status_code == 200
        assert isinstance(response.json(), list)


class TestRefreshToken:
    @pytest.mark.asyncio
    async def test_login_returns_refresh_token_and_cookie(self, async_client):
        await async_client.post(
            "/api/auth/register",
            json={
                "username": "refreshuser",
                "password": "TestPass123!",
                "displayName": "Refresh Test",
            },
        )
        response = await async_client.post(
            "/api/auth/login",
            json={
                "username": "refreshuser",
                "password": "TestPass123!",
            },
        )
        assert response.status_code == 200
        data = response.json()
        assert "refresh_token" in data
        assert data["token_type"] == "bearer"

        set_cookie = response.headers.get("set-cookie")
        assert set_cookie is not None
        assert "refresh_token=" in set_cookie
        assert "HttpOnly" in set_cookie
        assert "refresh_token" in response.cookies

    @pytest.mark.asyncio
    async def test_refresh_endpoint_returns_new_tokens(self, async_client):
        await async_client.post(
            "/api/auth/register",
            json={
                "username": "refreshrotate",
                "password": "TestPass123!",
                "displayName": "Refresh Rotate",
            },
        )
        login_response = await async_client.post(
            "/api/auth/login",
            json={
                "username": "refreshrotate",
                "password": "TestPass123!",
            },
        )
        assert login_response.status_code == 200
        old_refresh = login_response.json()["refresh_token"]

        # /auth/refresh uses the httpOnly cookie automatically stored by the client
        refresh_response = await async_client.post("/api/auth/refresh")
        assert refresh_response.status_code == 200
        data = refresh_response.json()
        assert "access_token" in data
        assert "refresh_token" in data
        assert data["refresh_token"] != old_refresh
        assert data["token_type"] == "bearer"

        # New access token works on a protected route
        washers = await async_client.get(
            "/api/auth/washers",
            headers={"Authorization": f"Bearer {data['access_token']}"},
        )
        assert washers.status_code == 200
        assert isinstance(washers.json(), list)

    @pytest.mark.asyncio
    async def test_refresh_with_blacklisted_token_returns_401(
        self, async_client, monkeypatch
    ):
        await async_client.post(
            "/api/auth/register",
            json={
                "username": "blacklistedrefresh",
                "password": "TestPass123!",
                "displayName": "Blacklisted Refresh",
            },
        )
        login_response = await async_client.post(
            "/api/auth/login",
            json={
                "username": "blacklistedrefresh",
                "password": "TestPass123!",
            },
        )
        assert login_response.status_code == 200

        async def _always_blacklisted(jti):
            return True

        monkeypatch.setattr(
            "services.auth_service.is_token_blacklisted", _always_blacklisted
        )

        refresh_response = await async_client.post("/api/auth/refresh")
        assert refresh_response.status_code == 401

    @pytest.mark.asyncio
    async def test_refresh_token_cannot_be_used_as_access_token(
        self, async_client
    ):
        await async_client.post(
            "/api/auth/register",
            json={
                "username": "refreshasaccess",
                "password": "TestPass123!",
                "displayName": "Refresh as Access",
            },
        )
        login_response = await async_client.post(
            "/api/auth/login",
            json={
                "username": "refreshasaccess",
                "password": "TestPass123!",
            },
        )
        assert login_response.status_code == 200
        refresh_token = login_response.json()["refresh_token"]

        response = await async_client.get(
            "/api/auth/washers",
            headers={"Authorization": f"Bearer {refresh_token}"},
        )
        assert response.status_code == 401


class TestTelegramAuth:
    @pytest.mark.asyncio
    async def test_telegram_auth_unlinked_raises(self, db_session, monkeypatch):
        def _fake_verify(init_data, max_age_seconds=300):
            return {
                "id": 999999,
                "username": "tg_unlinked",
                "first_name": "Unlinked",
            }

        monkeypatch.setattr(
            "services.telegram_auth_service.verify_telegram_init_data", _fake_verify
        )
        svc = AuthService(db_session)
        with pytest.raises(TelegramNotLinkedError):
            await svc.telegram_auth("dummy_init_data")

    @pytest.mark.asyncio
    async def test_telegram_auth_unlinked_returns_409(self, async_client, monkeypatch):
        def _fake_verify(init_data, max_age_seconds=300):
            return {
                "id": 999999,
                "username": "tg_unlinked",
                "first_name": "Unlinked",
            }

        monkeypatch.setattr(
            "services.telegram_auth_service.verify_telegram_init_data", _fake_verify
        )
        response = await async_client.post(
            "/api/auth/telegram", json={"initData": "dummy_init_data"}
        )
        assert response.status_code == 409
        assert "не привязан" in response.json()["detail"].lower()


class TestUserResponseTelegramLinked:
    def test_telegram_linked_true_when_telegram_id_set(self):
        user = UserResponse(
            id=1,
            username="tguser",
            role="client",
            displayName="TG User",
            phone="",
            carModel="",
            carNumber="",
            createdAt=datetime.now(),
            isFavoriteAdmin=False,
            telegramId="123456789",
        )
        assert user.telegramLinked is True

    def test_telegram_linked_false_when_telegram_id_empty(self):
        user = UserResponse(
            id=2,
            username="notguser",
            role="client",
            displayName="No TG User",
            phone="",
            carModel="",
            carNumber="",
            createdAt=datetime.now(),
            isFavoriteAdmin=False,
            telegramId=None,
        )
        assert user.telegramLinked is False

    def test_telegram_linked_false_when_telegram_id_is_empty_string(self):
        user = UserResponse(
            id=3,
            username="emptytguser",
            role="client",
            displayName="Empty TG User",
            phone="",
            carModel="",
            carNumber="",
            createdAt=datetime.now(),
            isFavoriteAdmin=False,
            telegramId="",
        )
        assert user.telegramLinked is False


class TestLinkTelegram:
    @pytest.mark.asyncio
    async def test_link_telegram_success(self, db_session, test_user):
        svc = AuthService(db_session)
        init_data = make_test_init_data(telegram_id="999999")
        result = await svc.link_telegram(
            init_data, test_user.username, "CorrectPassword123!"
        )
        assert result["user"].telegramId == "999999"

    @pytest.mark.asyncio
    async def test_link_telegram_wrong_password(self, db_session, test_user):
        svc = AuthService(db_session)
        init_data = make_test_init_data(telegram_id="999999")
        with pytest.raises(InvalidCredentialsError):
            await svc.link_telegram(init_data, test_user.username, "wrong")

    @pytest.mark.asyncio
    async def test_link_telegram_already_linked_to_other_user(self, db_session):
        from services.auth_service import get_password_hash

        first = User(
            username="first_tg",
            passwordHash=get_password_hash("TestPass123!"),
            role="client",
            displayName="First",
            createdAt=datetime.now(),
            telegramId="shared_tg_id",
        )
        second = User(
            username="second_tg",
            passwordHash=get_password_hash("TestPass123!"),
            role="client",
            displayName="Second",
            createdAt=datetime.now(),
        )
        db_session.add(first)
        db_session.add(second)
        await db_session.commit()

        svc = AuthService(db_session)
        init_data = make_test_init_data(telegram_id="shared_tg_id")
        with pytest.raises(TelegramAlreadyLinkedError):
            await svc.link_telegram(init_data, "second_tg", "TestPass123!")

    @pytest.mark.asyncio
    async def test_link_telegram_endpoint_returns_409_when_already_linked(
        self, async_client, db_session
    ):
        from services.auth_service import get_password_hash

        first = User(
            username="first_tg_endpoint",
            passwordHash=get_password_hash("TestPass123!"),
            role="client",
            displayName="First Endpoint",
            createdAt=datetime.now(),
            telegramId="shared_endpoint_tg_id",
        )
        second = User(
            username="second_tg_endpoint",
            passwordHash=get_password_hash("TestPass123!"),
            role="client",
            displayName="Second Endpoint",
            createdAt=datetime.now(),
        )
        db_session.add(first)
        db_session.add(second)
        await db_session.commit()

        init_data = make_test_init_data(telegram_id="shared_endpoint_tg_id")
        response = await async_client.post(
            "/api/auth/link-telegram",
            json={
                "initData": init_data,
                "username": "second_tg_endpoint",
                "password": "TestPass123!",
            },
        )
        assert response.status_code == 409
        assert "уже привязан" in response.json()["detail"].lower()

    @pytest.mark.asyncio
    async def test_link_telegram_nonexistent_user_returns_invalid_credentials(
        self, db_session
    ):
        svc = AuthService(db_session)
        init_data = make_test_init_data(telegram_id="999999")
        with pytest.raises(InvalidCredentialsError):
            await svc.link_telegram(init_data, "nonexistent_user", "AnyPass123!")

    @pytest.mark.asyncio
    async def test_link_telegram_idempotent_same_user(self, db_session, test_user):
        svc = AuthService(db_session)
        init_data = make_test_init_data(telegram_id="999999")
        first = await svc.link_telegram(
            init_data, test_user.username, "CorrectPassword123!"
        )
        assert first["user"].telegramId == "999999"
        assert "access_token" in first

        second = await svc.link_telegram(
            init_data, test_user.username, "CorrectPassword123!"
        )
        assert second["user"].telegramId == "999999"
        assert "access_token" in second

    @pytest.mark.asyncio
    async def test_link_telegram_endpoint_invalid_init_data_returns_401(
        self, async_client
    ):
        response = await async_client.post(
            "/api/auth/link-telegram",
            json={
                "initData": "tampered_or_expired_init_data",
                "username": "linktestuser",
                "password": "CorrectPassword123!",
            },
        )
        assert response.status_code == 401
        assert "telegram" in response.json()["detail"].lower()

    @pytest.mark.asyncio
    async def test_link_telegram_endpoint_wrong_password_returns_401(
        self, async_client, test_user
    ):
        init_data = make_test_init_data(telegram_id="999999")
        response = await async_client.post(
            "/api/auth/link-telegram",
            json={
                "initData": init_data,
                "username": test_user.username,
                "password": "WrongPassword123!",
            },
        )
        assert response.status_code == 401
        assert "неверный логин или пароль" in response.json()["detail"].lower()


class TestTelegramRegister:
    @pytest.mark.asyncio
    async def test_telegram_register_user_success(self, db_session):
        svc = AuthService(db_session)
        req = TelegramRegisterRequest(
            initData=make_test_init_data(telegram_id="111222"),
            username="newtguser",
            password="StrongPass123!",
            displayName="New User",
        )
        result = await svc.register_telegram_user(req)
        assert result["user"].username == "newtguser"
        assert result["user"].telegramId == "111222"

    @pytest.mark.asyncio
    async def test_telegram_register_duplicate_telegram(self, db_session):
        svc = AuthService(db_session)
        req1 = TelegramRegisterRequest(
            initData=make_test_init_data(telegram_id="111222"),
            username="tguser1",
            password="StrongPass123!",
            displayName="First",
        )
        await svc.register_telegram_user(req1)

        req2 = TelegramRegisterRequest(
            initData=make_test_init_data(telegram_id="111222"),
            username="tguser2",
            password="StrongPass123!",
            displayName="Second",
        )
        with pytest.raises(TelegramAlreadyLinkedError):
            await svc.register_telegram_user(req2)

    @pytest.mark.asyncio
    async def test_telegram_register_duplicate_username(self, db_session):
        svc = AuthService(db_session)
        req1 = TelegramRegisterRequest(
            initData=make_test_init_data(telegram_id="111222"),
            username="dupusertg",
            password="StrongPass123!",
            displayName="First",
        )
        await svc.register_telegram_user(req1)

        req2 = TelegramRegisterRequest(
            initData=make_test_init_data(telegram_id="333444"),
            username="dupusertg",
            password="StrongPass123!",
            displayName="Second",
        )
        with pytest.raises(UsernameAlreadyExistsError):
            await svc.register_telegram_user(req2)

    @pytest.mark.asyncio
    async def test_telegram_register_endpoint_success(self, async_client):
        response = await async_client.post(
            "/api/auth/telegram-register",
            json={
                "initData": make_test_init_data(telegram_id="333444"),
                "username": "endpointtg",
                "password": "StrongPass123!",
                "displayName": "Endpoint",
            },
        )
        assert response.status_code == 200
        data = response.json()
        assert data["user"]["username"] == "endpointtg"
        assert data["user"]["telegramId"] == "333444"
        assert "access_token" in data
