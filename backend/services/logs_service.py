from datetime import datetime

from db_models import LogEntry
from sqlalchemy import delete, select
from sqlalchemy.ext.asyncio import AsyncSession


class LogAccessDeniedError(Exception):
    pass


class LogsService:
    """Business logic for log entries."""

    def __init__(self, db: AsyncSession) -> None:
        self._db = db

    async def get_all(self, limit: int, offset: int = 0) -> list[LogEntry]:
        result = await self._db.execute(
            select(LogEntry)
            .order_by(LogEntry.timestamp.desc())
            .offset(offset)
            .limit(limit)
        )
        return list(result.scalars().all())

    async def get_by_user(
        self, username: str, limit: int, offset: int = 0
    ) -> list[LogEntry]:
        result = await self._db.execute(
            select(LogEntry)
            .where(LogEntry.username == username)
            .order_by(LogEntry.timestamp.desc())
            .offset(offset)
            .limit(limit)
        )
        return list(result.scalars().all())

    async def create_log(self, username: str, action: str, details: str) -> LogEntry:
        new_log = LogEntry(
            username=username,
            action=action,
            details=details,
            timestamp=datetime.now().isoformat(),
        )
        self._db.add(new_log)
        await self._db.commit()
        await self._db.refresh(new_log)
        return new_log

    async def clear_all(self) -> None:
        await self._db.execute(delete(LogEntry))
        await self._db.commit()
