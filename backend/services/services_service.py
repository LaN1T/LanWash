from datetime import datetime

from sqlalchemy import delete, distinct, select
from sqlalchemy.ext.asyncio import AsyncSession

from core.cache import cache
from db_models import ExtraFavorite, Promo, PromoIncludedExtra, Service, ServiceFavorite
from models import ServiceRequest


class ServiceNotFoundError(Exception):
    pass


class ServicesService:
    """Business logic for services, promos, and favorites."""

    def __init__(self, db: AsyncSession) -> None:
        self._db = db

    async def _promo_extras_map(self, promo_ids: list[int]) -> dict[int, list[str]]:
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

    async def get_promos(self) -> list[dict]:
        cache_key = "services:promos"
        cached = await cache.get(cache_key)
        if cached is not None:
            return cached

        result = await self._db.execute(select(Promo))
        promos = list(result.scalars().all())
        extras_map = await self._promo_extras_map([p.id for p in promos])
        data = [
            {
                "id": p.id,
                "washTypeId": p.washTypeId,
                "name": p.name,
                "description": p.description,
                "price": p.price,
                "discountPercent": p.discountPercent,
                "duration": p.duration,
                "weekendOnly": p.weekendOnly,
                "includedExtraIds": extras_map.get(p.id, []),
            }
            for p in promos
        ]
        await cache.set(cache_key, data, ttl=600)
        return data

    async def get_all_services(self) -> list[dict]:
        cache_key = "services:all"
        cached = await cache.get(cache_key)
        if cached is not None:
            return cached

        result = await self._db.execute(
            select(Service).order_by(Service.category.asc(), Service.name.asc())
        )
        services = list(result.scalars().all())
        data = [
            {
                "id": s.id,
                "name": s.name,
                "description": s.description,
                "price": s.price,
                "durationMinutes": s.durationMinutes,
                "category": s.category,
                "isFavorite": bool(s.isFavorite),
                "isFromApi": bool(s.isFromApi),
                "updatedAt": s.updatedAt,
            }
            for s in services
        ]
        await cache.set(cache_key, data, ttl=600)
        return data

    async def get_categories(self) -> list[str]:
        cache_key = "services:categories"
        cached = await cache.get(cache_key)
        if cached is not None:
            return cached

        result = await self._db.execute(
            select(distinct(Service.category)).order_by(Service.category)
        )
        categories = [r[0] for r in result.all()]
        if 'Акции' not in categories:
            categories.append('Акции')
            categories.sort()
        await cache.set(cache_key, categories, ttl=600)
        return categories

    async def _invalidate_service_cache(self) -> None:
        await cache.delete("services:promos")
        await cache.delete("services:all")
        await cache.delete("services:categories")

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
        await self._invalidate_service_cache()
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
        await self._invalidate_service_cache()
        return service

    async def delete_service(self, service_id: str) -> bool:
        result = await self._db.execute(delete(Service).where(Service.id == service_id))
        await self._db.commit()
        if result.rowcount > 0:
            await self._invalidate_service_cache()
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
