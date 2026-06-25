import pytest


class TestByWasher:
    @pytest.mark.asyncio
    async def test_get_appointments_by_washer(
        self, async_client, admin_token, client_token, washer_token
    ):
        # Client creates an appointment
        resp = await async_client.post(
            "/api/appointments/",
            headers={"Authorization": f"Bearer {client_token}"},
            json={
                "id": "appt_by_washer_1",
                "clientName": "Тест Клиент",
                "carModel": "Toyota Camry",
                "carNumber": "А123БВ77",
                "dateTime": "2099-05-01T10:00:00",
                "washTypeId": "w1",
                "additionalServices": "[]",
                "status": "scheduled",
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
        assert resp.status_code == 200

        # Admin assigns washer
        resp = await async_client.post(
            "/api/appointments/appt_by_washer_1/assign-washer",
            headers={"Authorization": f"Bearer {admin_token}"},
            json={"washerUsername": "washer_test"},
        )
        assert resp.status_code == 200

        # Washer fetches by-washer endpoint
        resp = await async_client.get(
            "/api/appointments/by-washer/washer_test",
            headers={"Authorization": f"Bearer {washer_token}"},
        )
        print("by-washer status:", resp.status_code)
        print("by-washer body:", resp.text[:500])
        assert resp.status_code == 200
        data = resp.json()
        assert any(a["id"] == "appt_by_washer_1" for a in data)

    @pytest.mark.asyncio
    async def test_get_appointments_by_washer_via_shift(
        self, async_client, admin_token, client_token, washer_token
    ):
        # Find the test washer id
        washers_resp = await async_client.get(
            "/api/auth/washers",
            headers={"Authorization": f"Bearer {admin_token}"},
        )
        assert washers_resp.status_code == 200
        washer_user = next(
            (w for w in washers_resp.json() if w["username"] == "washer_test"), None
        )
        assert washer_user is not None
        washer_id = washer_user["id"]

        # Admin creates a confirmed shift for the washer
        shift_resp = await async_client.post(
            "/api/shifts/",
            headers={"Authorization": f"Bearer {admin_token}"},
            json={
                "userId": washer_id,
                "date": "2099-06-15",
                "startTime": "08:00",
                "endTime": "18:00",
            },
        )
        assert shift_resp.status_code == 201

        # Client creates an appointment inside the shift, no explicit washer assignment
        appt_resp = await async_client.post(
            "/api/appointments/",
            headers={"Authorization": f"Bearer {client_token}"},
            json={
                "id": "appt_by_shift_1",
                "clientName": "Тест Клиент",
                "carModel": "Toyota Camry",
                "carNumber": "А123БВ77",
                "dateTime": "2099-06-15T10:00:00",
                "washTypeId": "w1",
                "additionalServices": "[]",
                "status": "scheduled",
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
        assert appt_resp.status_code == 200

        # Washer fetches by-washer endpoint
        resp = await async_client.get(
            "/api/appointments/by-washer/washer_test",
            headers={"Authorization": f"Bearer {washer_token}"},
        )
        print("by-washer status:", resp.status_code)
        print("by-washer body:", resp.text[:500])
        assert resp.status_code == 200
        data = resp.json()
        assert any(a["id"] == "appt_by_shift_1" for a in data)

    @pytest.mark.asyncio
    async def test_get_appointments_by_washer_includes_own_bookings(
        self, async_client, washer_token
    ):
        # Washer creates an appointment themselves
        resp = await async_client.post(
            "/api/appointments/",
            headers={"Authorization": f"Bearer {washer_token}"},
            json={
                "id": "appt_washer_own_1",
                "clientName": "Самозапись",
                "carModel": "Kia Rio",
                "carNumber": "О777ОО77",
                "dateTime": "2099-07-01T12:00:00",
                "washTypeId": "w1",
                "additionalServices": "[]",
                "status": "scheduled",
                "notes": "",
                "isFavorite": False,
                "ownerUsername": "washer_test",
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
        assert resp.status_code == 200

        # Washer fetches by-washer endpoint
        resp = await async_client.get(
            "/api/appointments/by-washer/washer_test",
            headers={"Authorization": f"Bearer {washer_token}"},
        )
        assert resp.status_code == 200
        data = resp.json()
        assert any(a["id"] == "appt_washer_own_1" for a in data)
