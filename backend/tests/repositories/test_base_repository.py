import pytest

from models import Consumable
from repositories.base import BaseRepository


class TestBaseRepository:
    @pytest.mark.asyncio
    async def test_add_and_get_by_id(self, db_session):
        repo = BaseRepository(db_session, Consumable)
        item = Consumable(id="c_test", name="Test Consumable", unit="шт")
        await repo.add(item)
        await db_session.flush()

        found = await repo.get_by_id("c_test")
        assert found is not None
        assert found.name == "Test Consumable"

    @pytest.mark.asyncio
    async def test_get_by_ids_and_order(self, db_session):
        repo = BaseRepository(db_session, Consumable)
        items = [
            Consumable(id="c_a", name="A", unit="шт"),
            Consumable(id="c_b", name="B", unit="шт"),
        ]
        for item in items:
            await repo.add(item)
        await db_session.flush()

        found = await repo.get_by_ids(["c_b", "c_a"])
        assert [i.id for i in found] == ["c_a", "c_b"]

    @pytest.mark.asyncio
    async def test_get_by_ids_empty_returns_empty(self, db_session):
        repo = BaseRepository(db_session, Consumable)
        assert await repo.get_by_ids([]) == []

    @pytest.mark.asyncio
    async def test_list_all_pagination(self, db_session):
        repo = BaseRepository(db_session, Consumable)
        for i in range(5):
            await repo.add(Consumable(id=f"c_{i}", name=f"Item {i}", unit="шт"))
        await db_session.flush()

        all_items = await repo.list_all()
        assert len(all_items) >= 5

        page = await repo.list_all(limit=2, offset=0)
        assert len(page) == 2

    @pytest.mark.asyncio
    async def test_count(self, db_session):
        repo = BaseRepository(db_session, Consumable)
        before = await repo.count()
        await repo.add(Consumable(id="c_count", name="Count Item", unit="шт"))
        await db_session.flush()
        assert await repo.count() == before + 1

    @pytest.mark.asyncio
    async def test_delete_instance(self, db_session):
        repo = BaseRepository(db_session, Consumable)
        item = Consumable(id="c_delete", name="Delete Me", unit="шт")
        await repo.add(item)
        await db_session.flush()

        await repo.delete(item)
        await db_session.flush()

        assert await repo.get_by_id("c_delete") is None

    @pytest.mark.asyncio
    async def test_delete_by_id(self, db_session):
        repo = BaseRepository(db_session, Consumable)
        await repo.add(Consumable(id="c_delete_id", name="Delete By ID", unit="шт"))
        await db_session.flush()

        assert await repo.delete_by_id("c_delete_id") is True
        await db_session.flush()
        assert await repo.get_by_id("c_delete_id") is None

    @pytest.mark.asyncio
    async def test_delete_by_id_missing_returns_false(self, db_session):
        repo = BaseRepository(db_session, Consumable)
        assert await repo.delete_by_id("c_missing") is False
