import pytest


class TestServices:
    """Тесты услуг и акций."""

    @pytest.mark.asyncio
    async def test_get_all_services(self, async_client, client_token):
        response = await async_client.get(
            "/api/services/",
            headers={"Authorization": f"Bearer {client_token}"},
        )
        assert response.status_code == 200
        data = response.json()
        assert isinstance(data, list)
        assert len(data) >= 1

    @pytest.mark.asyncio
    async def test_get_promos(self, async_client, client_token):
        response = await async_client.get(
            "/api/services/promos",
            headers={"Authorization": f"Bearer {client_token}"},
        )
        assert response.status_code == 200
        data = response.json()
        assert isinstance(data, list)

    @pytest.mark.asyncio
    async def test_get_categories(self, async_client, client_token):
        response = await async_client.get(
            "/api/services/categories",
            headers={"Authorization": f"Bearer {client_token}"},
        )
        assert response.status_code == 200
        data = response.json()
        assert isinstance(data, list)
        assert "Акции" in data

    @pytest.mark.asyncio
    async def test_create_update_delete_service(self, async_client, admin_token):
        create_resp = await async_client.post(
            "/api/services/",
            headers={"Authorization": f"Bearer {admin_token}"},
            json={
                "id": "test_service_1",
                "name": "Тестовая услуга",
                "description": "Описание тестовой услуги",
                "price": 1000,
                "durationMinutes": 30,
                "category": "Тестовая категория",
                "isFavorite": False,
                "isFromApi": False,
            },
        )
        assert create_resp.status_code == 200
        assert create_resp.json()["name"] == "Тестовая услуга"

        update_resp = await async_client.put(
            "/api/services/test_service_1",
            headers={"Authorization": f"Bearer {admin_token}"},
            json={
                "id": "test_service_1",
                "name": "Обновлённая услуга",
                "description": "Новое описание",
                "price": 1500,
                "durationMinutes": 45,
                "category": "Тестовая категория",
                "isFavorite": True,
                "isFromApi": False,
            },
        )
        assert update_resp.status_code == 200
        assert update_resp.json()["name"] == "Обновлённая услуга"
        assert update_resp.json()["price"] == 1500

        del_resp = await async_client.delete(
            "/api/services/test_service_1",
            headers={"Authorization": f"Bearer {admin_token}"},
        )
        assert del_resp.status_code == 200
        assert del_resp.json()["ok"] is True

    @pytest.mark.asyncio
    async def test_create_service_forbidden(self, async_client, client_token):
        response = await async_client.post(
            "/api/services/",
            headers={"Authorization": f"Bearer {client_token}"},
            json={
                "id": "hack",
                "name": "Hacked",
                "description": "",
                "price": 0,
                "durationMinutes": 0,
                "category": "",
                "isFavorite": False,
                "isFromApi": False,
            },
        )
        assert response.status_code == 403

    @pytest.mark.asyncio
    async def test_service_favorites(self, async_client, client_token):
        username = "client_test"
        # Добавляем в избранное
        toggle_on = await async_client.post(
            "/api/services/favorites/toggle",
            headers={"Authorization": f"Bearer {client_token}"},
            json={"username": username, "serviceId": "s4"},
        )
        assert toggle_on.status_code == 200
        assert toggle_on.json()["isFavorite"] is True

        # Проверяем список избранного
        get_fav = await async_client.get(
            f"/api/services/favorites/{username}",
            headers={"Authorization": f"Bearer {client_token}"},
        )
        assert get_fav.status_code == 200
        assert "s4" in get_fav.json()

        # Убираем из избранного
        toggle_off = await async_client.post(
            "/api/services/favorites/toggle",
            headers={"Authorization": f"Bearer {client_token}"},
            json={"username": username, "serviceId": "s4"},
        )
        assert toggle_off.status_code == 200
        assert toggle_off.json()["isFavorite"] is False

    @pytest.mark.asyncio
    async def test_extra_favorites(self, async_client, client_token):
        username = "client_test"
        toggle_on = await async_client.post(
            "/api/services/extra-favorites/toggle",
            headers={"Authorization": f"Bearer {client_token}"},
            json={"username": username, "serviceId": "s4"},
        )
        assert toggle_on.status_code == 200
        assert toggle_on.json()["isFavorite"] is True

        get_fav = await async_client.get(
            f"/api/services/extra-favorites/{username}",
            headers={"Authorization": f"Bearer {client_token}"},
        )
        assert get_fav.status_code == 200
        assert "s4" in get_fav.json()

        toggle_off = await async_client.post(
            "/api/services/extra-favorites/toggle",
            headers={"Authorization": f"Bearer {client_token}"},
            json={"username": username, "serviceId": "s4"},
        )
        assert toggle_off.status_code == 200
        assert toggle_off.json()["isFavorite"] is False

    @pytest.mark.asyncio
    async def test_favorites_forbidden_other_user(self, async_client, client_token):
        response = await async_client.get(
            "/api/services/favorites/other_user",
            headers={"Authorization": f"Bearer {client_token}"},
        )
        assert response.status_code == 403
