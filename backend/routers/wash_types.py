from fastapi import APIRouter, HTTPException, Depends, status, Request
from sqlalchemy.ext.asyncio import AsyncSession
from core.limiter import limiter
from sqlalchemy import select, delete
from database import get_db
from db_models import WashType, WashTypeIncludedExtra, User
from models import WashTypeRequest, WashTypeResponse
from services.auth_service import get_current_user, check_roles

router = APIRouter(
    prefix="/api/wash-types",
    tags=["wash-types"],
    
)


async def _to_response(wt: WashType, extras_map: dict[str, list[str]]) -> dict:
    return {
        "id": wt.id,
        "code": wt.code,
        "name": wt.name,
        "description": wt.description,
        "basePrice": wt.basePrice,
        "durationMinutes": wt.durationMinutes,
        "sortOrder": wt.sortOrder,
        "includedExtraIds": extras_map.get(wt.id, []),
    }


@router.get("/", response_model=list[WashTypeResponse])
@limiter.limit("60/minute")
async def get_all(request: Request, db: AsyncSession = Depends(get_db), current_user: User = Depends(get_current_user)):
    result = await db.execute(select(WashType).order_by(WashType.sortOrder.asc()))
    wash_types = result.scalars().all()
    if not wash_types:
        return []

    wt_ids = [wt.id for wt in wash_types]
    extras_res = await db.execute(
        select(WashTypeIncludedExtra.washTypeId, WashTypeIncludedExtra.extraServiceId)
        .where(WashTypeIncludedExtra.washTypeId.in_(wt_ids))
    )
    extras_map: dict[str, list[str]] = {}
    for wt_id, extra_id in extras_res.all():
        extras_map.setdefault(wt_id, []).append(extra_id)

    return [_to_response(wt, extras_map) for wt in wash_types]


async def _to_response_single(db: AsyncSession, wt: WashType) -> dict:
    res = await db.execute(
        select(WashTypeIncludedExtra.extraServiceId)
        .where(WashTypeIncludedExtra.washTypeId == wt.id)
    )
    return {
        "id": wt.id,
        "code": wt.code,
        "name": wt.name,
        "description": wt.description,
        "basePrice": wt.basePrice,
        "durationMinutes": wt.durationMinutes,
        "sortOrder": wt.sortOrder,
        "includedExtraIds": [r[0] for r in res.all()],
    }


@router.get("/{wash_type_id}", response_model=WashTypeResponse)
@limiter.limit("60/minute")
async def get_one(request: Request, wash_type_id: str, db: AsyncSession = Depends(get_db), current_user: User = Depends(get_current_user)):
    result = await db.execute(select(WashType).where(WashType.id == wash_type_id))
    wt = result.scalar_one_or_none()
    if not wt:
        raise HTTPException(404, "Тип мойки не найден")
    return await _to_response_single(db, wt)


@router.put("/{wash_type_id}", response_model=WashTypeResponse)
@limiter.limit("10/minute")
async def update(request: Request, wash_type_id: str, req: WashTypeRequest, db: AsyncSession = Depends(get_db), current_user: User = Depends(check_roles(['admin']))):
    result = await db.execute(select(WashType).where(WashType.id == wash_type_id))
    wt = result.scalar_one_or_none()
    if not wt:
        raise HTTPException(404, "Тип мойки не найден")

    wt.code = req.code
    wt.name = req.name
    wt.description = req.description
    wt.basePrice = req.basePrice
    wt.durationMinutes = req.durationMinutes
    wt.sortOrder = req.sortOrder

    # Обновляем включённые доп.услуги: удалить старые, вставить новые
    await db.execute(delete(WashTypeIncludedExtra).where(WashTypeIncludedExtra.washTypeId == wash_type_id))
    for extra_id in req.includedExtraIds:
        db.add(WashTypeIncludedExtra(washTypeId=wash_type_id, extraServiceId=extra_id))

    await db.commit()
    await db.refresh(wt)
    return await _to_response_single(db, wt)
