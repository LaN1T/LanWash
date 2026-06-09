import pytest


class TestLateAndCancel:
    """Тесты опоздания и отмены с причиной."""

    async def _create_appointment(self, async_client, token, appt_id, date_time, status="scheduled", owner="client_test"):
        """Хелпер для создания записи."""
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
                "status": status,
                "notes": "Тестовые заметки",
                "isFavorite": False,
                "ownerUsername": owner,
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
        return resp

    @pytest.mark.asyncio
    async def test_report_late_owner(self, async_client, client_token):
        await self._create_appointment(async_client, client_token, "appt_late_1", "2099-05-01T10:00:00")
        resp = await async_client.post(
            "/api/appointments/appt_late_1/late",
            headers={"Authorization": f"Bearer {client_token}"},
            json={"minutes": 15},
        )
        assert resp.status_code == 200
        data = resp.json()
        assert data["late_minutes"] == 15

    @pytest.mark.asyncio
    async def test_report_late_forbidden_admin(self, async_client, admin_token, client_token):
        await self._create_appointment(async_client, client_token, "appt_late_2", "2099-05-02T10:00:00")
        resp = await async_client.post(
            "/api/appointments/appt_late_2/late",
            headers={"Authorization": f"Bearer {admin_token}"},
            json={"minutes": 15},
        )
        assert resp.status_code == 403

    @pytest.mark.asyncio
    async def test_report_late_wrong_status(self, async_client, client_token, admin_token):
        # Создаём через клиента, затем админ меняет статус на completed
        await self._create_appointment(async_client, client_token, "appt_late_3", "2099-05-03T10:00:00")
        await async_client.put(
            "/api/appointments/appt_late_3",
            headers={"Authorization": f"Bearer {admin_token}"},
            json={
                "id": "appt_late_3",
                "clientName": "Тест Клиент",
                "carModel": "Toyota Camry",
                "carNumber": "А123БВ77",
                "dateTime": "2099-05-03T10:00:00",
                "washTypeId": "w1",
                "additionalServices": "[]",
                "status": "completed",
                "notes": "Тестовые заметки",
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
        resp = await async_client.post(
            "/api/appointments/appt_late_3/late",
            headers={"Authorization": f"Bearer {client_token}"},
            json={"minutes": 15},
        )
        assert resp.status_code == 400

    @pytest.mark.asyncio
    async def test_report_late_invalid_minutes(self, async_client, client_token):
        await self._create_appointment(async_client, client_token, "appt_late_4", "2099-05-04T10:00:00")
        resp = await async_client.post(
            "/api/appointments/appt_late_4/late",
            headers={"Authorization": f"Bearer {client_token}"},
            json={"minutes": 10},
        )
        assert resp.status_code == 422

    @pytest.mark.asyncio
    async def test_cancel_with_reason_owner(self, async_client, client_token):
        await self._create_appointment(async_client, client_token, "appt_cancel_1", "2099-05-05T10:00:00")
        resp = await async_client.post(
            "/api/appointments/appt_cancel_1/cancel-reason",
            headers={"Authorization": f"Bearer {client_token}"},
            json={"reason": "Не могу приехать"},
        )
        assert resp.status_code == 200
        data = resp.json()
        assert data["status"] == "cancelled"
        assert data["cancel_reason"] == "Не могу приехать"

    @pytest.mark.asyncio
    async def test_cancel_with_reason_forbidden(self, async_client, washer_token, client_token):
        await self._create_appointment(async_client, client_token, "appt_cancel_2", "2099-05-06T10:00:00")
        resp = await async_client.post(
            "/api/appointments/appt_cancel_2/cancel-reason",
            headers={"Authorization": f"Bearer {washer_token}"},
            json={"reason": "Не могу приехать"},
        )
        assert resp.status_code == 403

    @pytest.mark.asyncio
    async def test_cancel_with_reason_empty(self, async_client, client_token):
        await self._create_appointment(async_client, client_token, "appt_cancel_3", "2099-05-07T10:00:00")
        resp = await async_client.post(
            "/api/appointments/appt_cancel_3/cancel-reason",
            headers={"Authorization": f"Bearer {client_token}"},
            json={"reason": ""},
        )
        assert resp.status_code == 422
