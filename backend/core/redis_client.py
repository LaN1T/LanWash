import os
import redis

_redis_url = os.getenv("REDIS_URL")
_redis_client = None

def get_redis():
    global _redis_client
    if _redis_client is not None:
        return _redis_client
    if _redis_url:
        _redis_client = redis.from_url(_redis_url, decode_responses=True)
    else:
        _redis_client = redis.Redis(host='localhost', port=6379, decode_responses=True)
    return _redis_client

# Deprecated: use get_redis() for lazy initialization
redis_client = None
