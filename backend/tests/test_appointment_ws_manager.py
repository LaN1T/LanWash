import pytest
from unittest.mock import MagicMock
from services.appointment_ws_manager import AppointmentWebSocketManager


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
