from sqlalchemy.ext.asyncio import AsyncSession

from models import ShiftTemplate
from repositories.base import BaseRepository


class ShiftTemplateRepository(BaseRepository[ShiftTemplate]):
    def __init__(self, db: AsyncSession) -> None:
        super().__init__(db, ShiftTemplate)
