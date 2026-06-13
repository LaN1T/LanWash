import pytest

from core.cache import Cache


@pytest.mark.asyncio
async def test_cache_without_redis_returns_none():
    """Cache should degrade gracefully when Redis is unavailable."""
    c = Cache(prefix="test")
    await c.set("x", {"a": 1})
    assert await c.get("x") is None
