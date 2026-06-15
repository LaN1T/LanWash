from sqlalchemy import delete, select
from sqlalchemy.ext.asyncio import AsyncSession

from models import LogEntry
from repositories.base import BaseRepository


class LogEntryRepository(BaseRepository[LogEntry]):
    def __init__(self, db: AsyncSession) -> None:
        super().__init__(db, LogEntry)

    async def list_all(self, limit: int, offset: int = 0) -> list[LogEntry]:
        result = await self._db.execute(
            select(LogEntry)
            .order_by(LogEntry.timestamp.desc())
            .offset(offset)
            .limit(limit)
        )
        return list(result.scalars().all())

    async def list_by_user(self, username: str, limit: int, offset: int = 0) -> list[LogEntry]:
        result = await self._db.execute(
            select(LogEntry)
            .where(LogEntry.username == username)
            .order_by(LogEntry.timestamp.desc())
            .offset(offset)
            .limit(limit)
        )
        return list(result.scalars().all())

    async def clear_all(self) -> int:
        result = await self._db.execute(delete(LogEntry))
        return result.rowcount
