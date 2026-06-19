# backend/tests/test_appointment_websocket.py
import uuid

import pytest
from starlette.testclient import TestClient

from main import app


class TestAppointmentWebSocket:
    def test_websocket_auth_fails_with_bad_token(self):
        with TestClient(app) as client:
            with client.websocket_connect("/ws/appointments") as ws:
                ws.send_json({"type": "auth", "token": "invalid"})
                # Starlette закрывает соединение с кодом 1008
                with pytest.raises(Exception):
                    ws.receive_json()

    def test_websocket_broadcasts_created_appointment(self):
        username = f"ws_appt_{uuid.uuid4().hex[:8]}"
        with TestClient(app) as client:
            client.post(
                "/api/auth/register",
                json={
                    "username": username,
                    "password": "TestPass123!",
                    "displayName": "WS Client",
                },
            )
            login_resp = client.post(
                "/api/auth/login",
                json={"username": username, "password": "TestPass123!"},
            )
            assert login_resp.status_code == 200
            token = login_resp.json()["access_token"]

            with client.websocket_connect("/ws/appointments") as ws:
                ws.send_json({"type": "auth", "token": token})

                create_resp = client.post(
                    "/api/appointments/",
                    headers={"Authorization": f"Bearer {token}"},
                    json={
                        "id": f"appt_{username}",
                        "clientName": "WS Клиент",
                        "carModel": "Kia Rio",
                        "carNumber": "А111АА77",
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

                data = ws.receive_json()
                assert data["type"] == "appointment_updated"
                assert data["event"] == "created"
                assert data["appointment"]["ownerUsername"] == username
