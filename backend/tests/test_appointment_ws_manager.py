from datetime import datetime
from types import SimpleNamespace
from unittest.mock import AsyncMock, MagicMock, patch

import pytest

from services.appointment_ws_manager import AppointmentWebSocketManager


def make_appointment(
    appointment_id: str = "appt-1",
    owner_username: str = "owner",
    assigned_washer: str = "[]",
):
    return SimpleNamespace(
        id=appointment_id,
        userId=1,
        clientName="Client",
        carModel="Model",
        carNumber="A123BC",
        dateTime=datetime.now(),
        washTypeId="wt-1",
        additionalServices="[]",
        status="pending",
        notes="",
        isFavorite=False,
        ownerUsername=owner_username,
        promoPrice=0,
        paidPrice=0,
        isModifiedByAdmin=False,
        isModifiedByWasher=False,
        isSeenByClient=True,
        originalPrice=0,
        assignedWasher=assigned_washer,
        promoId=None,
        subscriptionId=None,
        box_index=0,
        late_minutes=0,
        cancel_reason="",
    )


class FakeWs:
    def __init__(self):
        self.sent = []
        self.closed = False

    async def send_text(self, text: str):
        self.sent.append(text)

    async def close(self, code: int = 1000):
        self.closed = True


@pytest.mark.asyncio
async def test_connect_and_disconnect():
    mgr = AppointmentWebSocketManager()
    ws = FakeWs()
    await mgr.connect(7, "washer", ws)
    assert any(item[0] is ws for item in mgr._connections[7])
    await mgr.disconnect(7, ws)
    assert 7 not in mgr._connections


@pytest.mark.asyncio
async def test_notify_appointment_sends_to_owner():
    mgr = AppointmentWebSocketManager()
    owner_ws = FakeWs()
    await mgr.connect(1, "client", owner_ws)

    appointment = make_appointment()
    db = AsyncMock()

    with patch.object(
        mgr, "_resolve_recipients", return_value=[(1, "client")]
    ):
        await mgr.notify_appointment(db, appointment, "created")

    assert len(owner_ws.sent) == 1
    assert '"event": "created"' in owner_ws.sent[0]


@pytest.mark.asyncio
async def test_notify_appointment_sends_to_assigned_washer():
    mgr = AppointmentWebSocketManager()
    washer_ws = FakeWs()
    await mgr.connect(2, "washer", washer_ws)

    appointment = make_appointment(assigned_washer='["washer1"]')
    db = AsyncMock()

    with patch.object(
        mgr, "_resolve_recipients", return_value=[(2, "washer")]
    ):
        await mgr.notify_appointment(db, appointment, "assigned")

    assert len(washer_ws.sent) == 1
    assert '"event": "assigned"' in washer_ws.sent[0]


@pytest.mark.asyncio
async def test_notify_appointment_sends_to_admin():
    mgr = AppointmentWebSocketManager()
    admin_ws = FakeWs()
    await mgr.connect(3, "admin", admin_ws)

    appointment = make_appointment()
    db = AsyncMock()

    with patch.object(mgr, "_resolve_recipients", return_value=[(None, "admin")]):
        await mgr.notify_appointment(db, appointment, "updated")

    assert len(admin_ws.sent) == 1
    assert '"event": "updated"' in admin_ws.sent[0]


@pytest.mark.asyncio
async def test_notify_appointment_deduplicates_shared_socket():
    mgr = AppointmentWebSocketManager()
    shared_ws = FakeWs()
    # Same socket registered as admin and as owner.
    await mgr.connect(1, "admin", shared_ws)
    await mgr.connect(1, "client", shared_ws)

    appointment = make_appointment()
    db = AsyncMock()

    with patch.object(
        mgr,
        "_resolve_recipients",
        return_value=[(1, "client"), (None, "admin")],
    ):
        await mgr.notify_appointment(db, appointment, "updated")

    assert len(shared_ws.sent) == 1


@pytest.mark.asyncio
async def test_notify_appointment_removes_socket_on_send_error():
    mgr = AppointmentWebSocketManager()
    failing_ws = FakeWs()
    failing_ws.send_text = AsyncMock(side_effect=RuntimeError("connection lost"))
    await mgr.connect(4, "client", failing_ws)

    appointment = make_appointment()
    db = AsyncMock()

    with patch.object(
        mgr, "_resolve_recipients", return_value=[(4, "client")]
    ):
        await mgr.notify_appointment(db, appointment, "updated")

    assert 4 not in mgr._connections


@pytest.mark.asyncio
async def test_notify_appointment_removes_socket_on_timeout():
    mgr = AppointmentWebSocketManager()
    slow_ws = FakeWs()
    slow_ws.send_text = AsyncMock(side_effect=TimeoutError())
    await mgr.connect(5, "client", slow_ws)

    appointment = make_appointment()
    db = AsyncMock()

    with patch.object(
        mgr, "_resolve_recipients", return_value=[(5, "client")]
    ):
        await mgr.notify_appointment(db, appointment, "updated")

    assert 5 not in mgr._connections


@pytest.mark.asyncio
async def test_resolve_recipients_returns_owner_washer_and_admin():
    mgr = AppointmentWebSocketManager()
    appointment = make_appointment(
        owner_username="owner1", assigned_washer='["washer1"]'
    )

    owner = SimpleNamespace(id=10, role="client")
    washer_rows = [(20, "washer")]

    db = AsyncMock()
    db.execute = AsyncMock()

    call_count = 0

    def fake_execute(stmt):
        nonlocal call_count
        call_count += 1
        result = MagicMock()
        if call_count == 1:
            result.scalar_one_or_none.return_value = owner
            result.all.return_value = []
        elif call_count == 2:
            result.scalar_one_or_none.return_value = None
            result.all.return_value = washer_rows
        else:
            result.scalar_one_or_none.return_value = None
            result.all.return_value = []
        return result

    db.execute.side_effect = fake_execute

    recipients = await mgr._resolve_recipients(db, appointment)

    assert set(recipients) == {(10, "client"), (20, "washer"), (None, "admin")}


@pytest.mark.asyncio
async def test_resolve_recipients_handles_invalid_assigned_washer_json():
    mgr = AppointmentWebSocketManager()
    appointment = make_appointment(assigned_washer="not-json")

    db = AsyncMock()
    db.execute = AsyncMock()

    def fake_execute(stmt):
        result = MagicMock()
        result.scalar_one_or_none.return_value = None
        result.all.return_value = []
        return result

    db.execute.side_effect = fake_execute

    recipients = await mgr._resolve_recipients(db, appointment)

    assert recipients == [(None, "admin")]
