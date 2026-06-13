import pytest


class TestRegister:
    @pytest.mark.asyncio
    async def test_register_success(self, async_client):
        response = await async_client.post("/api/auth/register", json={
            "username": "testuser",
            "password": "TestPass123!",
            "displayName": "Тест",
            "phone": "+79990000000",
            "carModel": "Toyota",
            "carNumber": "А123БВ777",
        })
        assert response.status_code == 200
        data = response.json()
        assert "user" in data
        assert data["user"]["username"] == "testuser"
        assert data["user"]["role"] == "client"
        assert "access_token" in data

    @pytest.mark.asyncio
    async def test_register_weak_password(self, async_client):
        response = await async_client.post("/api/auth/register", json={
            "username": "weakuser",
            "password": "123",
            "displayName": "Weak",
        })
        # Pydantic валидация срабатывает раньше кастомной — возвращает 422
        assert response.status_code == 422

    @pytest.mark.asyncio
    async def test_register_duplicate_username(self, async_client):
        # Первая регистрация
        await async_client.post("/api/auth/register", json={
            "username": "dupuser",
            "password": "TestPass123!",
            "displayName": "First",
        })
        # Вторая регистрация с тем же username
        response = await async_client.post("/api/auth/register", json={
            "username": "dupuser",
            "password": "TestPass123!",
            "displayName": "Second",
        })
        assert response.status_code == 400
        assert "Регистрация не удалась" in response.json()["detail"]

    @pytest.mark.asyncio
    async def test_register_honeypot_rejected(self, async_client):
        response = await async_client.post("/api/auth/register", json={
            "username": "honeypotuser",
            "password": "TestPass123!",
            "displayName": "Honeypot",
            "website": "http://spam.example.com",
        })
        assert response.status_code == 400
        assert "Регистрация не удалась" in response.json()["detail"]


class TestLogin:
    @pytest.mark.asyncio
    async def test_login_success(self, async_client):
        # Регистрация
        await async_client.post("/api/auth/register", json={
            "username": "logintest",
            "password": "TestPass123!",
            "displayName": "Login Test",
        })
        # Логин
        response = await async_client.post("/api/auth/login", json={
            "username": "logintest",
            "password": "TestPass123!",
        })
        assert response.status_code == 200
        data = response.json()
        assert data["user"]["username"] == "logintest"
        assert "access_token" in data
        assert data["token_type"] == "bearer"

    @pytest.mark.asyncio
    async def test_login_wrong_password(self, async_client):
        # Регистрация
        await async_client.post("/api/auth/register", json={
            "username": "wrongpass",
            "password": "TestPass123!",
            "displayName": "Wrong Pass",
        })
        # Логин с неверным паролем
        response = await async_client.post("/api/auth/login", json={
            "username": "wrongpass",
            "password": "WrongPass123!",
        })
        assert response.status_code == 401
        assert "Неверный логин или пароль" in response.json()["detail"]

    @pytest.mark.asyncio
    async def test_login_nonexistent_user(self, async_client):
        response = await async_client.post("/api/auth/login", json={
            "username": "nonexistent",
            "password": "AnyPass123!",
        })
        assert response.status_code == 401
        assert "Неверный логин или пароль" in response.json()["detail"]


class TestProfile:
    @pytest.mark.asyncio
    async def test_update_profile(self, async_client):
        # Регистрация и логин
        reg = await async_client.post("/api/auth/register", json={
            "username": "profiletest",
            "password": "TestPass123!",
            "displayName": "Before",
        })
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
    async def test_update_profile_unauthorized(self, async_client):
        response = await async_client.put("/api/auth/profile/1", json={
            "displayName": "Hacker",
        })
        assert response.status_code == 401


class TestProtectedEndpoints:
    @pytest.mark.asyncio
    async def test_washers_without_auth(self, async_client):
        response = await async_client.get("/api/auth/washers")
        assert response.status_code == 401

    @pytest.mark.asyncio
    async def test_washers_with_auth(self, async_client):
        # Регистрация
        reg = await async_client.post("/api/auth/register", json={
            "username": "washercheck",
            "password": "TestPass123!",
            "displayName": "Washer Check",
        })
        token = reg.json()["access_token"]
        response = await async_client.get(
            "/api/auth/washers",
            headers={"Authorization": f"Bearer {token}"},
        )
        assert response.status_code == 200
        assert isinstance(response.json(), list)
