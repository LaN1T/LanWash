import pytest


class TestLogs:
    """Тесты логирования действий."""

    @pytest.mark.asyncio
    async def test_create_log_public(self, async_client):
        """Создание лога — публичный endpoint (для логирования входа/регистрации)."""
        response = await async_client.post("/api/logs/", json={
            "username": "testuser",
            "action": "login",
            "details": "Вход с устройства iPhone",
        })
        assert response.status_code == 200
        data = response.json()
        assert data["username"] == "testuser"
        assert data["action"] == "login"
        assert "id" in data

    @pytest.mark.asyncio
    async def test_get_all_logs_admin(self, async_client, admin_token):
        # Создаём лог
        await async_client.post("/api/logs/", json={
            "username": "testuser",
            "action": "test_action",
            "details": "test details",
        })
        response = await async_client.get(
            "/api/logs/",
            headers={"Authorization": f"Bearer {admin_token}"},
        )
        assert response.status_code == 200
        data = response.json()
        assert isinstance(data, list)
        assert len(data) >= 1
        assert data[0]["action"] == "test_action"

    @pytest.mark.asyncio
    async def test_get_all_logs_forbidden(self, async_client, client_token):
        response = await async_client.get(
            "/api/logs/",
            headers={"Authorization": f"Bearer {client_token}"},
        )
        assert response.status_code == 403

    @pytest.mark.asyncio
    async def test_get_logs_by_user(self, async_client, admin_token):
        await async_client.post("/api/logs/", json={
            "username": "specific_user",
            "action": "specific_action",
            "details": "",
        })
        response = await async_client.get(
            "/api/logs/by-user/specific_user",
            headers={"Authorization": f"Bearer {admin_token}"},
        )
        assert response.status_code == 200
        data = response.json()
        assert len(data) >= 1
        assert data[0]["username"] == "specific_user"

    @pytest.mark.asyncio
    async def test_clear_logs_admin(self, async_client, admin_token):
        response = await async_client.delete(
            "/api/logs/",
            headers={"Authorization": f"Bearer {admin_token}"},
        )
        assert response.status_code == 200
        assert response.json()["ok"] is True

        # Проверяем что логи очищены
        response = await async_client.get(
            "/api/logs/",
            headers={"Authorization": f"Bearer {admin_token}"},
        )
        assert response.json() == []

    @pytest.mark.asyncio
    async def test_clear_logs_forbidden(self, async_client, client_token):
        response = await async_client.delete(
            "/api/logs/",
            headers={"Authorization": f"Bearer {client_token}"},
        )
        assert response.status_code == 403
