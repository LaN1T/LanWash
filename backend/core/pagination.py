from fastapi import Query
from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.sql import Select


class PaginationParams:
    def __init__(self, page: int = Query(1, ge=1), per_page: int = Query(20, ge=1, le=100)):
        self.page = page
        self.per_page = per_page
        self.offset = (page - 1) * per_page


async def paginate(query: Select, db: AsyncSession, pagination: PaginationParams):
    total = await db.scalar(select(func.count()).select_from(query.subquery()))
    items_query = query.offset(pagination.offset).limit(pagination.per_page)
    result = await db.execute(items_query)
    return total, list(result.scalars().all())
