from sqlalchemy.exc import IntegrityError
from sqlalchemy.ext.asyncio import AsyncSession

from models import Car
from repositories.car import CarRepository
from schemas import CarRequest


class CarNotFoundError(Exception):
    pass


class CarAccessDeniedError(Exception):
    pass


class CarsService:
    """Business logic for car management."""

    def __init__(self, db: AsyncSession) -> None:
        self._db = db
        self._cars = CarRepository(db)

    async def get_cars_for_user(self, user_id: int) -> list[Car]:
        return await self._cars.list_for_user(user_id)

    async def get_car(self, car_id: int) -> Car | None:
        return await self._cars.get_by_id(car_id)

    async def _ensure_access(self, car_id: int, user_id: int) -> Car:
        car = await self._cars.get_with_lock(car_id)
        if not car:
            raise CarNotFoundError()
        if car.userId != user_id:
            raise CarAccessDeniedError()
        return car

    async def create_car(self, user_id: int, req: CarRequest) -> Car:
        total_cars = await self._cars.count_for_user(user_id)
        is_primary = True if total_cars == 0 else (req.isPrimary or False)

        if is_primary:
            await self._cars.set_non_primary_for_user(user_id)

        car = Car(
            userId=user_id,
            brand=req.brand,
            model=req.model,
            number=req.number or "",
            isPrimary=is_primary,
        )
        self._db.add(car)
        try:
            await self._db.commit()
        except IntegrityError:
            await self._db.rollback()
            raise
        await self._db.refresh(car)
        return car

    async def update_car(self, car_id: int, user_id: int, req: CarRequest) -> Car:
        car = await self._ensure_access(car_id, user_id)

        if req.brand is not None:
            car.brand = req.brand
        if req.model is not None:
            car.model = req.model
        if req.number is not None:
            car.number = req.number

        if req.isPrimary is True and not car.isPrimary:
            await self._cars.set_non_primary_for_user(user_id, exclude_id=car_id)
            car.isPrimary = True
        elif req.isPrimary is False and car.isPrimary:
            car.isPrimary = False
            if await self._cars.count_for_user(user_id) > 0:
                oldest = await self._cars.get_oldest_for_user(user_id, exclude_id=car_id)
                if oldest:
                    oldest.isPrimary = True

        try:
            await self._db.commit()
        except IntegrityError:
            await self._db.rollback()
            raise
        await self._db.refresh(car)
        return car

    async def delete_car(self, car_id: int, user_id: int) -> None:
        car = await self._ensure_access(car_id, user_id)

        was_primary = car.isPrimary
        await self._db.delete(car)

        if was_primary:
            oldest = await self._cars.get_oldest_for_user(user_id)
            if oldest:
                oldest.isPrimary = True

        try:
            await self._db.commit()
        except IntegrityError:
            await self._db.rollback()
            raise
