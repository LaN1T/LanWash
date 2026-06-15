from sqlalchemy.ext.asyncio import create_async_engine

from core.config import get_settings

settings = get_settings()

_engine_kwargs = {
    "echo": False,
    "pool_pre_ping": True,
    "pool_size": 10,
    "max_overflow": 20,
    "pool_recycle": 3600,
}

engine = create_async_engine(settings.database_url, **_engine_kwargs)
