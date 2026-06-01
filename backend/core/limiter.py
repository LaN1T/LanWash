import os
from slowapi import Limiter
from slowapi.util import get_remote_address

# Use Redis for rate limiting in production (multi-worker safe).
# Fallback to in-memory storage if REDIS_URL is not set.
_redis_url = os.getenv("REDIS_URL")
_storage_uri = _redis_url if _redis_url else "memory://"

limiter = Limiter(
    key_func=get_remote_address,
    storage_uri=_storage_uri,
)
