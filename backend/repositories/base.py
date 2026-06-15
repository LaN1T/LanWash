from typing import Generic, Sequence, TypeVar

from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession

ModelT = TypeVar("ModelT")


class BaseRepository(Generic[ModelT]):
    """Generic async CRUD repository for SQLAlchemy models."""

    def __init__(self, db: AsyncSession, model: type[ModelT]) -> None:
        self._db = db
        self._model = model

    async def get_by_id(self, pk: int | str) -> ModelT | None:
        return await self._db.get(self._model, pk)

    async def get_by_ids(self, ids: Sequence[int | str]) -> Sequence[ModelT]:
        if not ids:
            return []
        result = await self._db.execute(
            select(self._model)
            .where(self._model.id.in_(ids))
            .order_by(self._model.id.asc())
        )
        return result.scalars().all()

    async def list_all(
        self,
        *,
        order_by=None,
        limit: int | None = None,
        offset: int = 0,
    ) -> Sequence[ModelT]:
        stmt = select(self._model)
        if order_by is not None:
            stmt = stmt.order_by(order_by)
        if offset:
            stmt = stmt.offset(offset)
        if limit is not None:
            stmt = stmt.limit(limit)
        result = await self._db.execute(stmt)
        return result.scalars().all()

    async def count(self) -> int:
        result = await self._db.execute(select(func.count(self._model.id)))
        return result.scalar() or 0

    async def add(self, instance: ModelT) -> ModelT:
        self._db.add(instance)
        return instance

    async def delete(self, instance: ModelT) -> None:
        await self._db.delete(instance)

    async def delete_by_id(self, pk: int | str) -> bool:
        instance = await self.get_by_id(pk)
        if instance is None:
            return False
        await self.delete(instance)
        return True
