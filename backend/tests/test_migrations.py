import os
import tempfile
from pathlib import Path

from alembic import command
from alembic.config import Config

from core.config import get_settings


def test_alembic_migrations_run_on_sqlite() -> None:
    """All Alembic migrations must apply cleanly to an empty SQLite database."""
    settings = get_settings()
    backend_dir = Path(__file__).resolve().parent.parent

    with tempfile.TemporaryDirectory() as tmpdir:
        db_path = os.path.join(tmpdir, "migrate_test.db")
        original_url = settings.database_url
        settings.database_url = f"sqlite+aiosqlite:///{db_path}"
        try:
            cfg = Config(str(backend_dir / "alembic.ini"))
            command.upgrade(cfg, "head")
            command.downgrade(cfg, "base")
        finally:
            settings.database_url = original_url
