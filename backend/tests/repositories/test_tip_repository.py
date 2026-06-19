from datetime import datetime

import pytest
from sqlalchemy import text

from models import Appointment, Tip
from repositories.tip import TipRepository


def _appointment(
    appt_id: str,
    owner: str = "owner_tip",
    assigned_washer: str = '["washer_tip"]',
) -> Appointment:
    return Appointment(
        id=appt_id,
        userId=None,
        clientName="Client",
        carModel="Model",
        carNumber="А111БВ777",
        dateTime="2099-06-01T10:00:00",
        washTypeId="w1",
        status="completed",
        ownerUsername=owner,
        assignedWasher=assigned_washer,
        originalPrice=1000,
    )


def _tip(
    appt_id: str,
    washer: str = "washer_tip",
    amount: int = 100,
    status: str = "pending",
) -> Tip:
    return Tip(
        appointmentId=appt_id,
        washerUsername=washer,
        amount=amount,
        method="sbp",
        status=status,
        createdAt=datetime.now(),
    )


class TestTipRepository:
    @pytest.mark.asyncio
    async def test_get_by_appointment_and_washer(self, db_session):
        repo = TipRepository(db_session)
        appt = _appointment("tip_repo_appt_1")
        db_session.add(appt)
        await db_session.flush()

        tip = _tip(appt.id)
        db_session.add(tip)
        await db_session.flush()

        found = await repo.get_by_appointment_and_washer(appt.id, "washer_tip")
        assert found is not None
        assert found.id == tip.id

    @pytest.mark.asyncio
    async def test_get_by_appointment_and_washer_missing(self, db_session):
        repo = TipRepository(db_session)
        assert await repo.get_by_appointment_and_washer("missing", "washer_tip") is None

    @pytest.mark.asyncio
    async def test_list_with_appointments(self, db_session):
        repo = TipRepository(db_session)
        appt1 = _appointment("tip_repo_appt_2")
        appt2 = _appointment("tip_repo_appt_3", assigned_washer='["other_washer"]')
        db_session.add_all([appt1, appt2])
        await db_session.flush()

        tip1 = _tip(appt1.id)
        tip2 = _tip(appt2.id, washer="other_washer")
        orphan_tip = _tip("nonexistent_appointment_id")

        # The schema enforces a non-nullable FK on appointmentId, so temporarily
        # drop the constraint inside this transaction to test the left-outer-join
        # semantics with an orphan tip. The DDL is rolled back with the test
        # transaction, leaving the schema unchanged for other tests.
        await db_session.execute(
            text('ALTER TABLE tips DROP CONSTRAINT "tips_appointmentId_fkey"')
        )

        db_session.add_all([tip1, tip2, orphan_tip])
        await db_session.flush()

        rows = await repo.list_with_appointments("washer_tip")
        assert len(rows) == 2
        matched = {tip.id: (tip, appointment) for tip, appointment in rows}
        assert tip1.id in matched
        tip, appointment = matched[tip1.id]
        assert isinstance(tip, Tip)
        assert isinstance(appointment, Appointment)
        assert appointment.id == appt1.id

        assert orphan_tip.id in matched
        orphan, orphan_appointment = matched[orphan_tip.id]
        assert isinstance(orphan, Tip)
        assert orphan_appointment is None

    @pytest.mark.asyncio
    async def test_get_stats(self, db_session):
        repo = TipRepository(db_session)
        appt1 = _appointment("tip_repo_appt_4")
        appt2 = _appointment("tip_repo_appt_5")
        appt3 = _appointment("tip_repo_appt_6", assigned_washer='["other_washer"]')
        db_session.add_all([appt1, appt2, appt3])
        await db_session.flush()

        db_session.add_all(
            [
                _tip(appt1.id, status="pending", amount=100),
                _tip(appt2.id, status="paid", amount=200),
                _tip(appt3.id, washer="other_washer", status="paid", amount=300),
            ]
        )
        await db_session.flush()

        stats = await repo.get_stats("washer_tip")
        assert stats["totalTips"] == 2
        assert stats["totalAmount"] == 200
        assert stats["pendingAmount"] == 100

    @pytest.mark.asyncio
    async def test_mark_paid_success(self, db_session):
        repo = TipRepository(db_session)
        appt = _appointment("tip_repo_appt_7")
        db_session.add(appt)
        await db_session.flush()

        tip = _tip(appt.id)
        db_session.add(tip)
        await db_session.flush()

        rowcount = await repo.mark_paid(tip.id)
        await db_session.flush()
        assert rowcount == 1

        refreshed = await db_session.get(Tip, tip.id)
        assert refreshed.status == "paid"

    @pytest.mark.asyncio
    async def test_mark_paid_already_paid(self, db_session):
        repo = TipRepository(db_session)
        appt = _appointment("tip_repo_appt_8")
        db_session.add(appt)
        await db_session.flush()

        tip = _tip(appt.id, status="paid")
        db_session.add(tip)
        await db_session.flush()

        assert await repo.mark_paid(tip.id) == 0

    @pytest.mark.asyncio
    async def test_mark_paid_missing(self, db_session):
        repo = TipRepository(db_session)
        assert await repo.mark_paid(999999) == 0
