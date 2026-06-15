from sqlalchemy.ext.asyncio import AsyncSession

from models import LogEntry
from repositories.base import BaseRepository


class LogEntryRepository(BaseRepository[LogEntry]):
    def __init__(self, db: AsyncSession) -> None:
        super().__init__(db, LogEntry)
