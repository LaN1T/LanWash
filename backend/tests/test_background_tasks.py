import pytest
from unittest.mock import AsyncMock, patch

from tasks import send_notification, update_metrics


@pytest.mark.asyncio
async def test_send_notification_task():
    result = await send_notification(None, user_id=1, message="Hello")
    assert result is True


@pytest.mark.asyncio
async def test_update_metrics_task():
    with patch("tasks.update_business_metrics", new_callable=AsyncMock) as mock:
        result = await update_metrics(None)
        mock.assert_awaited_once()
        assert result is True


def _redis_available():
    import redis as sync_redis

    try:
        r = sync_redis.Redis(host="localhost", port=6379, socket_connect_timeout=1)
        r.ping()
        return True
    except Exception:
        return False


@pytest.mark.asyncio
@pytest.mark.skipif(not _redis_available(), reason="Redis not available")
async def test_arq_pool_enqueue_job():
    from core.background import get_arq_pool, close_arq_pool

    pool = await get_arq_pool()
    job = await pool.enqueue_job("send_notification", 1, "integration test")
    assert job is not None
    await close_arq_pool()
