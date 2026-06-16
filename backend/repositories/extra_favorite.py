from sqlalchemy import delete, select
from sqlalchemy.ext.asyncio import AsyncSession

from models import ExtraFavorite
from repositories.base import BaseRepository


class ExtraFavoriteRepository(BaseRepository[ExtraFavorite]):
    def __init__(self, db: AsyncSession) -> None:
        super().__init__(db, ExtraFavorite)

    async def list_service_ids_for_user(self, username: str) -> list[str]:
        result = await self._db.execute(
            select(ExtraFavorite.serviceId).where(ExtraFavorite.username == username)
        )
        return result.scalars().all()

    async def get_favorite(
        self, username: str, service_id: str
    ) -> ExtraFavorite | None:
        result = await self._db.execute(
            select(ExtraFavorite).where(
                ExtraFavorite.username == username,
                ExtraFavorite.serviceId == service_id,
            )
        )
        return result.scalar_one_or_none()

    async def delete_favorite(self, username: str, service_id: str) -> None:
        await self._db.execute(
            delete(ExtraFavorite).where(
                ExtraFavorite.username == username,
                ExtraFavorite.serviceId == service_id,
            )
        )
