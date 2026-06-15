"""ARQ background task pool helpers."""

from arq import create_pool
from arq.connections import RedisSettings
from core.config import get_settings

settings = get_settings()

REDIS_SETTINGS = RedisSettings.from_dsn(settings.redis_url or "redis://localhost:6379")

_arq_pool = None


async def get_arq_pool():
    """Create or return cached ARQ pool."""
    global _arq_pool
    if _arq_pool is None:
        _arq_pool = await create_pool(REDIS_SETTINGS)
    return _arq_pool


async def close_arq_pool():
    """Close cached ARQ pool if open."""
    global _arq_pool
    if _arq_pool is not None:
        await _arq_pool.close()
        _arq_pool = None
