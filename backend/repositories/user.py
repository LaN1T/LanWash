from sqlalchemy import and_, func, or_, select, update
from sqlalchemy.ext.asyncio import AsyncSession

from models import User
from repositories.base import BaseRepository


class UserRepository(BaseRepository[User]):
    def __init__(self, db: AsyncSession) -> None:
        super().__init__(db, User)

    async def get_by_username(self, username: str) -> User | None:
        result = await self._db.execute(
            select(User).where(User.username == username)
        )
        return result.scalar_one_or_none()

    async def get_by_telegram_id(self, telegram_id: str) -> User | None:
        result = await self._db.execute(
            select(User).where(User.telegramId == telegram_id)
        )
        return result.scalar_one_or_none()

    async def get_by_referral_code(self, code: str) -> User | None:
        result = await self._db.execute(
            select(User).where(User.referralCode == code)
        )
        return result.scalar_one_or_none()

    async def list_washers(self) -> list[User]:
        result = await self._db.execute(
            select(User)
            .where(User.role == "washer")
            .order_by(User.displayName.asc())
        )
        return list(result.scalars().all())

    async def list_client_usernames(
        self, *, limit: int, offset: int
    ) -> list[str]:
        result = await self._db.execute(
            select(User.username)
            .where(User.role == "client")
            .order_by(User.id)
            .limit(limit)
            .offset(offset)
        )
        return [row[0] for row in result.all() if row[0]]

    async def update_fields(self, pk: int, updates: dict) -> int:
        result = await self._db.execute(
            update(User).where(User.id == pk).values(updates)
        )
        return result.rowcount or 0

    async def get_display_names_by_usernames(
        self, usernames: list[str]
    ) -> dict[str, str | None]:
        if not usernames:
            return {}
        result = await self._db.execute(
            select(User.username, User.displayName).where(
                User.username.in_(usernames)
            )
        )
        return {row[0]: row[1] for row in result.all()}

    async def search(
        self,
        *,
        q: str | None,
        role: str | None,
        from_date: str | None,
        to_date: str | None,
        limit: int,
        offset: int,
    ) -> tuple[list[User], int]:
        stmt = select(User)
        filters = []

        if q:
            escaped_q = q.replace('%', r'\%').replace('_', r'\_')
            safe_q = f"%{escaped_q}%"
            filters.append(
                or_(
                    User.displayName.ilike(safe_q, escape='\\'),
                    User.username.ilike(safe_q, escape='\\'),
                    User.phone.ilike(safe_q, escape='\\'),
                    User.carModel.ilike(safe_q, escape='\\'),
                    User.carNumber.ilike(safe_q, escape='\\'),
                )
            )

        if role:
            filters.append(User.role == role)

        if from_date:
            filters.append(User.createdAt >= from_date)
        if to_date:
            filters.append(User.createdAt < to_date + "T23:59:59")

        if filters:
            stmt = stmt.where(and_(*filters))

        count_stmt = select(func.count(User.id))
        if filters:
            count_stmt = count_stmt.where(and_(*filters))
        total_result = await self._db.execute(count_stmt)
        total = total_result.scalar() or 0

        stmt = stmt.order_by(User.createdAt.desc()).limit(limit).offset(offset)
        result = await self._db.execute(stmt)
        items = list(result.scalars().all())

        return items, total
