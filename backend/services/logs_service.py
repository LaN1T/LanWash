from datetime import datetime
from typing import Optional

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from models import LogEntry, User
from repositories.log_entry import LogEntryRepository

_LOG_ROLES = {"admin", "washer"}


class LogAccessDeniedError(Exception):
    pass


class LogsService:
    """Business logic for log entries."""

    def __init__(self, db: AsyncSession) -> None:
        self._db = db
        self._logs = LogEntryRepository(db)

    async def get_all(
        self,
        limit: int,
        offset: int = 0,
        cursor: Optional[dict] = None,
    ) -> list[LogEntry]:
        return await self._logs.list_all(
            limit=limit, offset=offset, cursor=cursor, roles=list(_LOG_ROLES)
        )

    async def get_by_user(
        self,
        username: str,
        limit: int,
        offset: int = 0,
        cursor: Optional[dict] = None,
    ) -> list[LogEntry]:
        return await self._logs.list_by_user(
            username,
            limit=limit,
            offset=offset,
            cursor=cursor,
            roles=list(_LOG_ROLES),
        )

    async def _is_loggable_user(self, username: str) -> bool:
        result = await self._db.execute(
            select(User.role).where(User.username == username)
        )
        role = result.scalar_one_or_none()
        return role in _LOG_ROLES

    async def create_log(
        self, username: str, action: str, details: str
    ) -> Optional[LogEntry]:
        if not await self._is_loggable_user(username):
            return None
        new_log = LogEntry(
            username=username,
            action=action,
            details=details,
            timestamp=datetime.now(),
        )
        await self._logs.add(new_log)
        await self._db.commit()
        await self._db.refresh(new_log)
        return new_log

    async def clear_all(self) -> None:
        await self._logs.clear_all()
        await self._db.commit()
