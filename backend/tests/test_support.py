import os
from unittest.mock import AsyncMock, patch

import pytest

from core.pagination import decode_cursor


@pytest.fixture(autouse=True)
def _mock_ai_services():
    with (
        patch(
            "app.routers.support.classify_and_reply",
            new_callable=AsyncMock,
            return_value=None,
        ) as _,
        patch(
            "app.routers.support.generate_admin_draft",
            new_callable=AsyncMock,
            return_value="Здравствуйте! Уточните детали.",
        ) as _,
    ):
        yield


class TestSupportChat:
    @pytest.mark.asyncio
    async def test_client_creates_chat(self, async_client, client_token):
        response = await async_client.post(
            "/api/support/chats",
            headers={"Authorization": f"Bearer {client_token}"},
            json={"firstMessage": "Привет, сколько стоит мойка?"},
        )
        assert response.status_code == 200
        data = response.json()
        assert data["userName"]
        assert data["status"] in ("open", "ai_handled", "waiting_admin")

    @pytest.mark.asyncio
    async def test_client_lists_own_chats(self, async_client, client_token):
        await async_client.post(
            "/api/support/chats",
            headers={"Authorization": f"Bearer {client_token}"},
            json={"firstMessage": "Вопрос"},
        )
        response = await async_client.get(
            "/api/support/chats/my",
            headers={"Authorization": f"Bearer {client_token}"},
        )
        assert response.status_code == 200
        data = response.json()
        assert len(data) >= 1

    @pytest.mark.asyncio
    async def test_admin_lists_all_chats(self, async_client, client_token, admin_token):
        await async_client.post(
            "/api/support/chats",
            headers={"Authorization": f"Bearer {client_token}"},
            json={"firstMessage": "Для админа"},
        )
        response = await async_client.get(
            "/api/support/chats",
            headers={"Authorization": f"Bearer {admin_token}"},
        )
        assert response.status_code == 200
        data = response.json()
        assert any(c["lastMessagePreview"] == "Для админа" for c in data)

    @pytest.mark.asyncio
    async def test_client_cannot_see_other_chat(
        self, async_client, client_token, admin_token
    ):
        create_resp = await async_client.post(
            "/api/support/chats",
            headers={"Authorization": f"Bearer {client_token}"},
            json={"firstMessage": "Мой вопрос"},
        )
        chat_id = create_resp.json()["id"]
        # Try to access with no token
        response = await async_client.get(f"/api/support/chats/{chat_id}/messages")
        assert response.status_code == 401

    @pytest.mark.asyncio
    async def test_admin_reply(self, async_client, client_token, admin_token):
        create_resp = await async_client.post(
            "/api/support/chats",
            headers={"Authorization": f"Bearer {client_token}"},
            json={"firstMessage": "Жалоба"},
        )
        chat_id = create_resp.json()["id"]

        with patch(
            "app.routers.support.classify_and_reply",
            new_callable=AsyncMock,
            return_value=None,
        ):
            response = await async_client.post(
                f"/api/support/chats/{chat_id}/messages",
                headers={"Authorization": f"Bearer {admin_token}"},
                json={"content": "Разберёмся"},
            )
        assert response.status_code == 200
        assert response.json()["senderRole"] == "admin"

    @pytest.mark.asyncio
    async def test_faq_auto_reply(self, async_client, client_token):
        with patch(
            "app.routers.support.classify_and_reply",
            new_callable=AsyncMock,
            return_value="Экспресс-мойка стоит 500₽.",
        ):
            response = await async_client.post(
                "/api/support/chats",
                headers={"Authorization": f"Bearer {client_token}"},
                json={"firstMessage": "Сколько стоит экспресс-мойка?"},
            )
        assert response.status_code == 200
        data = response.json()
        assert data["status"] == "ai_handled"

    @pytest.mark.asyncio
    async def test_ai_draft_endpoint(self, async_client, client_token, admin_token):
        create_resp = await async_client.post(
            "/api/support/chats",
            headers={"Authorization": f"Bearer {client_token}"},
            json={"firstMessage": "Хочу перенести запись"},
        )
        chat_id = create_resp.json()["id"]

        with patch(
            "app.routers.support.generate_admin_draft",
            new_callable=AsyncMock,
            return_value="Добрый день! Уточните, пожалуйста, желаемое время.",
        ):
            response = await async_client.post(
                f"/api/support/chats/{chat_id}/ai-draft",
                headers={"Authorization": f"Bearer {admin_token}"},
            )
        assert response.status_code == 200
        assert "draft" in response.json()
        assert response.json()["draft"] != ""

    @pytest.mark.asyncio
    async def test_mark_read(self, async_client, client_token, admin_token):
        create_resp = await async_client.post(
            "/api/support/chats",
            headers={"Authorization": f"Bearer {client_token}"},
            json={"firstMessage": "Вопрос"},
        )
        chat_id = create_resp.json()["id"]

        response = await async_client.post(
            f"/api/support/chats/{chat_id}/read",
            headers={"Authorization": f"Bearer {admin_token}"},
        )
        assert response.status_code == 200


class TestSupportWebSocket:
    def test_websocket_broadcast(self):
        from starlette.testclient import TestClient

        from main import app

        with TestClient(app) as client:
            admin_resp = client.post(
                "/api/auth/login",
                json={
                    "username": "admin",
                    "password": os.getenv("INITIAL_ADMIN_PASSWORD"),
                },
            )
            assert admin_resp.status_code == 200
            admin_token = admin_resp.json()["access_token"]

            client.post(
                "/api/auth/register",
                json={
                    "username": "ws_client_test",
                    "password": "TestPass123!",
                    "displayName": "WS Client",
                },
            )
            user_resp = client.post(
                "/api/auth/login",
                json={
                    "username": "ws_client_test",
                    "password": "TestPass123!",
                },
            )
            assert user_resp.status_code == 200
            user_token = user_resp.json()["access_token"]

            with patch(
                "app.routers.support.classify_and_reply",
                new_callable=AsyncMock,
                return_value=None,
            ):
                create_resp = client.post(
                    "/api/support/chats",
                    headers={"Authorization": f"Bearer {user_token}"},
                    json={"firstMessage": "WS broadcast test"},
                )
            assert create_resp.status_code == 200
            chat_id = create_resp.json()["id"]

            with client.websocket_connect(f"/ws/support/chats/{chat_id}") as ws:
                ws.send_json({"type": "auth", "token": admin_token})
                with patch(
                    "app.routers.support.classify_and_reply",
                    new_callable=AsyncMock,
                    return_value=None,
                ):
                    msg_resp = client.post(
                        f"/api/support/chats/{chat_id}/messages",
                        headers={"Authorization": f"Bearer {user_token}"},
                        json={"content": "Hello from WS"},
                    )
                assert msg_resp.status_code == 200
                data = ws.receive_json()
                # Heartbeat pings may arrive before the broadcasted message.
                while data.get("type") == "ping":
                    data = ws.receive_json()
                assert data["type"] == "new_message"
                assert data["data"]["content"] == "Hello from WS"


class TestSupportCursorPagination:
    @pytest.mark.asyncio
    async def test_list_my_chats_without_cursor(self, async_client, client_token):
        for i in range(3):
            resp = await async_client.post(
                "/api/support/chats",
                headers={"Authorization": f"Bearer {client_token}"},
                json={"firstMessage": f"Вопрос {i}"},
            )
            assert resp.status_code == 200

        response = await async_client.get(
            "/api/support/chats/my",
            headers={"Authorization": f"Bearer {client_token}"},
        )
        assert response.status_code == 200
        data = response.json()
        assert len(data) >= 3
        assert "X-Next-Cursor" not in response.headers

    @pytest.mark.asyncio
    async def test_list_my_chats_with_cursor(self, async_client, client_token):
        messages = [f"Cursor chat {i}" for i in range(3)]
        for msg in messages:
            resp = await async_client.post(
                "/api/support/chats",
                headers={"Authorization": f"Bearer {client_token}"},
                json={"firstMessage": msg},
            )
            assert resp.status_code == 200

        first_page = await async_client.get(
            "/api/support/chats/my?limit=1",
            headers={"Authorization": f"Bearer {client_token}"},
        )
        assert first_page.status_code == 200
        first_data = first_page.json()
        assert len(first_data) == 1
        assert "X-Next-Cursor" in first_page.headers
        cursor = first_page.headers["X-Next-Cursor"]
        cursor_payload = decode_cursor(cursor)
        assert cursor_payload["id"] != first_data[0]["id"]

        second_page = await async_client.get(
            f"/api/support/chats/my?limit=1&cursor={cursor}",
            headers={"Authorization": f"Bearer {client_token}"},
        )
        assert second_page.status_code == 200
        second_data = second_page.json()
        assert len(second_data) == 1
        assert second_data[0]["id"] != first_data[0]["id"]

    @pytest.mark.asyncio
    async def test_list_all_chats_with_cursor(
        self, async_client, client_token, admin_token
    ):
        for i in range(3):
            resp = await async_client.post(
                "/api/support/chats",
                headers={"Authorization": f"Bearer {client_token}"},
                json={"firstMessage": f"Admin cursor {i}"},
            )
            assert resp.status_code == 200

        first_page = await async_client.get(
            "/api/support/chats?limit=1",
            headers={"Authorization": f"Bearer {admin_token}"},
        )
        assert first_page.status_code == 200
        first_data = first_page.json()
        assert len(first_data) == 1
        cursor = first_page.headers["X-Next-Cursor"]

        second_page = await async_client.get(
            f"/api/support/chats?limit=1&cursor={cursor}",
            headers={"Authorization": f"Bearer {admin_token}"},
        )
        assert second_page.status_code == 200
        second_data = second_page.json()
        assert len(second_data) == 1
        assert second_data[0]["id"] != first_data[0]["id"]

    @pytest.mark.asyncio
    async def test_list_messages_with_cursor(
        self, async_client, client_token, admin_token
    ):
        create_resp = await async_client.post(
            "/api/support/chats",
            headers={"Authorization": f"Bearer {client_token}"},
            json={"firstMessage": "Первое сообщение"},
        )
        chat_id = create_resp.json()["id"]

        with patch(
            "app.routers.support.classify_and_reply",
            new_callable=AsyncMock,
            return_value=None,
        ):
            for i in range(3):
                resp = await async_client.post(
                    f"/api/support/chats/{chat_id}/messages",
                    headers={"Authorization": f"Bearer {admin_token}"},
                    json={"content": f"Ответ админа {i}"},
                )
                assert resp.status_code == 200

        first_page = await async_client.get(
            f"/api/support/chats/{chat_id}/messages?limit=2",
            headers={"Authorization": f"Bearer {client_token}"},
        )
        assert first_page.status_code == 200
        first_data = first_page.json()
        assert len(first_data) == 2
        cursor = first_page.headers["X-Next-Cursor"]

        second_page = await async_client.get(
            f"/api/support/chats/{chat_id}/messages?limit=2&cursor={cursor}",
            headers={"Authorization": f"Bearer {client_token}"},
        )
        assert second_page.status_code == 200
        second_data = second_page.json()
        assert len(second_data) >= 1
        assert all(m["id"] not in {x["id"] for x in first_data} for m in second_data)
