from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from models import WashType
from repositories.base import BaseRepository


class WashTypeRepository(BaseRepository[WashType]):
    def __init__(self, db: AsyncSession) -> None:
        super().__init__(db, WashType)

    async def list_all_id_name_map(self) -> dict[str, str]:
        result = await self._db.execute(select(WashType.id, WashType.name))
        return {row[0]: row[1] for row in result.all()}
