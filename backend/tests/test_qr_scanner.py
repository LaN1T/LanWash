import json

import pytest
from db_models import User
from sqlalchemy import select


class TestQrScanner:
    """Тесты QR-кода и сканера для записей на мойку."""

    async def _create_appointment(
        self,
        async_client,
        token,
        appt_id,
        date_time,
        status="scheduled",
        owner="client_test",
        assigned_washer=None,
    ):
        """Хелпер для создания записи."""
        payload = {
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
            "assignedWasher": json.dumps([assigned_washer])
            if assigned_washer
            else "[]",
            "promoId": None,
            "box_index": 0,
        }
        resp = await async_client.post(
            "/api/appointments/",
            headers={"Authorization": f"Bearer {token}"},
            json=payload,
        )
        return resp

    @pytest.mark.asyncio
    async def test_qr_endpoint_owner(self, async_client, client_token):
        await self._create_appointment(
            async_client, client_token, "qr_appt_1", "2099-05-01T10:00:00"
        )
        resp = await async_client.get(
            "/api/appointments/qr_appt_1/qr",
            headers={"Authorization": f"Bearer {client_token}"},
        )
        assert resp.status_code == 200
        assert resp.json()["qrData"] == "qr_appt_1"

    @pytest.mark.asyncio
    async def test_qr_endpoint_admin(self, async_client, admin_token, client_token):
        await self._create_appointment(
            async_client, client_token, "qr_appt_2", "2099-05-02T10:00:00"
        )
        resp = await async_client.get(
            "/api/appointments/qr_appt_2/qr",
            headers={"Authorization": f"Bearer {admin_token}"},
        )
        assert resp.status_code == 200
        assert resp.json()["qrData"] == "qr_appt_2"

    @pytest.mark.asyncio
    async def test_qr_endpoint_assigned_washer(
        self, async_client, admin_token, washer_token
    ):
        await self._create_appointment(
            async_client,
            admin_token,
            "qr_appt_3",
            "2099-05-03T10:00:00",
            assigned_washer="washer_test",
        )
        resp = await async_client.get(
            "/api/appointments/qr_appt_3/qr",
            headers={"Authorization": f"Bearer {washer_token}"},
        )
        assert resp.status_code == 200
        assert resp.json()["qrData"] == "qr_appt_3"

    @pytest.mark.asyncio
    async def test_qr_endpoint_forbidden_unauthorized(self, async_client, client_token):
        # Создаём запись от имени client_test
        await self._create_appointment(
            async_client, client_token, "qr_appt_4", "2099-05-04T10:00:00"
        )
        # Регистрируем другого клиента
        await async_client.post(
            "/api/auth/register",
            json={
                "username": "other_client",
                "password": "TestPass123!",
                "displayName": "Other Client",
            },
        )
        login_resp = await async_client.post(
            "/api/auth/login",
            json={
                "username": "other_client",
                "password": "TestPass123!",
            },
        )
        other_token = login_resp.json()["access_token"]
        resp = await async_client.get(
            "/api/appointments/qr_appt_4/qr",
            headers={"Authorization": f"Bearer {other_token}"},
        )
        assert resp.status_code == 403

    @pytest.mark.asyncio
    async def test_scan_qr_updates_status(
        self, async_client, admin_token, washer_token, client_token
    ):
        # Только админ может назначать мойщика при создании
        await self._create_appointment(
            async_client,
            admin_token,
            "qr_appt_5",
            "2099-05-05T10:00:00",
            owner="client_test",
            assigned_washer="washer_test",
        )
        resp = await async_client.post(
            "/api/appointments/scan-qr",
            headers={"Authorization": f"Bearer {washer_token}"},
            json={"qrData": "qr_appt_5"},
        )
        assert resp.status_code == 200
        data = resp.json()
        assert data["status"] == "in_progress"
        assert data["id"] == "qr_appt_5"
        assert data["isModifiedByWasher"] == 1
        assert data["isSeenByClient"] == 0

    @pytest.mark.asyncio
    async def test_scan_qr_admin(self, async_client, admin_token, client_token):
        await self._create_appointment(
            async_client,
            admin_token,
            "qr_appt_5a",
            "2099-05-05T11:00:00",
            owner="client_test",
            assigned_washer="washer_test",
        )
        resp = await async_client.post(
            "/api/appointments/scan-qr",
            headers={"Authorization": f"Bearer {admin_token}"},
            json={"qrData": "qr_appt_5a"},
        )
        assert resp.status_code == 200
        data = resp.json()
        assert data["status"] == "in_progress"
        assert data["isModifiedByWasher"] == 1
        assert data["isSeenByClient"] == 0

    @pytest.mark.asyncio
    async def test_scan_qr_forbidden_non_assigned_washer(
        self, async_client, admin_token, other_washer_token
    ):
        await self._create_appointment(
            async_client,
            admin_token,
            "qr_appt_6",
            "2099-05-06T10:00:00",
            owner="client_test",
            assigned_washer="washer_test",
        )
        resp = await async_client.post(
            "/api/appointments/scan-qr",
            headers={"Authorization": f"Bearer {other_washer_token}"},
            json={"qrData": "qr_appt_6"},
        )
        assert resp.status_code == 403

    @pytest.mark.asyncio
    async def test_scan_qr_not_found(self, async_client, washer_token):
        resp = await async_client.post(
            "/api/appointments/scan-qr",
            headers={"Authorization": f"Bearer {washer_token}"},
            json={"qrData": "nonexistent_appt"},
        )
        assert resp.status_code == 404

    @pytest.mark.asyncio
    async def test_scan_qr_wrong_status(
        self, async_client, admin_token, washer_token, client_token
    ):
        await self._create_appointment(
            async_client,
            admin_token,
            "qr_appt_7",
            "2099-05-07T10:00:00",
            status="completed",
            owner="client_test",
            assigned_washer="washer_test",
        )
        resp = await async_client.post(
            "/api/appointments/scan-qr",
            headers={"Authorization": f"Bearer {washer_token}"},
            json={"qrData": "qr_appt_7"},
        )
        assert resp.status_code == 400

    @pytest.mark.asyncio
    async def test_scan_qr_in_progress(
        self, async_client, admin_token, washer_token, client_token
    ):
        await self._create_appointment(
            async_client,
            admin_token,
            "qr_appt_8",
            "2099-05-08T10:00:00",
            status="in_progress",
            owner="client_test",
            assigned_washer="washer_test",
        )
        resp = await async_client.post(
            "/api/appointments/scan-qr",
            headers={"Authorization": f"Bearer {washer_token}"},
            json={"qrData": "qr_appt_8"},
        )
        assert resp.status_code == 400

    @pytest.mark.asyncio
    async def test_scan_qr_cancelled(
        self, async_client, admin_token, washer_token, client_token
    ):
        await self._create_appointment(
            async_client,
            admin_token,
            "qr_appt_9",
            "2099-05-09T10:00:00",
            status="cancelled",
            owner="client_test",
            assigned_washer="washer_test",
        )
        resp = await async_client.post(
            "/api/appointments/scan-qr",
            headers={"Authorization": f"Bearer {washer_token}"},
            json={"qrData": "qr_appt_9"},
        )
        assert resp.status_code == 400

    @pytest.mark.asyncio
    async def test_qr_endpoint_shift_washer(
        self, async_client, admin_token, washer_token, db_session
    ):
        """Мойщик с сменой, покрывающей время записи, может получить QR."""
        await self._create_appointment(
            async_client,
            admin_token,
            "qr_appt_shift",
            "2099-05-10T10:00:00",
            owner="client_test",
            assigned_washer=None,
        )
        result = await db_session.execute(
            select(User).where(User.username == "washer_test")
        )
        washer_user = result.scalar_one()
        shift_resp = await async_client.post(
            "/api/shifts/",
            headers={"Authorization": f"Bearer {admin_token}"},
            json={
                "userId": washer_user.id,
                "date": "2099-05-10",
                "startTime": "09:00",
                "endTime": "11:00",
            },
        )
        assert shift_resp.status_code == 201
        resp = await async_client.get(
            "/api/appointments/qr_appt_shift/qr",
            headers={"Authorization": f"Bearer {washer_token}"},
        )
        assert resp.status_code == 200
        assert resp.json()["qrData"] == "qr_appt_shift"
