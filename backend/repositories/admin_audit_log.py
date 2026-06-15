from sqlalchemy.ext.asyncio import AsyncSession

from models import AdminAuditLog
from repositories.base import BaseRepository


class AdminAuditLogRepository(BaseRepository[AdminAuditLog]):
    def __init__(self, db: AsyncSession) -> None:
        super().__init__(db, AdminAuditLog)
