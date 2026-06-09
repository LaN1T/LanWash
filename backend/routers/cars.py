from typing import Optional
from fastapi import APIRouter, HTTPException, Depends, status, Request
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, update, delete, func
from database import get_db
from models import CarRequest, CarResponse
from db_models import Car, User
from services.auth_service import get_current_user
from core.limiter import limiter
import structlog

logger = structlog.get_logger()

router = APIRouter(
    prefix="/api/cars",
    tags=["cars"],
)


@router.get("/", response_model=list[CarResponse])
@limiter.limit("60/minute")
async def get_cars(request: Request, db: AsyncSession = Depends(get_db), current_user: User = Depends(get_current_user)):
    result = await db.execute(select(Car).where(Car.userId == current_user.id).order_by(Car.id.asc()))
    return result.scalars().all()


@router.post("/", response_model=CarResponse)
@limiter.limit("30/minute")
async def create_car(request: Request, req: CarRequest, db: AsyncSession = Depends(get_db), current_user: User = Depends(get_current_user)):
    # If this is the first car for the user, make it primary regardless of request
    count_res = await db.execute(select(func.count(Car.id)).where(Car.userId == current_user.id))
    total_cars = count_res.scalar() or 0
    is_primary = req.isPrimary if req.isPrimary is not None else (total_cars == 0)

    if is_primary:
        await db.execute(update(Car).where(Car.userId == current_user.id).values(isPrimary=False))

    car = Car(
        userId=current_user.id,
        brand=req.brand,
        model=req.model,
        number=req.number or "",
        isPrimary=is_primary,
    )
    db.add(car)
    await db.commit()
    await db.refresh(car)
    return car


@router.put("/{car_id}", response_model=CarResponse)
@limiter.limit("30/minute")
async def update_car(request: Request, car_id: int, req: CarRequest, db: AsyncSession = Depends(get_db), current_user: User = Depends(get_current_user)):
    result = await db.execute(select(Car).where(Car.id == car_id))
    car = result.scalar_one_or_none()
    if not car:
        raise HTTPException(status.HTTP_404_NOT_FOUND, "Автомобиль не найден")
    if car.userId != current_user.id:
        raise HTTPException(status.HTTP_403_FORBIDDEN, "У вас нет доступа к этому автомобилю")

    if req.brand is not None:
        car.brand = req.brand
    if req.model is not None:
        car.model = req.model
    if req.number is not None:
        car.number = req.number

    if req.isPrimary is True and not car.isPrimary:
        await db.execute(update(Car).where(Car.userId == current_user.id).values(isPrimary=False))
        car.isPrimary = True
    elif req.isPrimary is False and car.isPrimary:
        # Unsetting primary: if there are other cars, make the oldest one primary
        car.isPrimary = False
        count_res = await db.execute(select(func.count(Car.id)).where(Car.userId == current_user.id, Car.id != car.id))
        if count_res.scalar() or 0 > 0:
            oldest_res = await db.execute(
                select(Car).where(Car.userId == current_user.id, Car.id != car.id).order_by(Car.id.asc()).limit(1)
            )
            oldest = oldest_res.scalar_one_or_none()
            if oldest:
                oldest.isPrimary = True

    await db.commit()
    await db.refresh(car)
    return car


@router.delete("/{car_id}")
@limiter.limit("30/minute")
async def delete_car(request: Request, car_id: int, db: AsyncSession = Depends(get_db), current_user: User = Depends(get_current_user)):
    result = await db.execute(select(Car).where(Car.id == car_id))
    car = result.scalar_one_or_none()
    if not car:
        raise HTTPException(status.HTTP_404_NOT_FOUND, "Автомобиль не найден")
    if car.userId != current_user.id:
        raise HTTPException(status.HTTP_403_FORBIDDEN, "У вас нет доступа к этому автомобилю")

    was_primary = car.isPrimary
    await db.delete(car)
    await db.commit()

    if was_primary:
        # Make the oldest remaining car primary
        oldest_res = await db.execute(
            select(Car).where(Car.userId == current_user.id).order_by(Car.id.asc()).limit(1)
        )
        oldest = oldest_res.scalar_one_or_none()
        if oldest:
            oldest.isPrimary = True
            await db.commit()

    return {"ok": True}
