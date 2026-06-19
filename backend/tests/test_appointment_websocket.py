import uuid

import pytest
from fastapi.testclient import TestClient
from sqlalchemy.ext.asyncio import async_sessionmaker
from starlette.websockets import WebSocketDisconnect

from app.deps import get_db
from app.main import app
from db.session import async_engine


async def _create_isolated_session():
    conn = await async_engine.connect()
    trans = await conn.begin()
    session_maker = async_sessionmaker(
        bind=conn,
        expire_on_commit=False,
        join_transaction_mode="create_savepoint",
    )
    session = session_maker()

    async def _test_commit():
        await session.flush()

    session.commit = _test_commit
    return conn, trans, session


async def _close_isolated_session(conn, trans, session):
    await session.close()
    await trans.rollback()
    await conn.close()


@pytest.fixture
def ws_client():
    with TestClient(app) as client:
        conn, trans, session = client.portal.call(_create_isolated_session)

        async def _override_get_db():
            yield session

        # HTTP endpoints go through dependency_overrides, but the websocket
        # endpoint in app/main.py calls get_db() directly, so patch the module
        # reference as well to keep the DB view shared inside one test.
        import app.main as _main_module

        original_main_get_db = _main_module.get_db
        _main_module.get_db = _override_get_db
        app.dependency_overrides[get_db] = _override_get_db
        try:
            yield client
        finally:
            app.dependency_overrides.pop(get_db, None)
            _main_module.get_db = original_main_get_db
            client.portal.call(_close_isolated_session, conn, trans, session)


class TestAppointmentWebSocket:
    def test_websocket_auth_fails_with_bad_token(self, ws_client):
        with ws_client.websocket_connect("/ws/appointments") as ws:
            ws.send_json({"type": "auth", "token": "invalid"})
            with pytest.raises(WebSocketDisconnect) as exc:
                ws.receive_json()
            assert exc.value.code == 1008

    def test_websocket_broadcasts_created_appointment(self, ws_client):
        username = f"ws_appt_{uuid.uuid4().hex[:8]}"
        ws_client.post(
            "/api/auth/register",
            json={
                "username": username,
                "password": "TestPass123!",
                "displayName": "WS Client",
            },
        )
        login_resp = ws_client.post(
            "/api/auth/login",
            json={"username": username, "password": "TestPass123!"},
        )
        assert login_resp.status_code == 200
        token = login_resp.json()["access_token"]

        with ws_client.websocket_connect("/ws/appointments") as ws:
            ws.send_json({"type": "auth", "token": token})
            ws.send_json({"type": "pong"})

            create_resp = ws_client.post(
                "/api/appointments/",
                headers={"Authorization": f"Bearer {token}"},
                json={
                    "id": f"appt_{username}",
                    "clientName": "WS Client",
                    "carModel": "Kia Rio",
                    "carNumber": "A111AA77",
                    "dateTime": "2099-10-10T10:00:00",
                    "washTypeId": "w1",
                    "additionalServices": "[]",
                    "status": "scheduled",
                    "notes": "",
                    "isFavorite": False,
                    "ownerUsername": username,
                    "promoPrice": 0,
                    "paidPrice": 1000,
                    "originalPrice": 1000,
                    "assignedWasher": "[]",
                    "box_index": 0,
                },
            )
            assert create_resp.status_code == 200
            created = create_resp.json()

            data = ws.receive_json()
            assert data["type"] == "appointment_updated"
            assert data["event"] == "created"
            assert data["appointment"]["id"] == created["id"]
            assert data["appointment"]["ownerUsername"] == username
