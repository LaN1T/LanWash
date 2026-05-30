import uuid
from fastapi import APIRouter, HTTPException, Depends, Request
from sqlalchemy.ext.asyncio import AsyncSession
from core.limiter import limiter
from sqlalchemy import select, update, delete
from database import get_db
from models import (
    ConsumableRequest, ConsumableResponse, ServiceConsumableRequest,
    ServiceConsumableResponse, RefillRequest,
)
from db_models import Consumable, ServiceConsumable, Service, User
from services.auth_service import get_current_user, check_roles

router = APIRouter(
    prefix="/api/consumables",
    tags=["consumables"],
    dependencies=[Depends(check_roles(['admin', 'washer']))],
    
)

@router.get("/", response_model=list[ConsumableResponse])
@limiter.limit("60/minute")
async def get_all_consumables(request: Request, db: AsyncSession = Depends(get_db)):
    result = await db.execute(select(Consumable).order_by(Consumable.name.asc()))
    return result.scalars().all()

@router.get("/by-service/{service_id}", response_model=list[ServiceConsumableResponse])
@limiter.limit("60/minute")
async def get_consumables_by_service(request: Request, service_id: str, db: AsyncSession = Depends(get_db)):
    result = await db.execute(select(ServiceConsumable).where(ServiceConsumable.serviceId == service_id).order_by(ServiceConsumable.consumableId.asc()))
    return result.scalars().all()

@router.get("/{consumable_id}", response_model=ConsumableResponse)
@limiter.limit("60/minute")
async def get_consumable(request: Request, consumable_id: str, db: AsyncSession = Depends(get_db)):
    result = await db.execute(select(Consumable).where(Consumable.id == consumable_id))
    consumable = result.scalar_one_or_none()
    if not consumable:
        raise HTTPException(404, "Расходник не найден")
    return consumable

@router.post("/", response_model=ConsumableResponse)
@limiter.limit("10/minute")
async def create_consumable(request: Request, req: ConsumableRequest, db: AsyncSession = Depends(get_db)):
    new_consumable = Consumable(id=str(uuid.uuid4()), name=req.name, unit=req.unit)
    db.add(new_consumable)
    await db.commit()
    await db.refresh(new_consumable)
    return new_consumable

@router.put("/{consumable_id}", response_model=ConsumableResponse)
@limiter.limit("10/minute")
async def update_consumable(request: Request, consumable_id: str, req: ConsumableRequest, db: AsyncSession = Depends(get_db)):
    result = await db.execute(update(Consumable).where(Consumable.id == consumable_id).values(name=req.name, unit=req.unit))
    await db.commit()
    if result.rowcount == 0:
        raise HTTPException(404, "Расходник не найден")
    return await get_consumable(request, consumable_id, db)

@router.delete("/{consumable_id}")
@limiter.limit("10/minute")
async def delete_consumable(request: Request, consumable_id: str, db: AsyncSession = Depends(get_db)):
    await db.execute(delete(ServiceConsumable).where(ServiceConsumable.consumableId == consumable_id))
    result = await db.execute(delete(Consumable).where(Consumable.id == consumable_id))
    await db.commit()
    if result.rowcount == 0:
        raise HTTPException(404, "Расходник не найден")
    return {"ok": True}

@router.post("/{consumable_id}/refill", response_model=ConsumableResponse)
@limiter.limit("10/minute")
async def refill_consumable(request: Request, consumable_id: str, req: RefillRequest, db: AsyncSession = Depends(get_db)):
    result = await db.execute(select(Consumable).where(Consumable.id == consumable_id))
    consumable = result.scalar_one_or_none()
    if not consumable:
        raise HTTPException(404, "Расходник не найден")
    consumable.currentStock += req.amount
    await db.commit()
    await db.refresh(consumable)
    return consumable

@router.get("/alerts/low-stock", response_model=list[ConsumableResponse])
@limiter.limit("60/minute")
async def get_low_stock_alerts(request: Request, db: AsyncSession = Depends(get_db)):
    result = await db.execute(
        select(Consumable).where(Consumable.currentStock < Consumable.minStock).order_by(Consumable.name.asc())
    )
    return result.scalars().all()

@router.post("/service-link", response_model=ServiceConsumableResponse)
@limiter.limit("10/minute")
async def link_consumable_to_service(request: Request, req: ServiceConsumableRequest, db: AsyncSession = Depends(get_db)):
    # Проверка существования service и consumable
    res_s = await db.execute(select(Service).where(Service.id == req.serviceId))
    if not res_s.scalar_one_or_none():
        raise HTTPException(404, f"Услуга с id={req.serviceId} не найдена")

    res_c = await db.execute(select(Consumable).where(Consumable.id == req.consumableId))
    if not res_c.scalar_one_or_none():
        raise HTTPException(404, f"Расходник с id={req.consumableId} не найден")

    # В SQLAlchemy upsert для простых таблиц
    existing = await db.execute(select(ServiceConsumable).where(ServiceConsumable.serviceId == req.serviceId, ServiceConsumable.consumableId == req.consumableId))
    link = existing.scalar_one_or_none()
    if link:
        link.quantity_per_service = req.quantity_per_service
    else:
        db.add(ServiceConsumable(serviceId=req.serviceId, consumableId=req.consumableId, quantity_per_service=req.quantity_per_service))
    
    await db.commit()
    return {"serviceId": req.serviceId, "consumableId": req.consumableId, "quantity_per_service": req.quantity_per_service}

@router.delete("/service-link/{service_id}/{consumable_id}")
@limiter.limit("10/minute")
async def unlink_consumable_from_service(request: Request, service_id: str, consumable_id: str, db: AsyncSession = Depends(get_db)):
    result = await db.execute(delete(ServiceConsumable).where(ServiceConsumable.serviceId == service_id, ServiceConsumable.consumableId == consumable_id))
    await db.commit()
    if result.rowcount == 0:
        raise HTTPException(404, "Связь расходника и услуги не найдена")
    return {"ok": True}
