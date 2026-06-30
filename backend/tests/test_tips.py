from datetime import datetime

import pytest


class TestTips:
    """Тесты чаевых для мойщиков."""

    async def _create_appointment_as_admin(
        self,
        async_client,
        admin_token,
        appt_id,
        date_time,
        status="completed",
        owner="client_test",
        assigned_washer='["washer_test"]',
    ):
        """Хелпер для создания записи от имени админа с нужными параметрами."""
        from tests.helpers import set_next_uuid, clear_next_uuid

        set_next_uuid(appt_id)
        try:
            resp = await async_client.post(
                "/api/appointments/",
                headers={
                    "Authorization": f"Bearer {admin_token}",
                    "X-Request-ID": "test",
                },
                json={
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
                    "assignedWasher": assigned_washer,
                    "promoId": None,
                    "box_index": 0,
                },
            )
        finally:
            clear_next_uuid()
        return resp

    @pytest.mark.asyncio
    async def test_create_tip_for_completed_appointment(
        self, async_client, client_token, admin_token
    ):
        appt_resp = await self._create_appointment_as_admin(
            async_client,
            admin_token,
            "appt_tip_1",
            "2099-05-01T10:00:00",
            status="completed",
            owner="client_test",
            assigned_washer='["washer_test"]',
        )
        assert appt_resp.status_code == 200

        resp = await async_client.post(
            "/api/tips/",
            headers={"Authorization": f"Bearer {client_token}"},
            json={
                "appointmentId": "appt_tip_1",
                "amount": 100,
                "method": "sbp",
            },
        )
        assert resp.status_code == 200
        data = resp.json()
        assert data["amount"] == 100
        assert data["method"] == "sbp"
        assert data["status"] == "pending"
        assert data["washerUsername"] == "washer_test"
        assert data.get("sbpUrl") is not None

    @pytest.mark.asyncio
    async def test_create_tip_for_non_completed_appointment(
        self, async_client, client_token, admin_token
    ):
        appt_resp = await self._create_appointment_as_admin(
            async_client,
            admin_token,
            "appt_tip_2",
            "2099-05-02T10:00:00",
            status="scheduled",
            owner="client_test",
            assigned_washer='["washer_test"]',
        )
        assert appt_resp.status_code == 200

        resp = await async_client.post(
            "/api/tips/",
            headers={"Authorization": f"Bearer {client_token}"},
            json={
                "appointmentId": "appt_tip_2",
                "amount": 100,
                "method": "cash",
            },
        )
        assert resp.status_code == 400
        assert "только за завершённую мойку" in resp.json()["detail"]

    @pytest.mark.asyncio
    async def test_create_tip_for_other_user_appointment(
        self, async_client, client_token, admin_token, db_session
    ):
        from models import User
        from services.auth_service import get_password_hash

        other_user = User(
            username="other_client_tip",
            passwordHash=get_password_hash("TestPass123!"),
            role="client",
            displayName="Other Client",
            createdAt=datetime(2099, 1, 1, 0, 0),
        )
        db_session.add(other_user)
        await db_session.commit()
        await db_session.refresh(other_user)

        login_resp = await async_client.post(
            "/api/auth/login",
            json={
                "username": "other_client_tip",
                "password": "TestPass123!",
            },
        )
        assert login_resp.status_code == 200

        appt_resp = await self._create_appointment_as_admin(
            async_client,
            admin_token,
            "appt_tip_3",
            "2099-05-03T10:00:00",
            status="completed",
            owner="other_client_tip",
            assigned_washer='["washer_test"]',
        )
        assert appt_resp.status_code == 200

        resp = await async_client.post(
            "/api/tips/",
            headers={"Authorization": f"Bearer {client_token}"},
            json={
                "appointmentId": "appt_tip_3",
                "amount": 100,
                "method": "app",
            },
        )
        assert resp.status_code == 403
        assert "чужую запись" in resp.json()["detail"]

    @pytest.mark.asyncio
    async def test_create_tip_no_washer(self, async_client, client_token, admin_token):
        appt_resp = await self._create_appointment_as_admin(
            async_client,
            admin_token,
            "appt_tip_4",
            "2099-05-04T10:00:00",
            status="completed",
            owner="client_test",
            assigned_washer="[]",
        )
        assert appt_resp.status_code == 200

        resp = await async_client.post(
            "/api/tips/",
            headers={"Authorization": f"Bearer {client_token}"},
            json={
                "appointmentId": "appt_tip_4",
                "amount": 100,
                "method": "cash",
            },
        )
        assert resp.status_code == 400
        assert "не назначен мойщик" in resp.json()["detail"]

    @pytest.mark.asyncio
    async def test_washer_lists_tips(
        self, async_client, client_token, washer_token, admin_token
    ):
        appt_resp = await self._create_appointment_as_admin(
            async_client,
            admin_token,
            "appt_tip_5",
            "2099-05-05T10:00:00",
            status="completed",
            owner="client_test",
            assigned_washer='["washer_test"]',
        )
        assert appt_resp.status_code == 200

        create_resp = await async_client.post(
            "/api/tips/",
            headers={"Authorization": f"Bearer {client_token}"},
            json={
                "appointmentId": "appt_tip_5",
                "amount": 200,
                "method": "cash",
            },
        )
        assert create_resp.status_code == 200

        my_resp = await async_client.get(
            "/api/tips/my",
            headers={"Authorization": f"Bearer {washer_token}"},
        )
        assert my_resp.status_code == 200
        data = my_resp.json()
        assert isinstance(data, list)
        assert any(t["amount"] == 200 for t in data)

    @pytest.mark.asyncio
    async def test_mark_tip_paid(
        self, async_client, client_token, washer_token, admin_token
    ):
        appt_resp = await self._create_appointment_as_admin(
            async_client,
            admin_token,
            "appt_tip_6",
            "2099-05-06T10:00:00",
            status="completed",
            owner="client_test",
            assigned_washer='["washer_test"]',
        )
        assert appt_resp.status_code == 200

        create_resp = await async_client.post(
            "/api/tips/",
            headers={"Authorization": f"Bearer {client_token}"},
            json={
                "appointmentId": "appt_tip_6",
                "amount": 300,
                "method": "cash",
            },
        )
        assert create_resp.status_code == 200
        tip_id = create_resp.json()["id"]

        mark_resp = await async_client.post(
            f"/api/tips/{tip_id}/mark-paid",
            headers={"Authorization": f"Bearer {washer_token}"},
        )
        assert mark_resp.status_code == 200
        assert mark_resp.json()["status"] == "paid"

    @pytest.mark.asyncio
    async def test_mark_tip_paid_by_non_owner(
        self, async_client, client_token, washer_token, other_washer_token, admin_token
    ):
        appt_resp = await self._create_appointment_as_admin(
            async_client,
            admin_token,
            "appt_tip_7",
            "2099-05-07T10:00:00",
            status="completed",
            owner="client_test",
            assigned_washer='["washer_test"]',
        )
        assert appt_resp.status_code == 200

        create_resp = await async_client.post(
            "/api/tips/",
            headers={"Authorization": f"Bearer {client_token}"},
            json={
                "appointmentId": "appt_tip_7",
                "amount": 400,
                "method": "app",
            },
        )
        assert create_resp.status_code == 200
        tip_id = create_resp.json()["id"]

        mark_resp = await async_client.post(
            f"/api/tips/{tip_id}/mark-paid",
            headers={"Authorization": f"Bearer {other_washer_token}"},
        )
        assert mark_resp.status_code == 403
        assert "Нет прав" in mark_resp.json()["detail"]

    @pytest.mark.asyncio
    async def test_create_duplicate_tip(self, async_client, client_token, admin_token):
        appt_resp = await self._create_appointment_as_admin(
            async_client,
            admin_token,
            "appt_tip_8",
            "2099-05-08T10:00:00",
            status="completed",
            owner="client_test",
            assigned_washer='["washer_test"]',
        )
        assert appt_resp.status_code == 200

        resp1 = await async_client.post(
            "/api/tips/",
            headers={"Authorization": f"Bearer {client_token}"},
            json={
                "appointmentId": "appt_tip_8",
                "amount": 100,
                "method": "sbp",
            },
        )
        assert resp1.status_code == 200

        resp2 = await async_client.post(
            "/api/tips/",
            headers={"Authorization": f"Bearer {client_token}"},
            json={
                "appointmentId": "appt_tip_8",
                "amount": 200,
                "method": "cash",
            },
        )
        assert resp2.status_code == 409
        assert "уже оставлены" in resp2.json()["detail"]

    @pytest.mark.asyncio
    async def test_mark_paid_idempotent(
        self, async_client, client_token, washer_token, admin_token
    ):
        appt_resp = await self._create_appointment_as_admin(
            async_client,
            admin_token,
            "appt_tip_9",
            "2099-05-09T10:00:00",
            status="completed",
            owner="client_test",
            assigned_washer='["washer_test"]',
        )
        assert appt_resp.status_code == 200

        create_resp = await async_client.post(
            "/api/tips/",
            headers={"Authorization": f"Bearer {client_token}"},
            json={
                "appointmentId": "appt_tip_9",
                "amount": 300,
                "method": "cash",
            },
        )
        assert create_resp.status_code == 200
        tip_id = create_resp.json()["id"]

        mark1 = await async_client.post(
            f"/api/tips/{tip_id}/mark-paid",
            headers={"Authorization": f"Bearer {washer_token}"},
        )
        assert mark1.status_code == 200
        assert mark1.json()["status"] == "paid"

        mark2 = await async_client.post(
            f"/api/tips/{tip_id}/mark-paid",
            headers={"Authorization": f"Bearer {washer_token}"},
        )
        assert mark2.status_code == 409
        assert "уже отмечены" in mark2.json()["detail"]

    @pytest.mark.asyncio
    async def test_create_tip_concurrent_race(
        self, async_client, client_token, admin_token, db_session
    ):
        """Симулирует состояние гонки, когда IntegrityError возникает на commit."""
        from sqlalchemy.exc import IntegrityError

        appt_resp = await self._create_appointment_as_admin(
            async_client,
            admin_token,
            "appt_race",
            "2099-05-20T10:00:00",
            status="completed",
            owner="client_test",
            assigned_washer='["washer_test"]',
        )
        assert appt_resp.status_code == 200

        original_commit = db_session.commit

        async def fake_commit():
            raise IntegrityError(
                "insert", {}, Exception("UNIQUE constraint failed: tips.appointmentId")
            )

        db_session.commit = fake_commit
        try:
            resp = await async_client.post(
                "/api/tips/",
                headers={"Authorization": f"Bearer {client_token}"},
                json={
                    "appointmentId": "appt_race",
                    "amount": 100,
                    "method": "cash",
                },
            )
            assert resp.status_code == 409
            assert "уже оставлены" in resp.json()["detail"]
        finally:
            db_session.commit = original_commit

    @pytest.mark.asyncio
    async def test_create_tip_amount_too_high(
        self, async_client, client_token, admin_token
    ):
        appt_resp = await self._create_appointment_as_admin(
            async_client,
            admin_token,
            "appt_tip_10",
            "2099-05-10T10:00:00",
            status="completed",
            owner="client_test",
            assigned_washer='["washer_test"]',
        )
        assert appt_resp.status_code == 200

        resp = await async_client.post(
            "/api/tips/",
            headers={"Authorization": f"Bearer {client_token}"},
            json={
                "appointmentId": "appt_tip_10",
                "amount": 100000,
                "method": "sbp",
            },
        )
        assert resp.status_code == 422

    @pytest.mark.asyncio
    async def test_create_tip_sbp_url_in_response(
        self, async_client, client_token, admin_token
    ):
        appt_resp = await self._create_appointment_as_admin(
            async_client,
            admin_token,
            "appt_tip_11",
            "2099-05-11T10:00:00",
            status="completed",
            owner="client_test",
            assigned_washer='["washer_test"]',
        )
        assert appt_resp.status_code == 200

        resp = await async_client.post(
            "/api/tips/",
            headers={"Authorization": f"Bearer {client_token}"},
            json={
                "appointmentId": "appt_tip_11",
                "amount": 150,
                "method": "sbp",
            },
        )
        assert resp.status_code == 200
        data = resp.json()
        assert "sbpUrl" in data
        assert data["sbpUrl"] is not None
        assert isinstance(data["sbpUrl"], str)
