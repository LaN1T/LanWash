import pytest


class TestByWasher:
    @pytest.mark.asyncio
    async def test_get_appointments_by_washer(
        self, async_client, admin_token, client_token, washer_token
    ):
        from datetime import datetime

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
