import os

import redis.asyncio as aioredis

_redis_url = os.getenv("REDIS_URL")
_redis_client = None
_redis_available = None


def get_redis():
    global _redis_client, _redis_available
    if _redis_available is False:
        return None
    if _redis_client is not None:
        return _redis_client
    try:
        if _redis_url:
            _redis_client = aioredis.from_url(
                _redis_url,
                decode_responses=True,
                socket_connect_timeout=0.5,
                socket_timeout=0.5,
            )
        else:
            _redis_client = aioredis.Redis(
                host="localhost",
                port=6379,
                decode_responses=True,
                socket_connect_timeout=0.5,
                socket_timeout=0.5,
            )
        _redis_available = True
    except Exception:
        _redis_available = False
        _redis_client = None
    return _redis_client


# Deprecated: use get_redis() for lazy initialization
redis_client = None
