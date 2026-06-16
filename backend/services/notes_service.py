from datetime import datetime

from sqlalchemy.ext.asyncio import AsyncSession

from models import WasherNote
from repositories.washer_note import WasherNoteRepository


class NoteAccessDeniedError(Exception):
    pass


class NotesService:
    """Business logic for washer notes."""

    def __init__(self, db: AsyncSession) -> None:
        self._db = db
        self._notes = WasherNoteRepository(db)

    async def get_all(self, limit: int, offset: int = 0) -> list[WasherNote]:
        return await self._notes.list_all(limit=limit, offset=offset)

    async def get_by_user(
        self, username: str, limit: int, offset: int = 0
    ) -> list[WasherNote]:
        return await self._notes.list_by_user(username, limit=limit, offset=offset)

    async def unread_count(self) -> int:
        return await self._notes.unread_count()

    async def create_note(
        self, username: str, title: str, message: str, category: str
    ) -> WasherNote:
        new_note = WasherNote(
            username=username,
            title=title,
            message=message,
            category=category,
            isRead=0,
            createdAt=datetime.now().isoformat(),
        )
        await self._notes.add(new_note)
        await self._db.commit()
        await self._db.refresh(new_note)
        return new_note

    async def mark_read(self, note_id: int) -> None:
        await self._notes.mark_read(note_id)
        await self._db.commit()

    async def mark_all_read(self) -> None:
        await self._notes.mark_all_read()
        await self._db.commit()

    async def delete_note(self, note_id: int) -> None:
        await self._notes.delete_by_id(note_id)
        await self._db.commit()
