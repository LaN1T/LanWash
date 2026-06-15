from sqlalchemy.ext.asyncio import AsyncSession

from models import Appointment
from repositories.base import BaseRepository


class AppointmentRepository(BaseRepository[Appointment]):
    def __init__(self, db: AsyncSession) -> None:
        super().__init__(db, Appointment)
