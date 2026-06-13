import pytest
from unittest.mock import AsyncMock, patch


@pytest.mark.asyncio
async def test_lifespan_closes_arq_pool_and_engine():
    from contextlib import asynccontextmanager

    from main import lifespan

    app_mock = type("App", (), {"state": type("State", (), {})()})()

    with (
        patch("main.init_db", new_callable=AsyncMock) as mock_init_db,
        patch("main.get_arq_pool", new_callable=AsyncMock) as mock_get_arq_pool,
        patch("main.close_arq_pool", new_callable=AsyncMock) as mock_close_arq_pool,
        patch("main.engine", new_callable=AsyncMock) as mock_engine,
        patch("core.redis_client.get_redis", new_callable=AsyncMock) as mock_get_redis,
    ):
        mock_arq_pool = AsyncMock()
        mock_get_arq_pool.return_value = mock_arq_pool
        mock_redis = AsyncMock()
        mock_get_redis.return_value = mock_redis

        @asynccontextmanager
        async def _lifespan():
            async with lifespan(app_mock):
                yield

        async with _lifespan():
            pass

        mock_init_db.assert_awaited_once()
        mock_get_arq_pool.assert_awaited_once()
        mock_close_arq_pool.assert_awaited_once()
        mock_engine.dispose.assert_awaited_once()
        mock_redis.aclose.assert_awaited_once()
