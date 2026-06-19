from datetime import datetime

import pytest

from models import Car, User
from repositories.car import CarRepository
from services.auth_service import get_password_hash


async def _create_user(db_session, username: str) -> User:
    user = User(
        username=username,
        passwordHash=get_password_hash("TestPass123!"),
        role="client",
        displayName=username,
        createdAt=datetime.now(),
    )
    db_session.add(user)
    await db_session.flush()
    return user


class TestCarRepository:
    @pytest.mark.asyncio
    async def test_list_for_user_orders_by_id(self, db_session):
        user = await _create_user(db_session, "car_list_user")
        repo = CarRepository(db_session)
        car1 = Car(userId=user.id, brand="BMW", model="X5", number="А111БВ777")
        db_session.add(car1)
        await db_session.flush()
        car2 = Car(userId=user.id, brand="Audi", model="A6", number="А222БВ777")
        db_session.add(car2)
        await db_session.flush()

        result = await repo.list_for_user(user.id)
        assert [c.id for c in result] == [car1.id, car2.id]

    @pytest.mark.asyncio
    async def test_list_for_user_filters_by_user(self, db_session):
        user1 = await _create_user(db_session, "car_user_1")
        user2 = await _create_user(db_session, "car_user_2")
        repo = CarRepository(db_session)
        car = Car(userId=user1.id, brand="BMW", model="X5", number="А111БВ777")
        db_session.add(car)
        await db_session.flush()

        assert len(await repo.list_for_user(user1.id)) == 1
        assert await repo.list_for_user(user2.id) == []

    @pytest.mark.asyncio
    async def test_count_for_user(self, db_session):
        user = await _create_user(db_session, "car_count_user")
        repo = CarRepository(db_session)
        db_session.add_all(
            [
                Car(userId=user.id, brand="BMW", model="X5", number="А111БВ777"),
                Car(userId=user.id, brand="Audi", model="A6", number="А222БВ777"),
            ]
        )
        await db_session.flush()

        assert await repo.count_for_user(user.id) == 2

    @pytest.mark.asyncio
    async def test_get_with_lock_returns_car(self, db_session):
        user = await _create_user(db_session, "car_lock_user")
        repo = CarRepository(db_session)
        car = Car(userId=user.id, brand="BMW", model="X5", number="А111БВ777")
        db_session.add(car)
        await db_session.flush()

        found = await repo.get_with_lock(car.id)
        assert found is not None
        assert found.id == car.id

    @pytest.mark.asyncio
    async def test_get_with_lock_missing_returns_none(self, db_session):
        repo = CarRepository(db_session)
        assert await repo.get_with_lock(999999) is None

    @pytest.mark.asyncio
    async def test_set_non_primary_for_user(self, db_session):
        user = await _create_user(db_session, "car_non_primary_user")
        repo = CarRepository(db_session)
        car = Car(
            userId=user.id, brand="BMW", model="X5", number="А111БВ777", isPrimary=True
        )
        db_session.add(car)
        await db_session.flush()

        await repo.set_non_primary_for_user(user.id)
        await db_session.flush()

        updated = await db_session.get(Car, car.id)
        assert updated.isPrimary is False

    @pytest.mark.asyncio
    async def test_set_non_primary_for_user_excludes_id(self, db_session):
        user = await _create_user(db_session, "car_exclude_user")
        repo = CarRepository(db_session)
        primary = Car(
            userId=user.id, brand="BMW", model="X5", number="А111БВ777", isPrimary=True
        )
        other = Car(
            userId=user.id,
            brand="Audi",
            model="A6",
            number="А222БВ777",
            isPrimary=False,
        )
        db_session.add_all([primary, other])
        await db_session.flush()

        await repo.set_non_primary_for_user(user.id, exclude_id=primary.id)
        await db_session.flush()

        cars = {c.id: c for c in await repo.list_for_user(user.id)}
        assert cars[primary.id].isPrimary is True
        assert cars[other.id].isPrimary is False

    @pytest.mark.asyncio
    async def test_get_oldest_for_user(self, db_session):
        user = await _create_user(db_session, "car_oldest_user")
        repo = CarRepository(db_session)
        car1 = Car(userId=user.id, brand="BMW", model="X5", number="А111БВ777")
        db_session.add(car1)
        await db_session.flush()
        car2 = Car(userId=user.id, brand="Audi", model="A6", number="А222БВ777")
        db_session.add(car2)
        await db_session.flush()

        oldest = await repo.get_oldest_for_user(user.id)
        assert oldest is not None
        assert oldest.id == car1.id

    @pytest.mark.asyncio
    async def test_get_oldest_for_user_excludes_id(self, db_session):
        user = await _create_user(db_session, "car_oldest_exclude_user")
        repo = CarRepository(db_session)
        car1 = Car(userId=user.id, brand="BMW", model="X5", number="А111БВ777")
        db_session.add(car1)
        await db_session.flush()
        car2 = Car(userId=user.id, brand="Audi", model="A6", number="А222БВ777")
        db_session.add(car2)
        await db_session.flush()

        oldest = await repo.get_oldest_for_user(user.id, exclude_id=car1.id)
        assert oldest is not None
        assert oldest.id == car2.id
