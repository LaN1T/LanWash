from datetime import datetime

import pytest

from models import WasherNote
from repositories.washer_note import WasherNoteRepository


def _note(username: str, title: str = "Title", is_read: int = 0) -> WasherNote:
    return WasherNote(
        username=username,
        title=title,
        message="message",
        isRead=is_read,
        createdAt=datetime.now().isoformat(),
    )


class TestWasherNoteRepository:
    @pytest.mark.asyncio
    async def test_mark_read(self, db_session):
        repo = WasherNoteRepository(db_session)
        note = _note("washer_mark_read")
        db_session.add(note)
        await db_session.flush()

        rowcount = await repo.mark_read(note.id)
        await db_session.flush()

        assert rowcount == 1
        updated = await db_session.get(WasherNote, note.id)
        assert updated.isRead == 1

    @pytest.mark.asyncio
    async def test_mark_read_missing_returns_zero(self, db_session):
        repo = WasherNoteRepository(db_session)
        assert await repo.mark_read(999999) == 0

    @pytest.mark.asyncio
    async def test_mark_all_read(self, db_session):
        repo = WasherNoteRepository(db_session)
        notes = [
            _note("washer_all_1", is_read=0),
            _note("washer_all_2", is_read=0),
            _note("washer_all_3", is_read=1),
        ]
        db_session.add_all(notes)
        await db_session.flush()

        rowcount = await repo.mark_all_read()
        await db_session.flush()

        assert rowcount == 3
        for note in notes:
            refreshed = await db_session.get(WasherNote, note.id)
            assert refreshed.isRead == 1

    @pytest.mark.asyncio
    async def test_delete_by_id(self, db_session):
        repo = WasherNoteRepository(db_session)
        note = _note("washer_delete")
        db_session.add(note)
        await db_session.flush()

        rowcount = await repo.delete_by_id(note.id)
        await db_session.flush()

        assert rowcount == 1
        assert await db_session.get(WasherNote, note.id) is None

    @pytest.mark.asyncio
    async def test_delete_by_id_missing_returns_zero(self, db_session):
        repo = WasherNoteRepository(db_session)
        assert await repo.delete_by_id(999999) == 0
