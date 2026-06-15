import structlog
from fastapi import APIRouter, Depends, HTTPException, Request, status
from sqlalchemy.ext.asyncio import AsyncSession

from core.limiter import limiter
from db.session import get_db
from models import User
from schemas import (
    PromoResponse,
    ServiceRequest,
    ServiceResponse,
    ToggleExtraFavoriteRequest,
    ToggleFavoriteRequest,
)
from services.auth_service import check_roles, get_current_user
from services.services_service import ServiceNotFoundError, ServicesService

logger = structlog.get_logger()

router = APIRouter(
    prefix="/api/services",
    tags=["services"],
)


@router.get("/promos", response_model=list[PromoResponse])
@limiter.limit("60/minute")
async def get_promos(request: Request, db: AsyncSession = Depends(get_db), current_user: User = Depends(get_current_user)):
    svc = ServicesService(db)
    return await svc.get_promos()


@router.get("/", response_model=list[ServiceResponse])
@limiter.limit("60/minute")
async def get_all(request: Request, db: AsyncSession = Depends(get_db), current_user: User = Depends(get_current_user)):
    svc = ServicesService(db)
    return await svc.get_all_services()


@router.get("/categories")
@limiter.limit("60/minute")
async def get_categories(request: Request, db: AsyncSession = Depends(get_db), current_user: User = Depends(get_current_user)):
    svc = ServicesService(db)
    return await svc.get_categories()


@router.post("/", response_model=ServiceResponse)
@limiter.limit("10/minute")
async def create(request: Request, req: ServiceRequest, db: AsyncSession = Depends(get_db), current_user: User = Depends(check_roles(['admin']))):
    svc = ServicesService(db)
    return await svc.create_service(req)


@router.put("/{service_id}", response_model=ServiceResponse)
@limiter.limit("10/minute")
async def update_service(request: Request, service_id: str, req: ServiceRequest, db: AsyncSession = Depends(get_db), current_user: User = Depends(check_roles(['admin']))):
    svc = ServicesService(db)
    try:
        return await svc.update_service(service_id, req)
    except ServiceNotFoundError:
        raise HTTPException(404, "Услуга не найдена")


@router.delete("/{service_id}")
@limiter.limit("10/minute")
async def delete_service(request: Request, service_id: str, db: AsyncSession = Depends(get_db), current_user: User = Depends(check_roles(['admin']))):
    svc = ServicesService(db)
    deleted = await svc.delete_service(service_id)
    if not deleted:
        raise HTTPException(404, "Услуга не найдена")
    return {"ok": True}


# ─── Service Favorites ───────────────────────────────────────────────────────
@router.get("/favorites/{username}")
@limiter.limit("60/minute")
async def get_service_favorites(request: Request, username: str, db: AsyncSession = Depends(get_db), current_user: User = Depends(get_current_user)):
    if current_user.username != username.lower() and current_user.role != 'admin':
        raise HTTPException(status.HTTP_403_FORBIDDEN, "У вас нет доступа к чужим избранным услугам")
    svc = ServicesService(db)
    return await svc.get_service_favorites(username.lower())


@router.post("/favorites/toggle")
@limiter.limit("10/minute")
async def toggle_service_favorite(request: Request, req: ToggleFavoriteRequest, db: AsyncSession = Depends(get_db), current_user: User = Depends(get_current_user)):
    if current_user.username != req.username.lower() and current_user.role != 'admin':
        raise HTTPException(status.HTTP_403_FORBIDDEN, "У вас нет прав на изменение чужого избранного")
    svc = ServicesService(db)
    is_fav = await svc.toggle_service_favorite(req.username.lower(), req.serviceId)
    return {"ok": True, "isFavorite": is_fav}


# ─── Extra Favorites (по id доп.услуги) ──────────────────────────────────────
@router.get("/extra-favorites/{username}")
@limiter.limit("60/minute")
async def get_extra_favorites(request: Request, username: str, db: AsyncSession = Depends(get_db), current_user: User = Depends(get_current_user)):
    if current_user.username != username.lower() and current_user.role != 'admin':
        raise HTTPException(status.HTTP_403_FORBIDDEN, "У вас нет доступа к чужим избранным услугам")
    svc = ServicesService(db)
    return await svc.get_extra_favorites(username.lower())


@router.post("/extra-favorites/toggle")
@limiter.limit("10/minute")
async def toggle_extra_favorite(request: Request, req: ToggleExtraFavoriteRequest, db: AsyncSession = Depends(get_db), current_user: User = Depends(get_current_user)):
    if current_user.username != req.username.lower() and current_user.role != 'admin':
        raise HTTPException(status.HTTP_403_FORBIDDEN, "У вас нет прав на изменение чужого избранного")
    svc = ServicesService(db)
    is_fav = await svc.toggle_extra_favorite(req.username.lower(), req.serviceId)
    return {"ok": True, "isFavorite": is_fav}
