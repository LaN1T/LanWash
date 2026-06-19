from datetime import datetime

import pytest

from models import LogEntry
from repositories.log_entry import LogEntryRepository


def _log(username: str, action: str, timestamp: str | None = None) -> LogEntry:
    ts = datetime.fromisoformat(timestamp) if timestamp else datetime.now()
    return LogEntry(
        username=username,
        action=action,
        details="",
        timestamp=ts,
    )


class TestLogEntryRepository:
    @pytest.mark.asyncio
    async def test_list_by_user(self, db_session):
        repo = LogEntryRepository(db_session)
        db_session.add_all(
            [
                _log("log_user_a", "login", "2099-01-01T00:00:00"),
                _log("log_user_a", "logout", "2099-01-02T00:00:00"),
                _log("log_user_b", "login", "2099-01-03T00:00:00"),
            ]
        )
        await db_session.flush()

        rows = await repo.list_by_user("log_user_a", limit=10)
        assert len(rows) == 2
        assert rows[0].action == "logout"
        assert rows[1].action == "login"

    @pytest.mark.asyncio
    async def test_list_by_user_pagination(self, db_session):
        repo = LogEntryRepository(db_session)
        db_session.add_all(
            [
                _log("log_user_c", "a", "2099-01-01T00:00:00"),
                _log("log_user_c", "b", "2099-01-02T00:00:00"),
                _log("log_user_c", "c", "2099-01-03T00:00:00"),
            ]
        )
        await db_session.flush()

        rows = await repo.list_by_user("log_user_c", limit=2, offset=0)
        assert len(rows) == 2
        assert rows[0].action == "c"
        assert rows[1].action == "b"

        rows = await repo.list_by_user("log_user_c", limit=2, offset=2)
        assert len(rows) == 1
        assert rows[0].action == "a"

    @pytest.mark.asyncio
    async def test_clear_all(self, db_session):
        repo = LogEntryRepository(db_session)
        db_session.add_all(
            [
                _log("log_user_d", "action1"),
                _log("log_user_e", "action2"),
            ]
        )
        await db_session.flush()

        assert await repo.count() == 2

        deleted = await repo.clear_all()
        await db_session.flush()
        assert deleted == 2
        assert await repo.count() == 0
