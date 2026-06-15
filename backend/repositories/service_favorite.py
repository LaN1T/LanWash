from sqlalchemy import delete, select
from sqlalchemy.ext.asyncio import AsyncSession

from models import ServiceFavorite
from repositories.base import BaseRepository


class ServiceFavoriteRepository(BaseRepository[ServiceFavorite]):
    def __init__(self, db: AsyncSession) -> None:
        super().__init__(db, ServiceFavorite)

    async def list_service_ids_for_user(self, username: str) -> list[str]:
        result = await self._db.execute(
            select(ServiceFavorite.serviceId).where(
                ServiceFavorite.username == username
            )
        )
        return result.scalars().all()

    async def get_favorite(
        self, username: str, service_id: str
    ) -> ServiceFavorite | None:
        result = await self._db.execute(
            select(ServiceFavorite).where(
                ServiceFavorite.username == username,
                ServiceFavorite.serviceId == service_id,
            )
        )
        return result.scalar_one_or_none()

    async def delete_favorite(self, username: str, service_id: str) -> None:
        await self._db.execute(
            delete(ServiceFavorite).where(
                ServiceFavorite.username == username,
                ServiceFavorite.serviceId == service_id,
            )
        )
