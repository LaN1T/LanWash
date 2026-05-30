from fastapi import APIRouter, HTTPException, Depends, status, Request
from sqlalchemy.ext.asyncio import AsyncSession
from core.limiter import limiter
from sqlalchemy import select, delete, distinct
from database import get_db
from models import ServiceRequest, ServiceResponse, ToggleFavoriteRequest, ToggleExtraFavoriteRequest, PromoResponse
from db_models import Service, ServiceFavorite, ExtraFavorite, Promo, PromoIncludedExtra, User
from datetime import datetime
from services.auth_service import get_current_user, check_roles

router = APIRouter(
    prefix="/api/services",
    tags=["services"],
    
)

@router.get("/promos", response_model=list[PromoResponse])
@limiter.limit("60/minute")
async def get_promos(request: Request, db: AsyncSession = Depends(get_db), current_user: User = Depends(get_current_user)):
    result = await db.execute(select(Promo))
    promos = result.scalars().all()
    out = []
    for p in promos:
        extras_res = await db.execute(
            select(PromoIncludedExtra.extraServiceId).where(PromoIncludedExtra.promoId == p.id)
        )
        out.append({
            "id": p.id,
            "washTypeId": p.washTypeId,
            "name": p.name,
            "description": p.description,
            "price": p.price,
            "discountPercent": p.discountPercent,
            "duration": p.duration,
            "weekendOnly": p.weekendOnly,
            "includedExtraIds": [r[0] for r in extras_res.all()],
        })
    return out

@router.get("/", response_model=list[ServiceResponse])
@limiter.limit("60/minute")
async def get_all(request: Request, db: AsyncSession = Depends(get_db), current_user: User = Depends(get_current_user)):
    result = await db.execute(select(Service).order_by(Service.category.asc(), Service.name.asc()))
    return result.scalars().all()

@router.get("/categories")
@limiter.limit("60/minute")
async def get_categories(request: Request, db: AsyncSession = Depends(get_db), current_user: User = Depends(get_current_user)):
    result = await db.execute(select(distinct(Service.category)).order_by(Service.category))
    categories = [r[0] for r in result.all()]
    if 'Акции' not in categories:
        categories.append('Акции')
        categories.sort()
    return categories

@router.post("/", response_model=ServiceResponse)
@limiter.limit("10/minute")
async def create(request: Request, req: ServiceRequest, db: AsyncSession = Depends(get_db), current_user: User = Depends(check_roles(['admin']))):
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
    db.add(new_service)
    await db.commit()
    await db.refresh(new_service)
    return new_service

@router.put("/{service_id}", response_model=ServiceResponse)
@limiter.limit("10/minute")
async def update_service(request: Request, service_id: str, req: ServiceRequest, db: AsyncSession = Depends(get_db), current_user: User = Depends(check_roles(['admin']))):
    result = await db.execute(select(Service).where(Service.id == service_id))
    service = result.scalar_one_or_none()
    if not service:
        raise HTTPException(404, "Услуга не найдена")

    service.name = req.name
    service.description = req.description
    service.price = req.price
    service.durationMinutes = req.durationMinutes
    service.category = req.category
    service.isFavorite = int(req.isFavorite)
    service.isFromApi = int(req.isFromApi)
    service.updatedAt = datetime.now().isoformat()

    await db.commit()
    await db.refresh(service)
    return service

@router.delete("/{service_id}")
@limiter.limit("10/minute")
async def delete_service(request: Request, service_id: str, db: AsyncSession = Depends(get_db), current_user: User = Depends(check_roles(['admin']))):
    result = await db.execute(delete(Service).where(Service.id == service_id))
    await db.commit()
    if result.rowcount == 0:
        raise HTTPException(404, "Услуга не найдена")
    return {"ok": True}

# ─── Service Favorites ───────────────────────────────────────────────────────
@router.get("/favorites/{username}")
@limiter.limit("60/minute")
async def get_service_favorites(request: Request, username: str, db: AsyncSession = Depends(get_db), current_user: User = Depends(get_current_user)):
    if current_user.username != username.lower() and current_user.role != 'admin':
        raise HTTPException(status.HTTP_403_FORBIDDEN, "У вас нет доступа к чужим избранным услугам")
    result = await db.execute(select(ServiceFavorite.serviceId).where(ServiceFavorite.username == username.lower()))
    return result.scalars().all()

@router.post("/favorites/toggle")
@limiter.limit("10/minute")
async def toggle_service_favorite(request: Request, req: ToggleFavoriteRequest, db: AsyncSession = Depends(get_db), current_user: User = Depends(get_current_user)):
    if current_user.username != req.username.lower() and current_user.role != 'admin':
        raise HTTPException(status.HTTP_403_FORBIDDEN, "У вас нет прав на изменение чужого избранного")
    username = req.username.lower()
    res = await db.execute(select(ServiceFavorite).where(ServiceFavorite.username == username, ServiceFavorite.serviceId == req.serviceId))
    fav = res.scalar_one_or_none()
    if fav:
        await db.execute(delete(ServiceFavorite).where(ServiceFavorite.username == username, ServiceFavorite.serviceId == req.serviceId))
        is_fav = False
    else:
        db.add(ServiceFavorite(username=username, serviceId=req.serviceId))
        is_fav = True
    await db.commit()
    return {"ok": True, "isFavorite": is_fav}

# ─── Extra Favorites (по id доп.услуги) ──────────────────────────────────────
@router.get("/extra-favorites/{username}")
@limiter.limit("60/minute")
async def get_extra_favorites(request: Request, username: str, db: AsyncSession = Depends(get_db), current_user: User = Depends(get_current_user)):
    if current_user.username != username.lower() and current_user.role != 'admin':
        raise HTTPException(status.HTTP_403_FORBIDDEN, "У вас нет доступа к чужим избранным услугам")
    result = await db.execute(select(ExtraFavorite.serviceId).where(ExtraFavorite.username == username.lower()))
    return result.scalars().all()

@router.post("/extra-favorites/toggle")
@limiter.limit("10/minute")
async def toggle_extra_favorite(request: Request, req: ToggleExtraFavoriteRequest, db: AsyncSession = Depends(get_db), current_user: User = Depends(get_current_user)):
    if current_user.username != req.username.lower() and current_user.role != 'admin':
        raise HTTPException(status.HTTP_403_FORBIDDEN, "У вас нет прав на изменение чужого избранного")
    username = req.username.lower()
    res = await db.execute(select(ExtraFavorite).where(ExtraFavorite.username == username, ExtraFavorite.serviceId == req.serviceId))
    fav = res.scalar_one_or_none()
    if fav:
        await db.execute(delete(ExtraFavorite).where(ExtraFavorite.username == username, ExtraFavorite.serviceId == req.serviceId))
        is_fav = False
    else:
        db.add(ExtraFavorite(username=username, serviceId=req.serviceId))
        is_fav = True
    await db.commit()
    return {"ok": True, "isFavorite": is_fav}
