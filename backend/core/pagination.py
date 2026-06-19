import base64
import json
from typing import Optional

from fastapi import Query
from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.sql import Select


class PaginationParams:
    def __init__(
        self, page: int = Query(1, ge=1), per_page: int = Query(20, ge=1, le=100)
    ):
        self.page = page
        self.per_page = per_page
        self.offset = (page - 1) * per_page


class CursorParams:
    def __init__(
        self,
        cursor: Optional[str] = Query(None),
        limit: int = Query(50, ge=1, le=200),
    ):
        self.cursor = cursor
        self.limit = limit


def encode_cursor(value: dict) -> str:
    return base64.urlsafe_b64encode(json.dumps(value, separators=(",", ":")).encode()).decode().rstrip("=")


def decode_cursor(cursor: str) -> dict:
    padding = "=" * (-len(cursor) % 4)
    return json.loads(base64.urlsafe_b64decode(cursor + padding).decode())


async def paginate(query: Select, db: AsyncSession, pagination: PaginationParams):
    total = await db.scalar(select(func.count()).select_from(query.subquery()))
    items_query = query.offset(pagination.offset).limit(pagination.per_page)
    result = await db.execute(items_query)
    return total, list(result.scalars().all())
