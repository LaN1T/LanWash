from datetime import datetime, time, timedelta

import pytest

from models import Shift, User


class TestShiftMove:
    @pytest.mark.asyncio
    async def test_admin_moves_shift_to_another_date(
        self, async_client, db_session, admin_token
    ):
        washer = User(
            username="move_washer1",
            passwordHash="fakehash",
            role="washer",
            displayName="Move Washer 1",
            createdAt=datetime.now(),
        )
        db_session.add(washer)
        await db_session.commit()
        await db_session.refresh(washer)

        today = datetime.now().date()
        tomorrow = today + timedelta(days=1)

        shift = Shift(
            userId=washer.id,
            date=today,
            startTime=time(9, 0),
            endTime=time(18, 0),
            status="confirmed",
            createdBy="admin",
            createdAt=datetime.now(),
            updatedAt=datetime.now(),
        )
        db_session.add(shift)
        await db_session.commit()
        await db_session.refresh(shift)

        response = await async_client.patch(
            f"/api/shifts/{shift.id}/move",
            json={"targetUserId": washer.id, "targetDate": tomorrow.isoformat()},
            headers={"Authorization": f"Bearer {admin_token}"},
        )
        assert response.status_code == 200
        data = response.json()
        assert data["userId"] == washer.id
        assert data["date"] == tomorrow.isoformat()
        assert data["startTime"] == "09:00"
        assert data["endTime"] == "18:00"
        assert data["status"] == "confirmed"

    @pytest.mark.asyncio
    async def test_admin_moves_shift_to_another_washer(
        self, async_client, db_session, admin_token
    ):
        washer_a = User(
            username="move_washer_a",
            passwordHash="fakehash",
            role="washer",
            displayName="Washer A",
            createdAt=datetime.now(),
        )
        washer_b = User(
            username="move_washer_b",
            passwordHash="fakehash",
            role="washer",
            displayName="Washer B",
            createdAt=datetime.now(),
        )
        db_session.add_all([washer_a, washer_b])
        await db_session.commit()
        await db_session.refresh(washer_a)
        await db_session.refresh(washer_b)

        today = datetime.now().date()
        shift = Shift(
            userId=washer_a.id,
            date=today,
            startTime=time(10, 0),
            endTime=time(19, 0),
            status="confirmed",
            createdBy="admin",
            createdAt=datetime.now(),
            updatedAt=datetime.now(),
        )
        db_session.add(shift)
        await db_session.commit()
        await db_session.refresh(shift)

        response = await async_client.patch(
            f"/api/shifts/{shift.id}/move",
            json={"targetUserId": washer_b.id, "targetDate": today.isoformat()},
            headers={"Authorization": f"Bearer {admin_token}"},
        )
        assert response.status_code == 200
        data = response.json()
        assert data["userId"] == washer_b.id
        assert data["date"] == today.isoformat()

    @pytest.mark.asyncio
    async def test_non_admin_cannot_move_shift(
        self, async_client, db_session, admin_token, washer_token
    ):
        washer = User(
            username="move_washer_c",
            passwordHash="fakehash",
            role="washer",
            displayName="Washer C",
            createdAt=datetime.now(),
        )
        db_session.add(washer)
        await db_session.commit()
        await db_session.refresh(washer)

        today = datetime.now().date()
        tomorrow = today + timedelta(days=1)
        shift = Shift(
            userId=washer.id,
            date=today,
            startTime=time(9, 0),
            endTime=time(18, 0),
            status="confirmed",
            createdBy="admin",
            createdAt=datetime.now(),
            updatedAt=datetime.now(),
        )
        db_session.add(shift)
        await db_session.commit()
        await db_session.refresh(shift)

        response = await async_client.patch(
            f"/api/shifts/{shift.id}/move",
            json={"targetUserId": washer.id, "targetDate": tomorrow.isoformat()},
            headers={"Authorization": f"Bearer {washer_token}"},
        )
        assert response.status_code == 403

    @pytest.mark.asyncio
    async def test_move_target_user_not_found(
        self, async_client, db_session, admin_token
    ):
        washer = User(
            username="move_washer_d",
            passwordHash="fakehash",
            role="washer",
            displayName="Washer D",
            createdAt=datetime.now(),
        )
        db_session.add(washer)
        await db_session.commit()
        await db_session.refresh(washer)

        today = datetime.now().date()
        tomorrow = today + timedelta(days=1)
        shift = Shift(
            userId=washer.id,
            date=today,
            startTime=time(9, 0),
            endTime=time(18, 0),
            status="confirmed",
            createdBy="admin",
            createdAt=datetime.now(),
            updatedAt=datetime.now(),
        )
        db_session.add(shift)
        await db_session.commit()
        await db_session.refresh(shift)

        response = await async_client.patch(
            f"/api/shifts/{shift.id}/move",
            json={"targetUserId": 99999, "targetDate": tomorrow.isoformat()},
            headers={"Authorization": f"Bearer {admin_token}"},
        )
        assert response.status_code == 404

    @pytest.mark.asyncio
    async def test_move_overwrites_existing_shift_at_target(
        self, async_client, db_session, admin_token
    ):
        washer = User(
            username="move_washer_e",
            passwordHash="fakehash",
            role="washer",
            displayName="Washer E",
            createdAt=datetime.now(),
        )
        db_session.add(washer)
        await db_session.commit()
        await db_session.refresh(washer)

        today = datetime.now().date()
        tomorrow = today + timedelta(days=1)

        source = Shift(
            userId=washer.id,
            date=today,
            startTime=time(8, 0),
            endTime=time(17, 0),
            status="confirmed",
            createdBy="admin",
            createdAt=datetime.now(),
            updatedAt=datetime.now(),
        )
        target_existing = Shift(
            userId=washer.id,
            date=tomorrow,
            startTime=time(12, 0),
            endTime=time(20, 0),
            status="confirmed",
            createdBy="admin",
            createdAt=datetime.now(),
            updatedAt=datetime.now(),
        )
        db_session.add_all([source, target_existing])
        await db_session.commit()
        await db_session.refresh(source)
        await db_session.refresh(target_existing)

        response = await async_client.patch(
            f"/api/shifts/{source.id}/move",
            json={"targetUserId": washer.id, "targetDate": tomorrow.isoformat()},
            headers={"Authorization": f"Bearer {admin_token}"},
        )
        assert response.status_code == 200
        data = response.json()
        assert data["date"] == tomorrow.isoformat()
        assert data["startTime"] == "08:00"
        assert data["endTime"] == "17:00"

        # Only one shift should remain at the target date.
        list_response = await async_client.get(
            "/api/shifts/",
            params={"start_date": tomorrow.isoformat(), "end_date": tomorrow.isoformat()},
            headers={"Authorization": f"Bearer {admin_token}"},
        )
        assert list_response.status_code == 200
        shifts = list_response.json()
        assert len(shifts) == 1
        assert shifts[0]["startTime"] == "08:00"
        assert shifts[0]["endTime"] == "17:00"
