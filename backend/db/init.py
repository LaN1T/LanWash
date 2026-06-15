import asyncio
import subprocess
import sys
from pathlib import Path

import structlog

from core.config import get_settings
from db.base import Base
from db.engine import engine
from db.seed import seed_data

logger = structlog.get_logger()
settings = get_settings()


async def init_db():
    """Initialize database.

    In production we rely on Alembic migrations; in development/testing we
    create tables directly and seed reference data.
    """
    if settings.is_production:
        await _run_migrations()
        return

    async with engine.begin() as conn:
        await conn.run_sync(Base.metadata.create_all)
    await seed_data()


async def _run_migrations():
    """Run Alembic migrations in a subprocess."""
    backend_dir = Path(__file__).resolve().parent.parent
    try:
        result = await asyncio.to_thread(
            subprocess.run,
            [sys.executable, "-m", "alembic", "upgrade", "head"],
            cwd=str(backend_dir),
            check=True,
            capture_output=True,
            text=True,
        )
        logger.info("migrations_applied", stdout=result.stdout.strip())
    except subprocess.CalledProcessError as exc:
        logger.error("migration_failed", stdout=exc.stdout, stderr=exc.stderr)
        raise RuntimeError("Database migrations failed") from exc
