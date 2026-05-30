import pytest


class TestConsumables:
    """Тесты расходников (admin/washer only)."""

    @pytest.mark.asyncio
    async def test_get_all_consumables(self, async_client, washer_token):
        response = await async_client.get(
            "/api/consumables/",
            headers={"Authorization": f"Bearer {washer_token}"},
        )
        assert response.status_code == 200
        data = response.json()
        assert isinstance(data, list)
        assert len(data) >= 1
        assert "name" in data[0]
        assert "unit" in data[0]

    @pytest.mark.asyncio
    async def test_get_consumable_by_id(self, async_client, washer_token):
        response = await async_client.get(
            "/api/consumables/c_shampoo",
            headers={"Authorization": f"Bearer {washer_token}"},
        )
        assert response.status_code == 200
        data = response.json()
        assert data["id"] == "c_shampoo"
        assert data["name"] == "Автошампунь"

    @pytest.mark.asyncio
    async def test_get_consumable_not_found(self, async_client, washer_token):
        response = await async_client.get(
            "/api/consumables/nonexistent",
            headers={"Authorization": f"Bearer {washer_token}"},
        )
        assert response.status_code == 404

    @pytest.mark.asyncio
    async def test_get_consumables_by_service(self, async_client, washer_token):
        response = await async_client.get(
            "/api/consumables/by-service/s4",
            headers={"Authorization": f"Bearer {washer_token}"},
        )
        assert response.status_code == 200
        data = response.json()
        assert isinstance(data, list)

    @pytest.mark.asyncio
    async def test_create_update_delete_consumable(self, async_client, admin_token):
        # Создание
        create_resp = await async_client.post(
            "/api/consumables/",
            headers={"Authorization": f"Bearer {admin_token}"},
            json={"name": "Тестовый расходник", "unit": "шт"},
        )
        assert create_resp.status_code == 200
        new_id = create_resp.json()["id"]
        assert create_resp.json()["name"] == "Тестовый расходник"

        # Обновление
        update_resp = await async_client.put(
            f"/api/consumables/{new_id}",
            headers={"Authorization": f"Bearer {admin_token}"},
            json={"name": "Обновлённый расходник", "unit": "л"},
        )
        assert update_resp.status_code == 200
        assert update_resp.json()["name"] == "Обновлённый расходник"
        assert update_resp.json()["unit"] == "л"

        # Удаление
        del_resp = await async_client.delete(
            f"/api/consumables/{new_id}",
            headers={"Authorization": f"Bearer {admin_token}"},
        )
        assert del_resp.status_code == 200
        assert del_resp.json()["ok"] is True

    @pytest.mark.asyncio
    async def test_link_unlink_consumable_to_service(self, async_client, admin_token):
        # Связываем существующий расходник с услугой
        link_resp = await async_client.post(
            "/api/consumables/service-link",
            headers={"Authorization": f"Bearer {admin_token}"},
            json={
                "serviceId": "s4",
                "consumableId": "c_shampoo",
                "quantity_per_service": 5.5,
            },
        )
        assert link_resp.status_code == 200
        data = link_resp.json()
        assert data["serviceId"] == "s4"
        assert data["consumableId"] == "c_shampoo"
        assert data["quantity_per_service"] == 5.5

        # Удаляем связь
        unlink_resp = await async_client.delete(
            "/api/consumables/service-link/s4/c_shampoo",
            headers={"Authorization": f"Bearer {admin_token}"},
        )
        assert unlink_resp.status_code == 200
        assert unlink_resp.json()["ok"] is True

    @pytest.mark.asyncio
    async def test_link_consumable_not_found(self, async_client, admin_token):
        response = await async_client.post(
            "/api/consumables/service-link",
            headers={"Authorization": f"Bearer {admin_token}"},
            json={
                "serviceId": "nonexistent",
                "consumableId": "c_shampoo",
                "quantity_per_service": 1.0,
            },
        )
        assert response.status_code == 404

    @pytest.mark.asyncio
    async def test_unlink_not_found(self, async_client, admin_token):
        response = await async_client.delete(
            "/api/consumables/service-link/nonexistent/nonexistent",
            headers={"Authorization": f"Bearer {admin_token}"},
        )
        assert response.status_code == 404

    @pytest.mark.asyncio
    async def test_forbidden_for_client(self, async_client, client_token):
        response = await async_client.get(
            "/api/consumables/",
            headers={"Authorization": f"Bearer {client_token}"},
        )
        assert response.status_code == 403

    @pytest.mark.asyncio
    async def test_refill_and_history(self, async_client, admin_token):
        # Пополнение
        refill_resp = await async_client.post(
            "/api/consumables/c_shampoo/refill",
            headers={"Authorization": f"Bearer {admin_token}"},
            json={"amount": 10.0},
        )
        assert refill_resp.status_code == 200
        data = refill_resp.json()
        assert data["currentStock"] >= 10.0

        # История
        history_resp = await async_client.get(
            "/api/consumables/c_shampoo/refill-history",
            headers={"Authorization": f"Bearer {admin_token}"},
        )
        assert history_resp.status_code == 200
        history = history_resp.json()
        assert isinstance(history, list)
        assert len(history) >= 1
        assert history[0]["amount"] == 10.0
        assert history[0]["refilledBy"] == "admin"

    @pytest.mark.asyncio
    async def test_forecast(self, async_client, admin_token):
        response = await async_client.get(
            "/api/consumables/c_shampoo/forecast",
            headers={"Authorization": f"Bearer {admin_token}"},
        )
        assert response.status_code == 200
        data = response.json()
        assert "currentStock" in data
        assert "avgDailyUsage" in data
        assert "daysLeft" in data
        assert "suggestedPurchase" in data
        assert data["unit"] in ["л", "мл"]
