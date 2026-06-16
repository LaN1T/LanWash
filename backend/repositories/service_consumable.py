from sqlalchemy import delete, select
from sqlalchemy.ext.asyncio import AsyncSession

from models import ServiceConsumable
from repositories.base import BaseRepository


class ServiceConsumableRepository(BaseRepository[ServiceConsumable]):
    def __init__(self, db: AsyncSession) -> None:
        super().__init__(db, ServiceConsumable)

    async def list_by_service(self, service_id: str) -> list[ServiceConsumable]:
        result = await self._db.execute(
            select(ServiceConsumable)
            .where(ServiceConsumable.serviceId == service_id)
            .order_by(ServiceConsumable.consumableId.asc())
        )
        return list(result.scalars().all())

    async def get_by_service_and_consumable(
        self, service_id: str, consumable_id: str
    ) -> ServiceConsumable | None:
        result = await self._db.execute(
            select(ServiceConsumable).where(
                ServiceConsumable.serviceId == service_id,
                ServiceConsumable.consumableId == consumable_id,
            )
        )
        return result.scalar_one_or_none()

    async def delete_by_consumable_id(self, consumable_id: str) -> int:
        result = await self._db.execute(
            delete(ServiceConsumable).where(
                ServiceConsumable.consumableId == consumable_id
            )
        )
        return result.rowcount

    async def delete_by_service_and_consumable(
        self, service_id: str, consumable_id: str
    ) -> bool:
        result = await self._db.execute(
            delete(ServiceConsumable).where(
                ServiceConsumable.serviceId == service_id,
                ServiceConsumable.consumableId == consumable_id,
            )
        )
        return result.rowcount > 0

    async def list_for_services(
        self, service_ids: set[str] | list[str]
    ) -> list[ServiceConsumable]:
        if not service_ids:
            return []
        result = await self._db.execute(
            select(ServiceConsumable).where(
                ServiceConsumable.serviceId.in_(service_ids)
            )
        )
        return list(result.scalars().all())

    async def list_all_service_consumable_pairs(self) -> list[tuple[str, str]]:
        result = await self._db.execute(
            select(ServiceConsumable.serviceId, ServiceConsumable.consumableId)
        )
        return list(result.all())
