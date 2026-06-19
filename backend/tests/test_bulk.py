from datetime import datetime

import pytest

from models import Appointment


class TestBulkOperations:
    @pytest.mark.asyncio
    async def test_bulk_assign_washer(self, async_client, db_session, admin_token):
        """Admin can assign washer to multiple appointments."""
        # Create appointments
        for i in range(3):
            appt = Appointment(
                id=f"bulk_appt_{i}",
                clientName=f"Client {i}",
                carModel="Test",
                carNumber="А123БВ777",
                dateTime=datetime.now(),
                washTypeId="w2",
                additionalServices="[]",
                status="scheduled",
                ownerUsername="client_test",
                box_index=1,
            )
            db_session.add(appt)
        await db_session.commit()

        response = await async_client.post(
            "/api/admin/bulk/assign-washer",
            json={
                "appointmentIds": ["bulk_appt_0", "bulk_appt_1", "bulk_appt_2"],
                "washerUsername": "washer_test",
            },
            headers={"Authorization": f"Bearer {admin_token}"},
        )
        assert response.status_code == 200
        data = response.json()
        assert data["processed"] == 3
        assert data["failed"] == 0

    @pytest.mark.asyncio
    async def test_bulk_assign_washer_skips_cancelled(
        self, async_client, db_session, admin_token
    ):
        """Bulk assign skips cancelled appointments."""
        appt = Appointment(
            id="bulk_appt_cancel",
            clientName="Client",
            carModel="Test",
            carNumber="А123БВ777",
            dateTime=datetime.now(),
            washTypeId="w2",
            additionalServices="[]",
            status="cancelled",
            ownerUsername="client_test",
            box_index=1,
        )
        db_session.add(appt)
        await db_session.commit()

        response = await async_client.post(
            "/api/admin/bulk/assign-washer",
            json={
                "appointmentIds": ["bulk_appt_cancel"],
                "washerUsername": "washer_test",
            },
            headers={"Authorization": f"Bearer {admin_token}"},
        )
        assert response.status_code == 200
        data = response.json()
        assert data["processed"] == 0
        assert data["failed"] == 1

    @pytest.mark.asyncio
    async def test_bulk_cancel(self, async_client, db_session, admin_token):
        """Admin can bulk cancel appointments."""
        for i in range(2):
            appt = Appointment(
                id=f"bulk_cancel_{i}",
                clientName=f"Client {i}",
                carModel="Test",
                carNumber="А123БВ777",
                dateTime=datetime.now(),
                washTypeId="w2",
                additionalServices="[]",
                status="scheduled",
                ownerUsername="client_test",
                box_index=1,
            )
            db_session.add(appt)
        await db_session.commit()

        response = await async_client.post(
            "/api/admin/bulk/cancel",
            json={
                "appointmentIds": ["bulk_cancel_0", "bulk_cancel_1"],
                "reason": "Технические работы",
            },
            headers={"Authorization": f"Bearer {admin_token}"},
        )
        assert response.status_code == 200
        data = response.json()
        assert data["processed"] == 2
        assert data["failed"] == 0

    @pytest.mark.asyncio
    async def test_bulk_cancel_skips_completed(
        self, async_client, db_session, admin_token
    ):
        """Bulk cancel skips completed appointments."""
        appt = Appointment(
            id="bulk_cancel_comp",
            clientName="Client",
            carModel="Test",
            carNumber="А123БВ777",
            dateTime=datetime.now(),
            washTypeId="w2",
            additionalServices="[]",
            status="completed",
            ownerUsername="client_test",
            box_index=1,
        )
        db_session.add(appt)
        await db_session.commit()

        response = await async_client.post(
            "/api/admin/bulk/cancel",
            json={
                "appointmentIds": ["bulk_cancel_comp"],
                "reason": "Технические работы",
            },
            headers={"Authorization": f"Bearer {admin_token}"},
        )
        assert response.status_code == 200
        data = response.json()
        assert data["processed"] == 0
        assert data["failed"] == 1

    @pytest.mark.asyncio
    async def test_bulk_update_status(self, async_client, db_session, admin_token):
        """Admin can bulk update status."""
        for i in range(2):
            appt = Appointment(
                id=f"bulk_status_{i}",
                clientName=f"Client {i}",
                carModel="Test",
                carNumber="А123БВ777",
                dateTime=datetime.now(),
                washTypeId="w2",
                additionalServices="[]",
                status="scheduled",
                ownerUsername="client_test",
                box_index=1,
            )
            db_session.add(appt)
        await db_session.commit()

        response = await async_client.post(
            "/api/admin/bulk/update-status",
            json={
                "appointmentIds": ["bulk_status_0", "bulk_status_1"],
                "status": "in_progress",
            },
            headers={"Authorization": f"Bearer {admin_token}"},
        )
        assert response.status_code == 200
        data = response.json()
        assert data["processed"] == 2
        assert data["failed"] == 0

    @pytest.mark.asyncio
    async def test_bulk_forbidden_client(self, async_client, client_token):
        """Client cannot use bulk operations."""
        response = await async_client.post(
            "/api/admin/bulk/cancel",
            json={"appointmentIds": ["a"], "reason": ""},
            headers={"Authorization": f"Bearer {client_token}"},
        )
        assert response.status_code == 403

    @pytest.mark.asyncio
    async def test_bulk_missing_appointments(self, async_client, admin_token):
        """Bulk operations report missing appointments."""
        response = await async_client.post(
            "/api/admin/bulk/update-status",
            json={
                "appointmentIds": ["nonexistent_1", "nonexistent_2"],
                "status": "completed",
            },
            headers={"Authorization": f"Bearer {admin_token}"},
        )
        assert response.status_code == 200
        data = response.json()
        assert data["processed"] == 0
        assert data["failed"] == 1
        assert "nonexistent_1" in data["errors"][0]
