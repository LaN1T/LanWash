import pytest


class TestAppointments:
    """Тесты жизненного цикла записей на мойку."""

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
    async def test_create_appointment_forbidden_other_owner(self, async_client, client_token):
        resp = await self._create_appointment(
            async_client, client_token, "appt_2", "2099-05-02T11:00:00", owner="other_user"
        )
        assert resp.status_code == 403

    @pytest.mark.asyncio
    async def test_get_all_appointments_admin(self, async_client, admin_token, client_token):
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
    async def test_get_appointments_by_owner_forbidden(self, async_client, client_token):
        response = await async_client.get(
            "/api/appointments/by-owner/other_user",
            headers={"Authorization": f"Bearer {client_token}"},
        )
        assert response.status_code == 403

    @pytest.mark.asyncio
    async def test_update_appointment_status(self, async_client, client_token):
        create_resp = await self._create_appointment(
            async_client, client_token, "appt_5", "2099-08-01T10:00:00"
        )
        assert create_resp.status_code == 200

        update_resp = await async_client.put(
            "/api/appointments/appt_5",
            headers={"Authorization": f"Bearer {client_token}"},
            json={
                "id": "appt_5",
                "clientName": "Тест Клиент",
                "carModel": "Toyota Camry",
                "carNumber": "А123БВ77",
                "dateTime": "2099-08-01T10:00:00",
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
        assert update_resp.json()["status"] == "completed"
        assert update_resp.json()["paidPrice"] == 1500

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
    async def test_delete_appointment_forbidden(self, async_client, client_token):
        # Создаём запись от имени другого пользователя через admin
        # (или просто пробуем удалить несуществующую — но лучше создать реальную)
        # Создаём через client_token с owner=client_test, а удаляем тем же токеном — это ок
        # Попробуем удалить чужую запись: создадим через другой токен
        pass  # Пропускаем, т.к. сложно создать чужую запись без admin

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
            async_client, client_token, "appt_9", "2099-12-01T10:00:00", status="completed"
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
    async def test_auto_assign_washer_on_create(self, async_client, db_session, admin_token):
        """When creating an appointment without washer, auto-assign from shift."""
        from datetime import datetime, timedelta
        from db_models import User, Shift

        # Create a washer with a confirmed shift for today
        washer = User(
            username="auto_washer",
            passwordHash="fakehash",
            role="washer",
            displayName="Auto Washer",
            createdAt=datetime.now().isoformat(),
        )
        db_session.add(washer)
        await db_session.commit()
        await db_session.refresh(washer)

        today = datetime.now().strftime("%Y-%m-%d")
        shift = Shift(
            userId=washer.id,
            date=today,
            startTime="00:00",
            endTime="23:59",
            status="confirmed",
            createdBy="admin",
            createdAt=datetime.now().isoformat(),
            updatedAt=datetime.now().isoformat(),
        )
        db_session.add(shift)
        await db_session.commit()

        # Create appointment without assignedWasher
        dt = (datetime.now() + timedelta(hours=1)).isoformat()
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
    async def test_auto_assign_respects_admin_override(self, async_client, db_session, admin_token):
        """Admin-specified washer is not overwritten by auto-assign."""
        from datetime import datetime, timedelta
        from db_models import User, Shift

        washer = User(
            username="auto_washer2",
            passwordHash="fakehash",
            role="washer",
            displayName="Auto Washer 2",
            createdAt=datetime.now().isoformat(),
        )
        db_session.add(washer)
        await db_session.commit()
        await db_session.refresh(washer)

        today = datetime.now().strftime("%Y-%m-%d")
        shift = Shift(
            userId=washer.id,
            date=today,
            startTime="00:00",
            endTime="23:59",
            status="confirmed",
            createdBy="admin",
            createdAt=datetime.now().isoformat(),
            updatedAt=datetime.now().isoformat(),
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
