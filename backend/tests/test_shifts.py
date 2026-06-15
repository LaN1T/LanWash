from datetime import datetime, timedelta

import pytest
from db_models import Shift, User


class TestShifts:
    @pytest.mark.asyncio
    async def test_create_shift_admin(self, async_client, db_session, admin_token):
        """Admin can create a shift for any washer."""
        # Create a washer
        washer = User(
            username="shift_washer",
            passwordHash="fakehash",
            role="washer",
            displayName="Shift Washer",
            createdAt=datetime.now().isoformat(),
        )
        db_session.add(washer)
        await db_session.commit()
        await db_session.refresh(washer)

        today = datetime.now().strftime("%Y-%m-%d")
        response = await async_client.post(
            "/api/shifts/",
            json={
                "userId": washer.id,
                "date": today,
                "startTime": "09:00",
                "endTime": "18:00",
            },
            headers={"Authorization": f"Bearer {admin_token}"},
        )
        assert response.status_code == 201
        data = response.json()
        assert data["status"] == "confirmed"
        assert data["startTime"] == "09:00"
        assert data["endTime"] == "18:00"

    @pytest.mark.asyncio
    async def test_create_shift_invalid_time_range(
        self, async_client, db_session, admin_token
    ):
        """Start time must be before end time."""
        washer = User(
            username="shift_washer2",
            passwordHash="fakehash",
            role="washer",
            displayName="Shift Washer 2",
            createdAt=datetime.now().isoformat(),
        )
        db_session.add(washer)
        await db_session.commit()
        await db_session.refresh(washer)

        today = datetime.now().strftime("%Y-%m-%d")
        response = await async_client.post(
            "/api/shifts/",
            json={
                "userId": washer.id,
                "date": today,
                "startTime": "18:00",
                "endTime": "09:00",
            },
            headers={"Authorization": f"Bearer {admin_token}"},
        )
        assert response.status_code == 400

    @pytest.mark.asyncio
    async def test_today_shifts(self, async_client, db_session, admin_token):
        """Today endpoint returns confirmed shifts for today."""
        washer = User(
            username="shift_washer3",
            passwordHash="fakehash",
            role="washer",
            displayName="Shift Washer 3",
            createdAt=datetime.now().isoformat(),
        )
        db_session.add(washer)
        await db_session.commit()
        await db_session.refresh(washer)

        today = datetime.now().strftime("%Y-%m-%d")
        shift = Shift(
            userId=washer.id,
            date=today,
            startTime="08:00",
            endTime="20:00",
            status="confirmed",
            createdBy="admin",
            createdAt=datetime.now().isoformat(),
            updatedAt=datetime.now().isoformat(),
        )
        db_session.add(shift)
        await db_session.commit()

        response = await async_client.get(
            "/api/shifts/today", headers={"Authorization": f"Bearer {admin_token}"}
        )
        assert response.status_code == 200
        data = response.json()
        assert len(data) >= 1
        assert data[0]["status"] == "confirmed"

    @pytest.mark.asyncio
    async def test_current_shifts(self, async_client, db_session, admin_token):
        """Current endpoint returns washers on duty right now."""
        washer = User(
            username="shift_washer4",
            passwordHash="fakehash",
            role="washer",
            displayName="Shift Washer 4",
            createdAt=datetime.now().isoformat(),
        )
        db_session.add(washer)
        await db_session.commit()
        await db_session.refresh(washer)

        now = datetime.now()
        today = now.strftime("%Y-%m-%d")
        # Create a shift that covers the entire day to avoid time-of-day flakiness
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

        response = await async_client.get(
            "/api/shifts/current", headers={"Authorization": f"Bearer {admin_token}"}
        )
        assert response.status_code == 200
        data = response.json()
        assert len(data) >= 1
        assert data[0]["name"] == "Shift Washer 4"

    @pytest.mark.asyncio
    async def test_current_shifts_excludes_outside_range(
        self, async_client, db_session, admin_token
    ):
        """Current endpoint excludes shifts that don't cover current time."""
        washer = User(
            username="shift_washer5",
            passwordHash="fakehash",
            role="washer",
            displayName="Shift Washer 5",
            createdAt=datetime.now().isoformat(),
        )
        db_session.add(washer)
        await db_session.commit()
        await db_session.refresh(washer)

        now = datetime.now()
        today = now.strftime("%Y-%m-%d")
        # Shift in the future (should not appear)
        start = (now + timedelta(hours=1)).strftime("%H:%M")
        end = (now + timedelta(hours=3)).strftime("%H:%M")
        shift = Shift(
            userId=washer.id,
            date=today,
            startTime=start,
            endTime=end,
            status="confirmed",
            createdBy="admin",
            createdAt=datetime.now().isoformat(),
            updatedAt=datetime.now().isoformat(),
        )
        db_session.add(shift)
        await db_session.commit()

        response = await async_client.get(
            "/api/shifts/current", headers={"Authorization": f"Bearer {admin_token}"}
        )
        assert response.status_code == 200
        data = response.json()
        # Should not include future shift
        names = [s["name"] for s in data]
        assert "Shift Washer 5" not in names

    @pytest.mark.asyncio
    async def test_delete_shift_admin(self, async_client, db_session, admin_token):
        """Admin can delete any shift."""
        washer = User(
            username="shift_washer6",
            passwordHash="fakehash",
            role="washer",
            displayName="Shift Washer 6",
            createdAt=datetime.now().isoformat(),
        )
        db_session.add(washer)
        await db_session.commit()
        await db_session.refresh(washer)

        today = datetime.now().strftime("%Y-%m-%d")
        shift = Shift(
            userId=washer.id,
            date=today,
            startTime="08:00",
            endTime="20:00",
            status="confirmed",
            createdBy="admin",
            createdAt=datetime.now().isoformat(),
            updatedAt=datetime.now().isoformat(),
        )
        db_session.add(shift)
        await db_session.commit()
        await db_session.refresh(shift)

        response = await async_client.delete(
            f"/api/shifts/{shift.id}",
            headers={"Authorization": f"Bearer {admin_token}"},
        )
        assert response.status_code == 204
