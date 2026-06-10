from datetime import datetime

from sqlalchemy import delete, func, select, update
from sqlalchemy.ext.asyncio import AsyncSession

from db_models import WasherNote


class NoteAccessDeniedError(Exception):
    pass


class NotesService:
    """Business logic for washer notes."""

    def __init__(self, db: AsyncSession) -> None:
        self._db = db

    async def get_all(self, limit: int) -> list[WasherNote]:
        result = await self._db.execute(
            select(WasherNote)
            .order_by(WasherNote.createdAt.desc())
            .limit(limit)
        )
        return list(result.scalars().all())

    async def get_by_user(self, username: str, limit: int) -> list[WasherNote]:
        result = await self._db.execute(
            select(WasherNote)
            .where(WasherNote.username == username)
            .order_by(WasherNote.createdAt.desc())
            .limit(limit)
        )
        return list(result.scalars().all())

    async def unread_count(self) -> int:
        result = await self._db.execute(
            select(func.count(WasherNote.id)).where(WasherNote.isRead == 0)
        )
        return result.scalar() or 0

    async def create_note(self, username: str, title: str, message: str, category: str) -> WasherNote:
        new_note = WasherNote(
            username=username,
            title=title,
            message=message,
            category=category,
            isRead=0,
            createdAt=datetime.now().isoformat()
        )
        self._db.add(new_note)
        await self._db.commit()
        await self._db.refresh(new_note)
        return new_note

    async def mark_read(self, note_id: int) -> None:
        await self._db.execute(
            update(WasherNote).where(WasherNote.id == note_id).values(isRead=1)
        )
        await self._db.commit()

    async def mark_all_read(self) -> None:
        await self._db.execute(update(WasherNote).values(isRead=1))
        await self._db.commit()

    async def delete_note(self, note_id: int) -> None:
        await self._db.execute(delete(WasherNote).where(WasherNote.id == note_id))
        await self._db.commit()
