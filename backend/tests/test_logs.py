import pytest

from core.pagination import decode_cursor


class TestLogs:
    """Тесты логирования действий."""

    @pytest.mark.asyncio
    async def test_create_log_public(self, async_client):
        """Создание лога — публичный endpoint (для логирования входа/регистрации)."""
        response = await async_client.post(
            "/api/logs/",
            json={
                "username": "testuser",
                "action": "login",
                "details": "Вход с устройства iPhone",
            },
        )
        assert response.status_code == 200
        data = response.json()
        assert data["username"] == "testuser"
        assert data["action"] == "login"
        assert "id" in data

    @pytest.mark.asyncio
    async def test_get_all_logs_admin(self, async_client, admin_token):
        # Создаём лог
        await async_client.post(
            "/api/logs/",
            json={
                "username": "testuser",
                "action": "test_action",
                "details": "test details",
            },
        )
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
        await async_client.post(
            "/api/logs/",
            json={
                "username": "specific_user",
                "action": "specific_action",
                "details": "",
            },
        )
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


class TestLogsCursorPagination:
    @pytest.mark.asyncio
    async def test_get_all_logs_without_cursor(self, async_client, admin_token):
        for i in range(3):
            await async_client.post(
                "/api/logs/",
                json={
                    "username": "cursor_user",
                    "action": f"action_{i}",
                    "details": "",
                },
            )
        response = await async_client.get(
            "/api/logs/",
            headers={"Authorization": f"Bearer {admin_token}"},
        )
        assert response.status_code == 200
        data = response.json()
        assert len(data) >= 3
        assert "X-Next-Cursor" not in response.headers

    @pytest.mark.asyncio
    async def test_get_all_logs_with_cursor(self, async_client, admin_token):
        for i in range(3):
            await async_client.post(
                "/api/logs/",
                json={
                    "username": "cursor_user",
                    "action": f"cursor_action_{i}",
                    "details": "",
                },
            )
        first_page = await async_client.get(
            "/api/logs/?limit=1",
            headers={"Authorization": f"Bearer {admin_token}"},
        )
        assert first_page.status_code == 200
        first_data = first_page.json()
        assert len(first_data) == 1
        assert "X-Next-Cursor" in first_page.headers
        cursor = first_page.headers["X-Next-Cursor"]
        assert decode_cursor(cursor)["id"] != first_data[0]["id"]

        second_page = await async_client.get(
            f"/api/logs/?limit=1&cursor={cursor}",
            headers={"Authorization": f"Bearer {admin_token}"},
        )
        assert second_page.status_code == 200
        second_data = second_page.json()
        assert len(second_data) == 1
        assert second_data[0]["id"] != first_data[0]["id"]

    @pytest.mark.asyncio
    async def test_get_logs_by_user_with_cursor(self, async_client, admin_token):
        username = "by_user_cursor"
        for i in range(3):
            await async_client.post(
                "/api/logs/",
                json={
                    "username": username,
                    "action": f"user_cursor_{i}",
                    "details": "",
                },
            )
        first_page = await async_client.get(
            f"/api/logs/by-user/{username}?limit=1",
            headers={"Authorization": f"Bearer {admin_token}"},
        )
        assert first_page.status_code == 200
        first_data = first_page.json()
        assert len(first_data) == 1
        cursor = first_page.headers["X-Next-Cursor"]

        second_page = await async_client.get(
            f"/api/logs/by-user/{username}?limit=1&cursor={cursor}",
            headers={"Authorization": f"Bearer {admin_token}"},
        )
        assert second_page.status_code == 200
        second_data = second_page.json()
        assert len(second_data) == 1
        assert second_data[0]["id"] != first_data[0]["id"]
        assert second_data[0]["username"] == username
