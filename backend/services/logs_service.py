from datetime import datetime

from sqlalchemy.ext.asyncio import AsyncSession

from models import LogEntry
from repositories.log_entry import LogEntryRepository


class LogAccessDeniedError(Exception):
    pass


class LogsService:
    """Business logic for log entries."""

    def __init__(self, db: AsyncSession) -> None:
        self._db = db
        self._logs = LogEntryRepository(db)

    async def get_all(self, limit: int, offset: int = 0) -> list[LogEntry]:
        return await self._logs.list_all(limit=limit, offset=offset)

    async def get_by_user(self, username: str, limit: int, offset: int = 0) -> list[LogEntry]:
        return await self._logs.list_by_user(username, limit=limit, offset=offset)

    async def create_log(self, username: str, action: str, details: str) -> LogEntry:
        new_log = LogEntry(
            username=username,
            action=action,
            details=details,
            timestamp=datetime.now().isoformat()
        )
        await self._logs.add(new_log)
        await self._db.commit()
        await self._db.refresh(new_log)
        return new_log

    async def clear_all(self) -> None:
        await self._logs.clear_all()
        await self._db.commit()
