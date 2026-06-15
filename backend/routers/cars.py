import structlog
from fastapi import APIRouter, Depends, HTTPException, Request, status
from sqlalchemy.exc import IntegrityError
from sqlalchemy.ext.asyncio import AsyncSession

from core.limiter import limiter
from database import get_db
from models import User
from models import CarRequest, CarResponse
from services.auth_service import check_roles, get_current_user
from services.cars_service import CarAccessDeniedError, CarNotFoundError, CarsService

logger = structlog.get_logger()

router = APIRouter(
    prefix="/api/cars",
    tags=["cars"],
)


@router.get("/", response_model=list[CarResponse])
@limiter.limit("60/minute")
async def get_cars(
    request: Request,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    svc = CarsService(db)
    return await svc.get_cars_for_user(current_user.id)


@router.get("/user/{user_id}", response_model=list[CarResponse])
@limiter.limit("60/minute")
async def get_user_cars(
    request: Request,
    user_id: int,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(check_roles(["admin"])),
):
    svc = CarsService(db)
    return await svc.get_cars_for_user(user_id)


@router.post("/", response_model=CarResponse)
@limiter.limit("30/minute")
async def create_car(
    request: Request,
    req: CarRequest,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    svc = CarsService(db)
    try:
        return await svc.create_car(current_user.id, req)
    except IntegrityError:
        raise HTTPException(
            status.HTTP_409_CONFLICT,
            "Не удалось установить основной автомобиль. Попробуйте ещё раз.",
        )


@router.put("/{car_id}", response_model=CarResponse)
@limiter.limit("30/minute")
async def update_car(
    request: Request,
    car_id: int,
    req: CarRequest,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    svc = CarsService(db)
    try:
        return await svc.update_car(car_id, current_user.id, req)
    except CarNotFoundError:
        raise HTTPException(
            status.HTTP_404_NOT_FOUND, "Автомобиль не найден"
        )
    except CarAccessDeniedError:
        raise HTTPException(
            status.HTTP_403_FORBIDDEN,
            "У вас нет доступа к этому автомобилю",
        )
    except IntegrityError:
        raise HTTPException(
            status.HTTP_409_CONFLICT,
            "Не удалось изменить основной автомобиль. Попробуйте ещё раз.",
        )


@router.delete("/{car_id}")
@limiter.limit("30/minute")
async def delete_car(
    request: Request,
    car_id: int,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    svc = CarsService(db)
    try:
        await svc.delete_car(car_id, current_user.id)
    except CarNotFoundError:
        raise HTTPException(
            status.HTTP_404_NOT_FOUND, "Автомобиль не найден"
        )
    except CarAccessDeniedError:
        raise HTTPException(
            status.HTTP_403_FORBIDDEN,
            "У вас нет доступа к этому автомобилю",
        )
    except IntegrityError:
        raise HTTPException(
            status.HTTP_409_CONFLICT,
            "Не удалось удалить автомобиль. Попробуйте ещё раз.",
        )
    return {"ok": True}
