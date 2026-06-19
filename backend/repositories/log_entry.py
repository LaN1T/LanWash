from typing import Optional

from sqlalchemy import and_, delete, or_, select
from sqlalchemy.ext.asyncio import AsyncSession

from models import LogEntry
from repositories.base import BaseRepository

_UNSET = object()


class LogEntryRepository(BaseRepository[LogEntry]):
    def __init__(self, db: AsyncSession) -> None:
        super().__init__(db, LogEntry)

    def _cursor_clause(self, cursor: dict):
        return or_(
            LogEntry.timestamp < cursor["t"],
            and_(
                LogEntry.timestamp == cursor["t"],
                LogEntry.id < cursor["id"],
            ),
        )

    async def list_all(
        self,
        limit: int,
        offset: int = 0,
        cursor: Optional[dict] = _UNSET,
    ) -> list[LogEntry]:
        use_cursor = cursor is not _UNSET
        if cursor is _UNSET:
            cursor = None
        stmt = select(LogEntry).order_by(LogEntry.timestamp.desc(), LogEntry.id.desc())
        if cursor:
            stmt = stmt.where(self._cursor_clause(cursor))
        if use_cursor:
            stmt = stmt.limit(limit + 1)
        else:
            stmt = stmt.offset(offset).limit(limit)
        result = await self._db.execute(stmt)
        return list(result.scalars().all())

    async def list_by_user(
        self,
        username: str,
        limit: int,
        offset: int = 0,
        cursor: Optional[dict] = _UNSET,
    ) -> list[LogEntry]:
        use_cursor = cursor is not _UNSET
        if cursor is _UNSET:
            cursor = None
        stmt = (
            select(LogEntry)
            .where(LogEntry.username == username)
            .order_by(LogEntry.timestamp.desc(), LogEntry.id.desc())
        )
        if cursor:
            stmt = stmt.where(self._cursor_clause(cursor))
        if use_cursor:
            stmt = stmt.limit(limit + 1)
        else:
            stmt = stmt.offset(offset).limit(limit)
        result = await self._db.execute(stmt)
        return list(result.scalars().all())

    async def clear_all(self) -> int:
        result = await self._db.execute(delete(LogEntry))
        return result.rowcount
