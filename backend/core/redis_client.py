import os

import redis.asyncio as aioredis
import structlog

_redis_url = os.getenv("REDIS_URL")
_redis_client = None

logger = structlog.get_logger()


def get_redis() -> aioredis.Redis:
    global _redis_client
    if _redis_client is not None:
        return _redis_client
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
    return _redis_client


# Deprecated: use get_redis() for lazy initialization
redis_client = None
