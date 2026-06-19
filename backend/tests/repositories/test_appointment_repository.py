from datetime import datetime

import pytest

from models import Appointment, User
from repositories.appointment import AppointmentRepository
from services.auth_service import get_password_hash


async def _create_user(db_session, username: str) -> User:
    user = User(
        username=username,
        passwordHash=get_password_hash("TestPass123!"),
        role="client",
        displayName=username,
        createdAt=datetime.now(),
    )
    db_session.add(user)
    await db_session.flush()
    return user


def _appointment(
    appt_id: str,
    username: str,
    date_time: str,
    status: str = "completed",
    paid_price: int = 1000,
) -> Appointment:
    return Appointment(
        id=appt_id,
        userId=None,
        clientName="Client",
        carModel="BMW X5",
        carNumber="А111БВ777",
        dateTime=date_time,
        date=date_time[:10],
        washTypeId="w1",
        status=status,
        ownerUsername=username,
        paidPrice=paid_price,
    )


class TestAppointmentRepository:
    @pytest.mark.asyncio
    async def test_get_status_counts_in_period(self, db_session):
        user = await _create_user(db_session, "appt_status_user")
        repo = AppointmentRepository(db_session)
        db_session.add_all(
            [
                _appointment(
                    "a1", user.username, "2026-06-10T10:00:00", status="completed"
                ),
                _appointment(
                    "a2", user.username, "2026-06-11T10:00:00", status="completed"
                ),
                _appointment(
                    "a3", user.username, "2026-06-12T10:00:00", status="cancelled"
                ),
            ]
        )
        await db_session.flush()

        counts = await repo.get_status_counts_in_period(
            "2026-06-10T00:00:00", "2026-06-13T00:00:00"
        )
        counts_map = dict(counts)
        assert counts_map.get("completed") == 2
        assert counts_map.get("cancelled") == 1

    @pytest.mark.asyncio
    async def test_get_status_counts_in_period_empty(self, db_session):
        repo = AppointmentRepository(db_session)
        counts = await repo.get_status_counts_in_period(
            "2026-01-01T00:00:00", "2026-01-02T00:00:00"
        )
        assert counts == []

    @pytest.mark.asyncio
    async def test_get_revenue_stats_in_period(self, db_session):
        user = await _create_user(db_session, "appt_revenue_user")
        repo = AppointmentRepository(db_session)
        db_session.add_all(
            [
                _appointment(
                    "a4", user.username, "2026-06-10T10:00:00", paid_price=1000
                ),
                _appointment(
                    "a5", user.username, "2026-06-11T10:00:00", paid_price=2000
                ),
                _appointment(
                    "a6",
                    user.username,
                    "2026-06-12T10:00:00",
                    status="cancelled",
                    paid_price=5000,
                ),
            ]
        )
        await db_session.flush()

        total, average = await repo.get_revenue_stats_in_period(
            "2026-06-10T00:00:00", "2026-06-13T00:00:00"
        )

        assert total == 3000
        assert average == 1500

    @pytest.mark.asyncio
    async def test_count_completed_by_owner(self, db_session):
        user = await _create_user(db_session, "appt_owner_user")
        repo = AppointmentRepository(db_session)
        db_session.add_all(
            [
                _appointment(
                    "a7", user.username, "2026-06-10T10:00:00", status="completed"
                ),
                _appointment(
                    "a8", user.username, "2026-06-11T10:00:00", status="completed"
                ),
                _appointment(
                    "a9", user.username, "2026-06-12T10:00:00", status="scheduled"
                ),
            ]
        )
        await db_session.flush()

        assert await repo.count_completed_by_owner(user.username) == 2
