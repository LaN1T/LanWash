from unittest.mock import AsyncMock, patch

import pytest


@pytest.mark.asyncio
async def test_send_fcm_notification_task_calls_service():
    from tasks.notifications import send_fcm_notification

    with patch(
        "services.fcm_service.fcm_service.send_notification_to_tokens",
        new_callable=AsyncMock,
    ) as mock_send:
        mock_send.return_value.success_count = 2
        mock_send.return_value.failure_count = 0
        result = await send_fcm_notification(
            None,
            ["token1", "token2"],
            "Test title",
            "Test body",
            {"key": "value"},
        )

        mock_send.assert_awaited_once_with(
            ["token1", "token2"],
            "Test title",
            "Test body",
            {"key": "value"},
        )
        assert result == {"sent": 2, "failure": 0}


@pytest.mark.asyncio
async def test_send_fcm_notification_task_skips_empty_tokens():
    from tasks.notifications import send_fcm_notification

    with patch(
        "services.fcm_service.fcm_service.send_notification_to_tokens",
        new_callable=AsyncMock,
    ) as mock_send:
        result = await send_fcm_notification(None, [], "title", "body", None)
        mock_send.assert_not_awaited()
        assert result == {"sent": 0, "skipped": True}
