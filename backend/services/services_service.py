from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, delete, distinct, func
from sqlalchemy.exc import IntegrityError
from datetime import datetime
from db_models import Service, ServiceFavorite, ExtraFavorite, Promo, PromoIncludedExtra
from models import ServiceRequest


class ServiceNotFoundError(Exception):
    pass


class ServicesService:
    """Business logic for services, promos, and favorites."""

    def __init__(self, db: AsyncSession) -> None:
        self._db = db

    async def get_promos(self) -> list[Promo]:
        result = await self._db.execute(select(Promo))
        return list(result.scalars().all())

    async def get_promo_extras_map(self, promo_ids: list[int]) -> dict[int, list[str]]:
        if not promo_ids:
            return {}
        extras_res = await self._db.execute(
            select(PromoIncludedExtra.promoId, PromoIncludedExtra.extraServiceId)
            .where(PromoIncludedExtra.promoId.in_(promo_ids))
        )
        extras_map: dict[int, list[str]] = {}
        for promo_id, extra_id in extras_res.all():
            extras_map.setdefault(promo_id, []).append(extra_id)
        return extras_map

    async def get_all_services(self) -> list[Service]:
        result = await self._db.execute(
            select(Service).order_by(Service.category.asc(), Service.name.asc())
        )
        return list(result.scalars().all())

    async def get_categories(self) -> list[str]:
        result = await self._db.execute(
            select(distinct(Service.category)).order_by(Service.category)
        )
        categories = [r[0] for r in result.all()]
        if 'Акции' not in categories:
            categories.append('Акции')
            categories.sort()
        return categories

    async def create_service(self, req: ServiceRequest) -> Service:
        new_service = Service(
            id=req.id,
            name=req.name,
            description=req.description,
            price=req.price,
            durationMinutes=req.durationMinutes,
            category=req.category,
            isFavorite=int(req.isFavorite),
            isFromApi=int(req.isFromApi),
            updatedAt=datetime.now().isoformat()
        )
        self._db.add(new_service)
        await self._db.commit()
        await self._db.refresh(new_service)
        return new_service

    async def update_service(self, service_id: str, req: ServiceRequest) -> Service:
        result = await self._db.execute(select(Service).where(Service.id == service_id))
        service = result.scalar_one_or_none()
        if not service:
            raise ServiceNotFoundError()

        service.name = req.name
        service.description = req.description
        service.price = req.price
        service.durationMinutes = req.durationMinutes
        service.category = req.category
        service.isFavorite = int(req.isFavorite)
        service.isFromApi = int(req.isFromApi)
        service.updatedAt = datetime.now().isoformat()

        await self._db.commit()
        await self._db.refresh(service)
        return service

    async def delete_service(self, service_id: str) -> bool:
        result = await self._db.execute(delete(Service).where(Service.id == service_id))
        await self._db.commit()
        return result.rowcount > 0

    async def get_service_favorites(self, username: str) -> list[str]:
        result = await self._db.execute(
            select(ServiceFavorite.serviceId).where(ServiceFavorite.username == username)
        )
        return result.scalars().all()

    async def toggle_service_favorite(self, username: str, service_id: str) -> bool:
        res = await self._db.execute(
            select(ServiceFavorite).where(
                ServiceFavorite.username == username,
                ServiceFavorite.serviceId == service_id,
            )
        )
        fav = res.scalar_one_or_none()
        if fav:
            await self._db.execute(
                delete(ServiceFavorite).where(
                    ServiceFavorite.username == username,
                    ServiceFavorite.serviceId == service_id,
                )
            )
            is_fav = False
        else:
            self._db.add(ServiceFavorite(username=username, serviceId=service_id))
            is_fav = True
        await self._db.commit()
        return is_fav

    async def get_extra_favorites(self, username: str) -> list[str]:
        result = await self._db.execute(
            select(ExtraFavorite.serviceId).where(ExtraFavorite.username == username)
        )
        return result.scalars().all()

    async def toggle_extra_favorite(self, username: str, service_id: str) -> bool:
        res = await self._db.execute(
            select(ExtraFavorite).where(
                ExtraFavorite.username == username,
                ExtraFavorite.serviceId == service_id,
            )
        )
        fav = res.scalar_one_or_none()
        if fav:
            await self._db.execute(
                delete(ExtraFavorite).where(
                    ExtraFavorite.username == username,
                    ExtraFavorite.serviceId == service_id,
                )
            )
            is_fav = False
        else:
            self._db.add(ExtraFavorite(username=username, serviceId=service_id))
            is_fav = True
        await self._db.commit()
        return is_fav
