import os

import redis.asyncio as aioredis
import structlog

_redis_url = os.getenv("REDIS_URL")
_redis_client = None

logger = structlog.get_logger()


def get_redis():
    global _redis_client
    if _redis_client is not None:
        return _redis_client
    try:
        if _redis_url:
            _redis_client = aioredis.from_url(
                _redis_url,
                decode_responses=True,
                socket_connect_timeout=2,
                socket_timeout=2,
            )
        else:
            _redis_client = aioredis.Redis(
                host="localhost",
                port=6379,
                decode_responses=True,
                socket_connect_timeout=2,
                socket_timeout=2,
            )
    except Exception as exc:
        logger.error("redis_client_init_failed", error=str(exc))
        _redis_client = None
    return _redis_client


# Deprecated: use get_redis() for lazy initialization
redis_client = None
