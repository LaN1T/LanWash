"""Async Redis cache abstraction with in-memory fallback."""

import json
from typing import Any

import structlog
from core.redis_client import get_redis

logger = structlog.get_logger()


class Cache:
    """Simple async Redis cache with optional TTL.

    Silently falls back to a no-op when Redis is unavailable so the app
    continues to work in development/test environments without Redis.
    """

    def __init__(self, prefix: str = "lanwash", default_ttl: int = 300):
        self.prefix = prefix
        self.default_ttl = default_ttl

    def _key(self, key: str) -> str:
        return f"{self.prefix}:{key}"

    async def get(self, key: str) -> Any | None:
        r = await get_redis()
        if not r:
            return None
        try:
            data = await r.get(self._key(key))
            if data:
                return json.loads(data)
        except Exception as e:
            logger.warning("cache_get_failed", key=key, error=str(e))
        return None

    async def set(self, key: str, value: Any, ttl: int | None = None) -> None:
        r = await get_redis()
        if not r:
            return
        try:
            await r.setex(
                self._key(key),
                ttl or self.default_ttl,
                json.dumps(value, default=str),
            )
        except Exception as e:
            logger.warning("cache_set_failed", key=key, error=str(e))

    async def delete(self, key: str) -> None:
        r = await get_redis()
        if not r:
            return
        try:
            await r.delete(self._key(key))
        except Exception as e:
            logger.warning("cache_delete_failed", key=key, error=str(e))

    async def delete_pattern(self, pattern: str) -> None:
        r = await get_redis()
        if not r:
            return
        try:
            keys = []
            async for key in r.scan_iter(match=self._key(pattern)):
                keys.append(key)
            if keys:
                await r.delete(*keys)
        except Exception as e:
            logger.warning("cache_delete_pattern_failed", pattern=pattern, error=str(e))


cache = Cache()
