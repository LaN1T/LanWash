from datetime import datetime, time, timedelta

import pytest


class TestAppointments:
    """Тесты жизненного цикла записей на мойку."""

    async def _create_appointment(
        self,
        async_client,
        token,
        appt_id,
        date_time,
        status="scheduled",
        owner="client_test",
    ):
        """Хелпер для создания записи."""
        from tests.helpers import set_next_uuid, clear_next_uuid

        set_next_uuid(appt_id)
        try:
            resp = await async_client.post(
                "/api/appointments/",
                headers={
                    "Authorization": f"Bearer {token}",
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
                    "assignedWasher": "[]",
                    "promoId": None,
                    "box_index": 0,
                },
            )
        finally:
            clear_next_uuid()
        return resp

    @pytest.mark.asyncio
    async def test_create_appointment(self, async_client, client_token):
        resp = await self._create_appointment(
            async_client, client_token, "appt_1", "2099-05-01T10:00:00"
        )
        assert resp.status_code == 200
        data = resp.json()
        assert data["clientName"] == "Тест Клиент"
        assert data["status"] == "scheduled"
        assert data["ownerUsername"] == "client_test"
        assert "box_index" in data

    @pytest.mark.asyncio
    async def test_create_appointment_forbidden_other_owner(
        self, async_client, client_token
    ):
        resp = await self._create_appointment(
            async_client,
            client_token,
            "appt_2",
            "2099-05-02T11:00:00",
            owner="other_user",
        )
        assert resp.status_code == 403

    @pytest.mark.asyncio
    async def test_get_all_appointments_admin(
        self, async_client, admin_token, client_token
    ):
        await self._create_appointment(
            async_client, client_token, "appt_3", "2099-06-01T09:00:00"
        )
        response = await async_client.get(
            "/api/appointments/",
            headers={"Authorization": f"Bearer {admin_token}"},
        )
        assert response.status_code == 200
        data = response.json()
        assert isinstance(data, list)
        # Проверяем заголовки пагинации
        assert "X-Total-Pages" in response.headers
        assert "X-Current-Page" in response.headers

    @pytest.mark.asyncio
    async def test_get_appointments_by_owner(self, async_client, client_token):
        await self._create_appointment(
            async_client, client_token, "appt_4", "2099-07-01T10:00:00"
        )
        response = await async_client.get(
            "/api/appointments/by-owner/client_test",
            headers={"Authorization": f"Bearer {client_token}"},
        )
        assert response.status_code == 200
        data = response.json()
        assert isinstance(data, list)
        assert any(a["id"] == "appt_4" for a in data)

    @pytest.mark.asyncio
    async def test_get_my_appointments(self, async_client, client_token):
        await self._create_appointment(
            async_client, client_token, "appt_4_me", "2099-07-02T10:00:00"
        )
        response = await async_client.get(
            "/api/appointments/by-owner/me",
            headers={"Authorization": f"Bearer {client_token}"},
        )
        assert response.status_code == 200
        data = response.json()
        assert isinstance(data, list)
        assert any(a["id"] == "appt_4_me" for a in data)

    @pytest.mark.asyncio
    async def test_get_my_appointments_status_filter(
        self, async_client, client_token
    ):
        await self._create_appointment(
            async_client, client_token, "appt_me_scheduled", "2099-07-03T10:00:00"
        )
        response = await async_client.get(
            "/api/appointments/by-owner/me?status=completed",
            headers={"Authorization": f"Bearer {client_token}"},
        )
        assert response.status_code == 200
        data = response.json()
        assert isinstance(data, list)
        assert not any(a["id"] == "appt_me_scheduled" for a in data)

    @pytest.mark.asyncio
    async def test_get_my_appointments_status_filter_scheduled(
        self, async_client, client_token
    ):
        await self._create_appointment(
            async_client, client_token, "appt_me_scheduled_pos", "2099-07-04T10:00:00"
        )
        response = await async_client.get(
            "/api/appointments/by-owner/me?status=scheduled",
            headers={"Authorization": f"Bearer {client_token}"},
        )
        assert response.status_code == 200
        data = response.json()
        assert isinstance(data, list)
        assert any(a["id"] == "appt_me_scheduled_pos" for a in data)

    @pytest.mark.asyncio
    async def test_get_my_appointments_invalid_status(
        self, async_client, client_token
    ):
        response = await async_client.get(
            "/api/appointments/by-owner/me?status=unknown",
            headers={"Authorization": f"Bearer {client_token}"},
        )
        assert response.status_code == 400

    @pytest.mark.asyncio
    async def test_get_appointments_by_owner_forbidden(
        self, async_client, client_token
    ):
        response = await async_client.get(
            "/api/appointments/by-owner/other_user",
            headers={"Authorization": f"Bearer {client_token}"},
        )
        assert response.status_code == 403

    @pytest.mark.asyncio
    async def test_get_appointment_by_id_owner(self, async_client, client_token):
        await self._create_appointment(
            async_client, client_token, "appt_detail_owner", "2099-07-05T10:00:00"
        )
        response = await async_client.get(
            "/api/appointments/appt_detail_owner",
            headers={"Authorization": f"Bearer {client_token}"},
        )
        assert response.status_code == 200
        data = response.json()
        assert data["id"] == "appt_detail_owner"

    @pytest.mark.asyncio
    async def test_get_appointment_by_id_admin(
        self, async_client, admin_token, client_token
    ):
        await self._create_appointment(
            async_client, client_token, "appt_detail_admin", "2099-07-06T10:00:00"
        )
        response = await async_client.get(
            "/api/appointments/appt_detail_admin",
            headers={"Authorization": f"Bearer {admin_token}"},
        )
        assert response.status_code == 200
        data = response.json()
        assert data["id"] == "appt_detail_admin"

    @pytest.mark.asyncio
    async def test_get_appointment_by_id_forbidden(
        self, async_client, client_token, admin_token
    ):
        # A client should not be able to view another user's appointment.
        await async_client.post(
            "/api/auth/register",
            json={
                "username": "other_user",
                "password": "TestPass123!",
                "displayName": "Other User",
            },
        )
        await self._create_appointment(
            async_client,
            admin_token,
            "appt_other_detail",
            "2099-07-07T10:00:00",
            owner="other_user",
        )
        response = await async_client.get(
            "/api/appointments/appt_other_detail",
            headers={"Authorization": f"Bearer {client_token}"},
        )
        assert response.status_code == 403

    @pytest.mark.asyncio
    async def test_update_appointment_client_restricted(
        self, async_client, client_token
    ):
        create_resp = await self._create_appointment(
            async_client, client_token, "appt_5", "2099-08-01T10:00:00"
        )
        assert create_resp.status_code == 200
        original = create_resp.json()

        update_resp = await async_client.put(
            "/api/appointments/appt_5",
            headers={"Authorization": f"Bearer {client_token}"},
            json={
                "id": "appt_5",
                "clientName": "Тест Клиент",
                "carModel": "Honda Civic",
                "carNumber": "В777ВВ77",
                "dateTime": "2099-08-01T11:00:00",
                "washTypeId": "w1",
                "additionalServices": "[]",
                "status": "completed",
                "notes": "Обновлённые заметки",
                "isFavorite": False,
                "ownerUsername": "client_test",
                "promoPrice": 0,
                "paidPrice": 1500,
                "isModifiedByAdmin": False,
                "isModifiedByWasher": False,
                "isSeenByClient": True,
                "originalPrice": 1500,
                "assignedWasher": "[]",
                "promoId": None,
                "box_index": 0,
            },
        )
        assert update_resp.status_code == 200
        data = update_resp.json()
        # Allowed fields are updated
        assert data["carModel"] == "Honda Civic"
        assert data["carNumber"] == "В777ВВ77"
        assert data["notes"] == "Обновлённые заметки"
        # Privileged fields are ignored for clients
        assert data["status"] == original["status"]
        assert data["paidPrice"] == original["paidPrice"]
        assert data["originalPrice"] == original["originalPrice"]
        assert data["dateTime"] == original["dateTime"]
        assert data["box_index"] == original["box_index"]

    @pytest.mark.asyncio
    async def test_delete_appointment_owner(self, async_client, client_token):
        await self._create_appointment(
            async_client, client_token, "appt_6", "2099-09-01T10:00:00"
        )
        response = await async_client.delete(
            "/api/appointments/appt_6",
            headers={"Authorization": f"Bearer {client_token}"},
        )
        assert response.status_code == 200
        assert response.json()["ok"] is True

    @pytest.mark.asyncio
    async def test_delete_appointment_forbidden(
        self, async_client, client_token, admin_token
    ):
        await async_client.post(
            "/api/auth/register",
            json={
                "username": "other_user_delete",
                "password": "TestPass123!",
                "displayName": "Other User Delete",
            },
        )
        await self._create_appointment(
            async_client,
            admin_token,
            "appt_other_delete",
            "2099-09-02T10:00:00",
            owner="other_user_delete",
        )
        response = await async_client.delete(
            "/api/appointments/appt_other_delete",
            headers={"Authorization": f"Bearer {client_token}"},
        )
        assert response.status_code == 403

    @pytest.mark.asyncio
    async def test_toggle_favorite(self, async_client, client_token):
        await self._create_appointment(
            async_client, client_token, "appt_7", "2099-10-01T10:00:00"
        )
        response = await async_client.post(
            "/api/appointments/appt_7/toggle-favorite",
            headers={"Authorization": f"Bearer {client_token}"},
        )
        assert response.status_code == 200
        assert response.json()["ok"] is True

    @pytest.mark.asyncio
    async def test_assign_washer_admin(self, async_client, admin_token, washer_token):
        await self._create_appointment(
            async_client, admin_token, "appt_8", "2099-11-01T10:00:00"
        )
        response = await async_client.post(
            "/api/appointments/appt_8/assign-washer",
            headers={"Authorization": f"Bearer {admin_token}"},
            json={"washerUsername": "washer_test"},
        )
        assert response.status_code == 200
        data = response.json()
        assert "washer_test" in data["assignedWasher"]

    @pytest.mark.asyncio
    async def test_assign_washer_forbidden(self, async_client, client_token):
        response = await async_client.post(
            "/api/appointments/nonexistent/assign-washer",
            headers={"Authorization": f"Bearer {client_token}"},
            json={"washerUsername": "washer_test"},
        )
        assert response.status_code == 403

    @pytest.mark.asyncio
    async def test_stats_admin(self, async_client, admin_token, client_token):
        await self._create_appointment(
            async_client,
            client_token,
            "appt_9",
            "2099-12-01T10:00:00",
            status="completed",
        )
        response = await async_client.get(
            "/api/appointments/stats",
            headers={"Authorization": f"Bearer {admin_token}"},
        )
        assert response.status_code == 200
        data = response.json()
        assert "total" in data
        assert "scheduled" in data
        assert "completed" in data

    @pytest.mark.asyncio
    async def test_stats_forbidden(self, async_client, client_token):
        response = await async_client.get(
            "/api/appointments/stats",
            headers={"Authorization": f"Bearer {client_token}"},
        )
        assert response.status_code == 403

    @pytest.mark.asyncio
    async def test_last_updated(self, async_client, client_token):
        response = await async_client.get(
            "/api/appointments/last-updated",
            headers={"Authorization": f"Bearer {client_token}"},
        )
        assert response.status_code == 200
        data = response.json()
        assert "count" in data
        assert "max_id" in data

    @pytest.mark.asyncio
    async def test_busy_slots(self, async_client, client_token):
        response = await async_client.get(
            "/api/appointments/busy-slots?date=2099-01-01",
            headers={"Authorization": f"Bearer {client_token}"},
        )
        assert response.status_code == 200
        assert isinstance(response.json(), dict)

    @pytest.mark.asyncio
    async def test_clear_admin_flag(self, async_client, client_token):
        await self._create_appointment(
            async_client, client_token, "appt_10", "2099-12-15T10:00:00"
        )
        response = await async_client.post(
            "/api/appointments/appt_10/clear-admin-flag",
            headers={"Authorization": f"Bearer {client_token}"},
        )
        assert response.status_code == 200
        assert response.json()["ok"] is True

    @pytest.mark.asyncio
    async def test_mark_seen(self, async_client, client_token):
        await self._create_appointment(
            async_client, client_token, "appt_11", "2099-12-20T10:00:00"
        )
        response = await async_client.post(
            "/api/appointments/appt_11/mark-seen",
            headers={"Authorization": f"Bearer {client_token}"},
        )
        assert response.status_code == 200
        assert response.json()["ok"] is True

    @pytest.mark.asyncio
    async def test_deleted_notification(self, async_client, client_token):
        # Создаём и удаляем запись
        await self._create_appointment(
            async_client, client_token, "appt_12", "2099-12-25T10:00:00"
        )
        await async_client.delete(
            "/api/appointments/appt_12",
            headers={"Authorization": f"Bearer {client_token}"},
        )

        response = await async_client.get(
            "/api/appointments/deleted-notification/client_test",
            headers={"Authorization": f"Bearer {client_token}"},
        )
        assert response.status_code == 200
        assert response.json()["hasNotification"] is True

        # Очищаем уведомление
        clear_resp = await async_client.delete(
            "/api/appointments/deleted-notification/client_test",
            headers={"Authorization": f"Bearer {client_token}"},
        )
        assert clear_resp.status_code == 200
        assert clear_resp.json()["ok"] is True

        # Проверяем что уведомление ушло
        check_resp = await async_client.get(
            "/api/appointments/deleted-notification/client_test",
            headers={"Authorization": f"Bearer {client_token}"},
        )
        assert check_resp.json()["hasNotification"] is False

    @pytest.mark.asyncio
    async def test_auto_assign_washer_on_create(
        self, async_client, db_session, admin_token
    ):
        """When creating an appointment without washer, auto-assign from shift."""
        from models import Shift, User

        # Create a washer with a confirmed shift for today
        washer = User(
            username="auto_washer",
            passwordHash="fakehash",
            role="washer",
            displayName="Auto Washer",
            createdAt=datetime.now(),
        )
        db_session.add(washer)
        await db_session.commit()
        await db_session.refresh(washer)

        today = datetime.now().date()
        shift = Shift(
            userId=washer.id,
            date=today,
            startTime=time(0, 0),
            endTime=time(23, 59),
            status="confirmed",
            createdBy="admin",
            createdAt=datetime.now(),
            updatedAt=datetime.now(),
        )
        db_session.add(shift)
        await db_session.commit()

        # Create appointment without assignedWasher (midday to avoid date rollover)
        dt = (
            datetime.now()
            .replace(hour=12, minute=0, second=0, microsecond=0)
            .isoformat()
        )
        resp = await async_client.post(
            "/api/appointments/",
            headers={"Authorization": f"Bearer {admin_token}"},
            json={
                "id": "auto_assign_appt",
                "clientName": "Тест Клиент",
                "carModel": "Toyota Camry",
                "carNumber": "А123БВ77",
                "dateTime": dt,
                "washTypeId": "w1",
                "additionalServices": "[]",
                "status": "scheduled",
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
            },
        )
        assert resp.status_code == 200
        data = resp.json()
        assert data["assignedWasher"] == '["auto_washer"]'

    @pytest.mark.asyncio
    async def test_auto_assign_respects_admin_override(
        self, async_client, db_session, admin_token
    ):
        """Admin-specified washer is not overwritten by auto-assign."""
        from models import Shift, User

        washer = User(
            username="auto_washer2",
            passwordHash="fakehash",
            role="washer",
            displayName="Auto Washer 2",
            createdAt=datetime.now(),
        )
        db_session.add(washer)
        await db_session.commit()
        await db_session.refresh(washer)

        today = datetime.now().date()
        shift = Shift(
            userId=washer.id,
            date=today,
            startTime=time(0, 0),
            endTime=time(23, 59),
            status="confirmed",
            createdBy="admin",
            createdAt=datetime.now(),
            updatedAt=datetime.now(),
        )
        db_session.add(shift)
        await db_session.commit()

        dt = (datetime.now() + timedelta(hours=2)).isoformat()
        resp = await async_client.post(
            "/api/appointments/",
            headers={"Authorization": f"Bearer {admin_token}"},
            json={
                "id": "manual_assign_appt",
                "clientName": "Тест Клиент",
                "carModel": "Toyota Camry",
                "carNumber": "А123БВ77",
                "dateTime": dt,
                "washTypeId": "w1",
                "additionalServices": "[]",
                "status": "scheduled",
                "notes": "",
                "isFavorite": False,
                "ownerUsername": "client_test",
                "promoPrice": 0,
                "paidPrice": 1000,
                "isModifiedByAdmin": False,
                "isModifiedByWasher": False,
                "isSeenByClient": True,
                "originalPrice": 1000,
                "assignedWasher": '["washer_test"]',
            },
        )
        assert resp.status_code == 200
        data = resp.json()
        # Admin-specified washer should be preserved
        assert data["assignedWasher"] == '["washer_test"]'

    @pytest.mark.asyncio
    async def test_client_promo_price_is_calculated_and_reported(
        self, async_client, client_token, admin_token
    ):
        """Non-admin booking with a weekend promo must store computed prices
        and show up in reports."""
        from datetime import date as dt_date

        # Pick a future Saturday
        today = dt_date.today()
        days_until_saturday = (5 - today.weekday()) % 7
        saturday = today + timedelta(days=max(1, days_until_saturday))
        date_time = f"{saturday.isoformat()}T10:00:00"

        appt_id = "promo_client_appt"
        from tests.helpers import set_next_uuid, clear_next_uuid

        set_next_uuid(appt_id)
        try:
            resp = await async_client.post(
                "/api/appointments/",
                headers={
                    "Authorization": f"Bearer {client_token}",
                    "X-Request-ID": "test",
                },
                json={
                    "clientName": "Тест Клиент",
                    "carModel": "Toyota Camry",
                    "carNumber": "А123БВ77",
                    "dateTime": date_time,
                    "washTypeId": "w3",
                    "additionalServices": "[]",
                    "status": "scheduled",
                    "notes": "",
                    "isFavorite": False,
                    "ownerUsername": "client_test",
                    "promoPrice": 0,
                    "paidPrice": 0,
                    "isModifiedByAdmin": False,
                    "isModifiedByWasher": False,
                    "isSeenByClient": True,
                    "originalPrice": 0,
                    "assignedWasher": "[]",
                    "promoId": "promo_3",
                },
            )
        finally:
            clear_next_uuid()
        assert resp.status_code == 200, resp.text
        data = resp.json()
        # w3 basePrice=1500, promo_3 -20% -> paidPrice=1200, originalPrice=1500
        assert data["promoId"] == "promo_3"
        assert data["originalPrice"] == 1500
        assert data["promoPrice"] == 1200
        assert data["paidPrice"] == 1200

        # Complete the appointment as admin so it appears in revenue reports
        complete_resp = await async_client.put(
            f"/api/appointments/{appt_id}",
            headers={"Authorization": f"Bearer {admin_token}"},
            json={
                "id": appt_id,
                "clientName": "Тест Клиент",
                "carModel": "Toyota Camry",
                "carNumber": "А123БВ77",
                "dateTime": date_time,
                "washTypeId": "w3",
                "additionalServices": "[]",
                "status": "completed",
                "notes": "",
                "isFavorite": False,
                "ownerUsername": "client_test",
                "promoPrice": data["promoPrice"],
                "paidPrice": data["paidPrice"],
                "isModifiedByAdmin": True,
                "isModifiedByWasher": False,
                "isSeenByClient": True,
                "originalPrice": data["originalPrice"],
                "assignedWasher": "[]",
                "promoId": "promo_3",
            },
        )
        assert complete_resp.status_code == 200

        # Financial report
        fin_resp = await async_client.get(
            "/api/reports/financial/",
            headers={"Authorization": f"Bearer {admin_token}"},
            params={
                "start_date": saturday.isoformat(),
                "end_date": saturday.isoformat(),
            },
        )
        assert fin_resp.status_code == 200
        fin = fin_resp.json()
        assert fin["summary"]["services_total"] == 1500
        assert fin["summary"]["discounts_total"] == 300
        assert fin["summary"]["revenue"] == 1200

        # Promo effectiveness report
        promo_resp = await async_client.get(
            "/api/reports/promo-effectiveness/",
            headers={"Authorization": f"Bearer {admin_token}"},
            params={
                "start_date": saturday.isoformat(),
                "end_date": saturday.isoformat(),
            },
        )
        assert promo_resp.status_code == 200
        promo_items = promo_resp.json()["items"]
        promo_item = next((i for i in promo_items if i["promo_id"] == "promo_3"), None)
        assert promo_item is not None
        assert promo_item["uses_count"] == 1
        assert promo_item["revenue"] == 1200
        assert promo_item["discount_total"] == 300

    @pytest.mark.asyncio
    async def test_cancel_with_reason_success(self, async_client, client_token):
        await self._create_appointment(
            async_client, client_token, "appt_cancel_reason", "2099-05-10T10:00:00"
        )
        resp = await async_client.post(
            "/api/appointments/appt_cancel_reason/cancel-reason",
            headers={"Authorization": f"Bearer {client_token}"},
            json={"reason": "Не могу приехать"},
        )
        assert resp.status_code == 200
        data = resp.json()
        assert data["status"] == "cancelled"
        assert data["cancel_reason"] == "Не могу приехать"

    @pytest.mark.asyncio
    async def test_cancel_with_reason_forbidden(
        self, async_client, washer_token, client_token
    ):
        await self._create_appointment(
            async_client, client_token, "appt_cancel_forbidden", "2099-05-11T10:00:00"
        )
        resp = await async_client.post(
            "/api/appointments/appt_cancel_forbidden/cancel-reason",
            headers={"Authorization": f"Bearer {washer_token}"},
            json={"reason": "Не могу приехать"},
        )
        assert resp.status_code == 403

    @pytest.mark.asyncio
    async def test_cancel_with_reason_wrong_status(
        self, async_client, client_token, admin_token
    ):
        await self._create_appointment(
            async_client, client_token, "appt_cancel_wrong", "2099-05-12T10:00:00"
        )
        await async_client.put(
            "/api/appointments/appt_cancel_wrong",
            headers={"Authorization": f"Bearer {admin_token}"},
            json={
                "id": "appt_cancel_wrong",
                "clientName": "Тест Клиент",
                "carModel": "Toyota Camry",
                "carNumber": "А123БВ77",
                "dateTime": "2099-05-12T10:00:00",
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
            "/api/appointments/appt_cancel_wrong/cancel-reason",
            headers={"Authorization": f"Bearer {client_token}"},
            json={"reason": "Не могу приехать"},
        )
        assert resp.status_code == 400

    @pytest.mark.asyncio
    async def test_cancel_with_reason_validation(
        self, async_client, client_token
    ):
        await self._create_appointment(
            async_client, client_token, "appt_cancel_validation", "2099-05-13T10:00:00"
        )
        resp = await async_client.post(
            "/api/appointments/appt_cancel_validation/cancel-reason",
            headers={"Authorization": f"Bearer {client_token}"},
            json={"reason": ""},
        )
        assert resp.status_code == 422

    @pytest.mark.asyncio
    async def test_report_late_success(self, async_client, client_token):
        await self._create_appointment(
            async_client, client_token, "appt_late_success", "2099-05-14T10:00:00"
        )
        resp = await async_client.post(
            "/api/appointments/appt_late_success/late",
            headers={"Authorization": f"Bearer {client_token}"},
            json={"minutes": 15},
        )
        assert resp.status_code == 200
        data = resp.json()
        assert data["late_minutes"] == 15

    @pytest.mark.asyncio
    async def test_report_late_forbidden(
        self, async_client, admin_token, client_token
    ):
        await self._create_appointment(
            async_client, client_token, "appt_late_forbidden", "2099-05-15T10:00:00"
        )
        resp = await async_client.post(
            "/api/appointments/appt_late_forbidden/late",
            headers={"Authorization": f"Bearer {admin_token}"},
            json={"minutes": 15},
        )
        assert resp.status_code == 403

    @pytest.mark.asyncio
    async def test_report_late_wrong_status(
        self, async_client, client_token, admin_token
    ):
        await self._create_appointment(
            async_client, client_token, "appt_late_wrong", "2099-05-16T10:00:00"
        )
        await async_client.put(
            "/api/appointments/appt_late_wrong",
            headers={"Authorization": f"Bearer {admin_token}"},
            json={
                "id": "appt_late_wrong",
                "clientName": "Тест Клиент",
                "carModel": "Toyota Camry",
                "carNumber": "А123БВ77",
                "dateTime": "2099-05-16T10:00:00",
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
            "/api/appointments/appt_late_wrong/late",
            headers={"Authorization": f"Bearer {client_token}"},
            json={"minutes": 15},
        )
        assert resp.status_code == 400

    @pytest.mark.asyncio
    async def test_report_late_validation(self, async_client, client_token):
        await self._create_appointment(
            async_client, client_token, "appt_late_validation", "2099-05-17T10:00:00"
        )
        resp = await async_client.post(
            "/api/appointments/appt_late_validation/late",
            headers={"Authorization": f"Bearer {client_token}"},
            json={"minutes": 10},
        )
        assert resp.status_code == 422
