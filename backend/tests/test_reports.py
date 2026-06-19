import pytest


class TestReports:
    """Тесты отчётов (admin only)."""

    async def _create_completed_appointment(
        self, async_client, token, appt_id, date_time, paid_price=1000
    ):
        """Хелпер для создания завершённой записи."""
        resp = await async_client.post(
            "/api/appointments/",
            headers={"Authorization": f"Bearer {token}"},
            json={
                "id": appt_id,
                "clientName": "Тест Клиент",
                "carModel": "Toyota Camry",
                "carNumber": "А123БВ77",
                "dateTime": date_time,
                "washTypeId": "w1",
                "additionalServices": "[]",
                "status": "completed",
                "notes": "",
                "isFavorite": False,
                "ownerUsername": "client_test",
                "promoPrice": 0,
                "paidPrice": paid_price,
                "isModifiedByAdmin": False,
                "isModifiedByWasher": False,
                "isSeenByClient": True,
                "originalPrice": paid_price,
                "assignedWasher": "[]",
                "promoId": None,
                "box_index": 0,
            },
        )
        return resp

    @pytest.mark.asyncio
    async def test_monthly_report(self, async_client, admin_token, client_token):
        # Создаём завершённую запись в январе 2099
        await self._create_completed_appointment(
            async_client, admin_token, "rep_appt_1", "2099-01-15T10:00:00", 1500
        )

        response = await async_client.get(
            "/api/reports/monthly-check-vs-price/?date=2099-01",
            headers={"Authorization": f"Bearer {admin_token}"},
        )
        assert response.status_code == 200
        data = response.json()
        assert data["date"] == "2099-01"
        assert len(data["data"]) >= 1
        # Проверяем структуру
        row = data["data"][0]
        assert "carModel" in row
        assert "avgCheck" in row
        assert "visitCount" in row
        assert "avgCarPrice" not in row

    @pytest.mark.asyncio
    async def test_popular_services_report(
        self, async_client, admin_token, client_token
    ):
        await self._create_completed_appointment(
            async_client, admin_token, "rep_appt_2", "2099-02-10T14:00:00", 2000
        )

        response = await async_client.get(
            "/api/reports/popular-additional-services/?date=2099-02",
            headers={"Authorization": f"Bearer {admin_token}"},
        )
        assert response.status_code == 200
        data = response.json()
        assert data["date"] == "2099-02"
        assert isinstance(data["data"], list)

    @pytest.mark.asyncio
    async def test_consumables_usage_report(
        self, async_client, admin_token, client_token
    ):
        # Создаём запись с типом мойки w1 (express) — расходуется шампунь
        await self._create_completed_appointment(
            async_client, admin_token, "rep_appt_3", "2099-03-05T09:00:00", 500
        )

        response = await async_client.get(
            "/api/reports/consumables-usage/?date=2099-03",
            headers={"Authorization": f"Bearer {admin_token}"},
        )
        assert response.status_code == 200
        data = response.json()
        assert data["date"] == "2099-03"
        # Должен быть расход шампуня для w1
        names = [item["consumableName"] for item in data["data"]]
        assert "Автошампунь" in names

    @pytest.mark.asyncio
    async def test_reports_forbidden(self, async_client, client_token):
        response = await async_client.get(
            "/api/reports/monthly-check-vs-price/",
            headers={"Authorization": f"Bearer {client_token}"},
        )
        assert response.status_code == 403
