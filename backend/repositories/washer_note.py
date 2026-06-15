from sqlalchemy import delete, func, select, update
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

    async def mark_read(self, note_id: int) -> int:
        result = await self._db.execute(
            update(WasherNote)
            .where(WasherNote.id == note_id)
            .values(isRead=1)
        )
        return result.rowcount

    async def mark_all_read(self) -> int:
        result = await self._db.execute(update(WasherNote).values(isRead=1))
        return result.rowcount

    async def delete_by_id(self, note_id: int) -> bool:
        result = await self._db.execute(
            delete(WasherNote).where(WasherNote.id == note_id)
        )
        return result.rowcount > 0
