from sqlalchemy.ext.asyncio import AsyncSession

from models import WasherNote
from repositories.base import BaseRepository


class WasherNoteRepository(BaseRepository[WasherNote]):
    def __init__(self, db: AsyncSession) -> None:
        super().__init__(db, WasherNote)
