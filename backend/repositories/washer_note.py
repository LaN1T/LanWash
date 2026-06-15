from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession

from models import WasherNote
from repositories.base import BaseRepository


class WasherNoteRepository(BaseRepository[WasherNote]):
    def __init__(self, db: AsyncSession) -> None:
        super().__init__(db, WasherNote)

    async def list_all(self, limit: int, offset: int = 0) -> list[WasherNote]:
        result = await self._db.execute(
            select(WasherNote)
            .order_by(WasherNote.createdAt.desc())
            .offset(offset)
            .limit(limit)
        )
        return list(result.scalars().all())

    async def list_by_user(self, username: str, limit: int, offset: int = 0) -> list[WasherNote]:
        result = await self._db.execute(
            select(WasherNote)
            .where(WasherNote.username == username)
            .order_by(WasherNote.createdAt.desc())
            .offset(offset)
            .limit(limit)
        )
        return list(result.scalars().all())

    async def unread_count(self) -> int:
        result = await self._db.execute(
            select(func.count(WasherNote.id)).where(WasherNote.isRead == 0)
        )
        return result.scalar() or 0
