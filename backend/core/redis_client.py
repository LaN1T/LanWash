import asyncio
import os

import redis.asyncio as aioredis
import structlog

_redis_url = os.getenv("REDIS_URL")
_redis_client = None
_redis_loop: asyncio.AbstractEventLoop | None = None

logger = structlog.get_logger()


async def get_redis() -> aioredis.Redis:
    """Return a Redis client bound to the current running event loop.

    The client is created lazily and cached. If the event loop changes
    between calls (e.g. in tests that spawn a fresh loop per request),
    the old client is closed and a new one is created for the current loop.
    """
    global _redis_client, _redis_loop

    current_loop = asyncio.get_running_loop()

    if _redis_client is not None and _redis_loop is current_loop:
        return _redis_client

    if _redis_client is not None:
        old_client = _redis_client
        _redis_client = None
        _redis_loop = None
        try:
            await old_client.aclose()
        except Exception as exc:
            logger.warning(
                "redis_client_close_failed",
                error=str(exc),
                error_type=type(exc).__name__,
            )

    if not _redis_url:
        raise RuntimeError("REDIS_URL is not set")

    _redis_client = aioredis.from_url(
        _redis_url,
        decode_responses=True,
        socket_connect_timeout=5,
        socket_timeout=5,
        health_check_interval=30,
        socket_keepalive=True,
    )
    _redis_loop = current_loop
    return _redis_client


# Deprecated: use get_redis() for lazy initialization
redis_client = None
