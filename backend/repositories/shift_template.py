from sqlalchemy import select, update
from sqlalchemy.ext.asyncio import AsyncSession

from models import ShiftTemplate
from repositories.base import BaseRepository


class ShiftTemplateRepository(BaseRepository[ShiftTemplate]):
    def __init__(self, db: AsyncSession) -> None:
        super().__init__(db, ShiftTemplate)

    async def list_for_owner(self, owner_username: str, include_all: bool = False) -> list[ShiftTemplate]:
        stmt = select(ShiftTemplate)
        if not include_all:
            stmt = stmt.where(ShiftTemplate.ownerUsername == owner_username)
        stmt = stmt.order_by(ShiftTemplate.name)
        result = await self._db.execute(stmt)
        return list(result.scalars().all())

    async def clear_owner_default(self, owner_username: str) -> None:
        await self._db.execute(
            update(ShiftTemplate)
            .where(
                ShiftTemplate.ownerUsername == owner_username,
                ShiftTemplate.isDefault.is_(True),
            )
            .values(isDefault=False)
            .execution_options(synchronize_session="fetch")
        )
