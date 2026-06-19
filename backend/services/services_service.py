from datetime import datetime

from sqlalchemy.ext.asyncio import AsyncSession

from core.cache import cache
from models import ExtraFavorite, Service, ServiceFavorite
from repositories.extra_favorite import ExtraFavoriteRepository
from repositories.promo import PromoRepository
from repositories.promo_included_extra import PromoIncludedExtraRepository
from repositories.service import ServiceRepository
from repositories.service_favorite import ServiceFavoriteRepository
from schemas import ServiceRequest


class ServiceNotFoundError(Exception):
    pass


class ServicesService:
    """Business logic for services, promos, and favorites."""

    def __init__(self, db: AsyncSession) -> None:
        self._db = db
        self._services = ServiceRepository(db)
        self._promos = PromoRepository(db)
        self._promo_extras = PromoIncludedExtraRepository(db)
        self._service_favorites = ServiceFavoriteRepository(db)
        self._extra_favorites = ExtraFavoriteRepository(db)

    async def get_promos(self) -> list[dict]:
        cache_key = "services:promos"
        cached = await cache.get(cache_key)
        if cached is not None:
            return cached

        promos = await self._promos.list_all()
        extras_map = await self._promo_extras.list_extras_for_promos(
            [p.id for p in promos]
        )
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

        services = await self._services.list_all_ordered()
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

        categories = await self._services.list_categories()
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
            updatedAt=datetime.now(),
        )
        await self._services.add(new_service)
        await self._db.commit()
        await self._db.refresh(new_service)
        await self._invalidate_service_cache()
        return new_service

    async def update_service(self, service_id: str, req: ServiceRequest) -> Service:
        service = await self._services.get_by_id(service_id)
        if not service:
            raise ServiceNotFoundError()

        service.name = req.name
        service.description = req.description
        service.price = req.price
        service.durationMinutes = req.durationMinutes
        service.category = req.category
        service.isFavorite = int(req.isFavorite)
        service.isFromApi = int(req.isFromApi)
        service.updatedAt = datetime.now()

        await self._db.commit()
        await self._db.refresh(service)
        await self._invalidate_service_cache()
        return service

    async def delete_service(self, service_id: str) -> bool:
        deleted = await self._services.delete_by_id(service_id)
        await self._db.commit()
        if deleted:
            await self._invalidate_service_cache()
        return deleted

    async def get_service_favorites(self, username: str) -> list[str]:
        return await self._service_favorites.list_service_ids_for_user(username)

    async def toggle_service_favorite(self, username: str, service_id: str) -> bool:
        fav = await self._service_favorites.get_favorite(username, service_id)
        if fav:
            await self._service_favorites.delete_favorite(username, service_id)
            is_fav = False
        else:
            await self._service_favorites.add(
                ServiceFavorite(username=username, serviceId=service_id)
            )
            is_fav = True
        await self._db.commit()
        return is_fav

    async def get_extra_favorites(self, username: str) -> list[str]:
        return await self._extra_favorites.list_service_ids_for_user(username)

    async def toggle_extra_favorite(self, username: str, service_id: str) -> bool:
        fav = await self._extra_favorites.get_favorite(username, service_id)
        if fav:
            await self._extra_favorites.delete_favorite(username, service_id)
            is_fav = False
        else:
            await self._extra_favorites.add(
                ExtraFavorite(username=username, serviceId=service_id)
            )
            is_fav = True
        await self._db.commit()
        return is_fav
