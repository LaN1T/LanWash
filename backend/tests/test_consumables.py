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
    async def test_history_merged(self, async_client, admin_token, client_token):
        # Пополнение
        refill_resp = await async_client.post(
            "/api/consumables/c_shampoo/refill",
            headers={"Authorization": f"Bearer {admin_token}"},
            json={"amount": 10.0},
        )
        assert refill_resp.status_code == 200

        # Создаём завершённую запись, чтобы списать расходник (w1 использует c_shampoo)
        appt_resp = await async_client.post(
            "/api/appointments/",
            headers={"Authorization": f"Bearer {admin_token}"},
            json={
                "id": "appt_history_test",
                "clientName": "История Клиент",
                "carModel": "Toyota Camry",
                "carNumber": "А123БВ77",
                "dateTime": "2099-05-01T10:00:00",
                "washTypeId": "w1",
                "additionalServices": "[]",
                "status": "completed",
                "notes": "",
                "isFavorite": False,
                "ownerUsername": "client_test",
                "promoPrice": 0,
                "paidPrice": 1000,
                "isModifiedByAdmin": False,
                "isModifiedByWasher": False,
                "isSeenByClient": True,
                "originalPrice": 1000,
                "assignedWasher": "[]",
                "promoId": None,
                "box_index": 0,
            },
        )
        assert appt_resp.status_code == 200

        # Объединённая история
        history_resp = await async_client.get(
            "/api/consumables/c_shampoo/history",
            headers={"Authorization": f"Bearer {admin_token}"},
        )
        assert history_resp.status_code == 200
        data = history_resp.json()
        assert "items" in data
        items = data["items"]
        assert len(items) >= 2

        types = [item["type"] for item in items]
        assert "refill" in types
        assert "consumption" in types

        # Сортировка по убыванию timestamp — запись (consumption) позже пополнения
        assert items[0]["type"] == "consumption"
        assert items[0]["appointmentId"] == "appt_history_test"
        assert items[0]["quantity"] == 50.0

        # Проверка полей
        consumption = next(i for i in items if i["type"] == "consumption")
        assert "id" in consumption
        assert "appointmentId" in consumption
        assert "quantity" in consumption
        assert "timestamp" in consumption

        refill = next(i for i in items if i["type"] == "refill")
        assert "id" in refill
        assert refill.get("appointmentId") is None
        assert refill["quantity"] == 10.0

    @pytest.mark.asyncio
    async def test_history_forbidden_for_non_admin(
        self, async_client, client_token, washer_token
    ):
        response = await async_client.get(
            "/api/consumables/c_shampoo/history",
            headers={"Authorization": f"Bearer {client_token}"},
        )
        assert response.status_code == 403

        response = await async_client.get(
            "/api/consumables/c_shampoo/history",
            headers={"Authorization": f"Bearer {washer_token}"},
        )
        assert response.status_code == 403

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

    @pytest.mark.asyncio
    async def test_export_excel(self, async_client, admin_token):
        response = await async_client.get(
            "/api/consumables/export",
            headers={"Authorization": f"Bearer {admin_token}"},
        )
        assert response.status_code == 200
        assert (
            response.headers["content-type"]
            == "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet"
        )
        assert len(response.content) > 100

    @pytest.mark.asyncio
    async def test_import_template(self, async_client, admin_token):
        response = await async_client.get(
            "/api/consumables/import-template",
            headers={"Authorization": f"Bearer {admin_token}"},
        )
        assert response.status_code == 200
        assert (
            response.headers["content-type"]
            == "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet"
        )
        assert len(response.content) > 100

    @pytest.mark.asyncio
    async def test_import_refills(self, async_client, admin_token):
        import io

        from openpyxl import Workbook

        wb = Workbook()
        ws = wb.active
        ws.append(["name", "amount"])
        ws.append(["Автошампунь", 25.0])
        buf = io.BytesIO()
        wb.save(buf)
        buf.seek(0)

        response = await async_client.post(
            "/api/consumables/import-refills",
            headers={"Authorization": f"Bearer {admin_token}"},
            files={
                "file": (
                    "refills.xlsx",
                    buf,
                    "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet",
                )
            },
        )
        assert response.status_code == 200
        data = response.json()
        assert data["succeeded"] >= 1
        assert data["failed"] == 0

    @pytest.mark.asyncio
    async def test_import_refills_invalid(self, async_client, admin_token):
        import io

        from openpyxl import Workbook

        wb = Workbook()
        ws = wb.active
        ws.append(["name", "amount"])
        ws.append(["Несуществующий расходник 12345", 10.0])
        buf = io.BytesIO()
        wb.save(buf)
        buf.seek(0)

        response = await async_client.post(
            "/api/consumables/import-refills",
            headers={"Authorization": f"Bearer {admin_token}"},
            files={
                "file": (
                    "refills.xlsx",
                    buf,
                    "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet",
                )
            },
        )
        assert response.status_code == 200
        data = response.json()
        assert data["failed"] == 1
