import pytest


class TestNotes:
    """Тесты заметок мойщиков."""

    @pytest.mark.asyncio
    async def test_create_note(self, async_client, washer_token):
        response = await async_client.post(
            "/api/notes/?username=washer_test",
            headers={"Authorization": f"Bearer {washer_token}"},
            json={
                "title": "Тестовая заметка",
                "message": "Содержание заметки",
                "category": "general",
            },
        )
        assert response.status_code == 200
        data = response.json()
        assert data["username"] == "washer_test"
        assert data["title"] == "Тестовая заметка"
        assert data["isRead"] is False

    @pytest.mark.asyncio
    async def test_create_note_forbidden_other_user(self, async_client, washer_token):
        """Мойщик не может создать заметку от имени другого."""
        response = await async_client.post(
            "/api/notes/?username=other_user",
            headers={"Authorization": f"Bearer {washer_token}"},
            json={
                "title": "Поддельная заметка",
                "message": "",
                "category": "general",
            },
        )
        assert response.status_code == 403

    @pytest.mark.asyncio
    async def test_get_all_notes_admin(self, async_client, admin_token, washer_token):
        # Создаём заметку мойщиком
        await async_client.post(
            "/api/notes/?username=washer_test",
            headers={"Authorization": f"Bearer {washer_token}"},
            json={"title": "Для админа", "message": "", "category": "general"},
        )
        response = await async_client.get(
            "/api/notes/",
            headers={"Authorization": f"Bearer {admin_token}"},
        )
        assert response.status_code == 200
        data = response.json()
        assert len(data) >= 1
        assert any(n["title"] == "Для админа" for n in data)

    @pytest.mark.asyncio
    async def test_get_all_notes_forbidden(self, async_client, client_token):
        response = await async_client.get(
            "/api/notes/",
            headers={"Authorization": f"Bearer {client_token}"},
        )
        assert response.status_code == 403

    @pytest.mark.asyncio
    async def test_get_notes_by_user(self, async_client, washer_token):
        response = await async_client.get(
            "/api/notes/by-user/washer_test",
            headers={"Authorization": f"Bearer {washer_token}"},
        )
        assert response.status_code == 200
        data = response.json()
        assert isinstance(data, list)

    @pytest.mark.asyncio
    async def test_unread_count(self, async_client, admin_token, washer_token):
        # Создаём непрочитанную заметку
        await async_client.post(
            "/api/notes/?username=washer_test",
            headers={"Authorization": f"Bearer {washer_token}"},
            json={"title": "Непрочитанная", "message": "", "category": "general"},
        )
        response = await async_client.get(
            "/api/notes/unread-count",
            headers={"Authorization": f"Bearer {admin_token}"},
        )
        assert response.status_code == 200
        assert response.json()["count"] >= 1

    @pytest.mark.asyncio
    async def test_mark_read(self, async_client, admin_token, washer_token):
        # Создаём заметку
        create_resp = await async_client.post(
            "/api/notes/?username=washer_test",
            headers={"Authorization": f"Bearer {washer_token}"},
            json={"title": "Прочитать", "message": "", "category": "general"},
        )
        note_id = create_resp.json()["id"]

        response = await async_client.put(
            f"/api/notes/{note_id}/read",
            headers={"Authorization": f"Bearer {admin_token}"},
        )
        assert response.status_code == 200
        assert response.json()["ok"] is True

    @pytest.mark.asyncio
    async def test_mark_all_read(self, async_client, admin_token, washer_token):
        await async_client.post(
            "/api/notes/?username=washer_test",
            headers={"Authorization": f"Bearer {washer_token}"},
            json={"title": "Все прочитать", "message": "", "category": "general"},
        )
        response = await async_client.put(
            "/api/notes/read-all",
            headers={"Authorization": f"Bearer {admin_token}"},
        )
        assert response.status_code == 200
        assert response.json()["ok"] is True

        # Проверяем что счётчик = 0
        count_resp = await async_client.get(
            "/api/notes/unread-count",
            headers={"Authorization": f"Bearer {admin_token}"},
        )
        assert count_resp.json()["count"] == 0

    @pytest.mark.asyncio
    async def test_delete_note(self, async_client, admin_token, washer_token):
        create_resp = await async_client.post(
            "/api/notes/?username=washer_test",
            headers={"Authorization": f"Bearer {washer_token}"},
            json={"title": "На удаление", "message": "", "category": "general"},
        )
        note_id = create_resp.json()["id"]

        response = await async_client.delete(
            f"/api/notes/{note_id}",
            headers={"Authorization": f"Bearer {admin_token}"},
        )
        assert response.status_code == 200
        assert response.json()["ok"] is True
