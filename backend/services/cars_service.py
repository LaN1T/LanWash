from db_models import Car
from models import CarRequest
from sqlalchemy import func, select, update
from sqlalchemy.exc import IntegrityError
from sqlalchemy.ext.asyncio import AsyncSession


class CarNotFoundError(Exception):
    pass


class CarAccessDeniedError(Exception):
    pass


class CarsService:
    """Business logic for car management."""

    def __init__(self, db: AsyncSession) -> None:
        self._db = db

    async def get_cars_for_user(self, user_id: int) -> list[Car]:
        result = await self._db.execute(
            select(Car).where(Car.userId == user_id).order_by(Car.id.asc())
        )
        return list(result.scalars().all())

    async def get_car(self, car_id: int) -> Car | None:
        result = await self._db.execute(select(Car).where(Car.id == car_id))
        return result.scalar_one_or_none()

    async def _ensure_access(self, car_id: int, user_id: int) -> Car:
        result = await self._db.execute(
            select(Car).where(Car.id == car_id).with_for_update()
        )
        car = result.scalar_one_or_none()
        if not car:
            raise CarNotFoundError()
        if car.userId != user_id:
            raise CarAccessDeniedError()
        return car

    async def create_car(self, user_id: int, req: CarRequest) -> Car:
        count_res = await self._db.execute(
            select(func.count(Car.id)).where(Car.userId == user_id)
        )
        total_cars = count_res.scalar() or 0
        is_primary = True if total_cars == 0 else (req.isPrimary or False)

        if is_primary:
            await self._db.execute(
                update(Car)
                .where(Car.userId == user_id)
                .values(isPrimary=False)
                .execution_options(synchronize_session="fetch")
            )

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
            await self._db.execute(
                update(Car)
                .where(Car.userId == user_id, Car.id != car_id)
                .values(isPrimary=False)
                .execution_options(synchronize_session="fetch")
            )
            car.isPrimary = True
        elif req.isPrimary is False and car.isPrimary:
            car.isPrimary = False
            count_res = await self._db.execute(
                select(func.count(Car.id)).where(
                    Car.userId == user_id, Car.id != car_id
                )
            )
            if (count_res.scalar() or 0) > 0:
                oldest_res = await self._db.execute(
                    select(Car)
                    .where(Car.userId == user_id, Car.id != car_id)
                    .order_by(Car.id.asc())
                    .limit(1)
                )
                oldest = oldest_res.scalar_one_or_none()
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
            oldest_res = await self._db.execute(
                select(Car).where(Car.userId == user_id).order_by(Car.id.asc()).limit(1)
            )
            oldest = oldest_res.scalar_one_or_none()
            if oldest:
                oldest.isPrimary = True

        try:
            await self._db.commit()
        except IntegrityError:
            await self._db.rollback()
            raise
