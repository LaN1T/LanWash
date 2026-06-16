from sqlalchemy.ext.asyncio import create_async_engine

from core.config import get_settings

settings = get_settings()

_engine_kwargs = {
    "echo": False,
    "pool_pre_ping": True,
    "pool_recycle": 3600,
}

# SQLite (especially :memory:) uses StaticPool and does not accept
# pool_size or max_overflow.
if not settings.database_url.startswith("sqlite"):
    _engine_kwargs["pool_size"] = 10
    _engine_kwargs["max_overflow"] = 20

engine = create_async_engine(settings.database_url, **_engine_kwargs)
