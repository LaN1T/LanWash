from fastapi import APIRouter, HTTPException, Depends
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, delete
from database import get_db
from db_models import WashType, WashTypeIncludedExtra
from models import WashTypeRequest, WashTypeResponse

router = APIRouter(prefix="/api/wash-types", tags=["wash-types"])


async def _to_response(db: AsyncSession, wt: WashType) -> dict:
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


@router.get("/", response_model=list[WashTypeResponse])
async def get_all(db: AsyncSession = Depends(get_db)):
    result = await db.execute(select(WashType).order_by(WashType.sortOrder.asc()))
    wash_types = result.scalars().all()
    return [await _to_response(db, wt) for wt in wash_types]


@router.get("/{wash_type_id}", response_model=WashTypeResponse)
async def get_one(wash_type_id: str, db: AsyncSession = Depends(get_db)):
    result = await db.execute(select(WashType).where(WashType.id == wash_type_id))
    wt = result.scalar_one_or_none()
    if not wt:
        raise HTTPException(404, "Тип мойки не найден")
    return await _to_response(db, wt)


@router.put("/{wash_type_id}", response_model=WashTypeResponse)
async def update(wash_type_id: str, req: WashTypeRequest, db: AsyncSession = Depends(get_db)):
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
    return await _to_response(db, wt)
