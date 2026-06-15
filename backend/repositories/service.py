from sqlalchemy import distinct, select
from sqlalchemy.ext.asyncio import AsyncSession

from models import Service
from repositories.base import BaseRepository


class ServiceRepository(BaseRepository[Service]):
    def __init__(self, db: AsyncSession) -> None:
        super().__init__(db, Service)

    async def list_all_ordered(self) -> list[Service]:
        result = await self._db.execute(
            select(Service).order_by(Service.category.asc(), Service.name.asc())
        )
        return list(result.scalars().all())

    async def list_categories(self) -> list[str]:
        result = await self._db.execute(
            select(distinct(Service.category)).order_by(Service.category)
        )
        categories = [r[0] for r in result.all()]
        if 'Акции' not in categories:
            categories.append('Акции')
            categories.sort()
        return categories

    async def list_all_id_name_map(self) -> dict[str, str]:
        result = await self._db.execute(select(Service.id, Service.name))
        return {row[0]: row[1] for row in result.all()}

    async def list_all_id_name_category_map(self) -> dict[str, tuple[str, str]]:
        result = await self._db.execute(
            select(Service.id, Service.name, Service.category)
        )
        return {row[0]: (row[1], row[2]) for row in result.all()}
