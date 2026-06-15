from datetime import datetime, timezone

from sqlalchemy.exc import IntegrityError
from sqlalchemy.ext.asyncio import AsyncSession

from models import Appointment, Review
from repositories.appointment import AppointmentRepository
from repositories.review import ReviewRepository
from schemas import ReviewCreateRequest, ReviewModerateRequest


class ReviewNotFoundError(Exception):
    pass


class ReviewBadRequestError(Exception):
    pass


class ReviewPermissionError(Exception):
    pass


class ReviewDuplicateError(Exception):
    pass


class ReviewsService:
    """Business logic for reviews."""

    def __init__(self, db: AsyncSession) -> None:
        self._db = db
        self._reviews = ReviewRepository(db)
        self._appointments = AppointmentRepository(db)

    async def list_reviews(
        self, published_only: bool, limit: int
    ) -> list[Review]:
        return await self._reviews.list_published_or_all(published_only, limit)

    async def list_my_reviews(self, user_id: int, limit: int) -> list[Review]:
        return await self._reviews.list_by_user(user_id, limit)

    async def has_review(self, user_id: int, appointment_id: str) -> bool:
        return await self._reviews.exists_for_user_appointment(user_id, appointment_id)

    async def create_review(
        self, data: ReviewCreateRequest, current_user_id: int, current_user_username: str, current_user_display_name: str
    ) -> Review:
        if data.appointmentId is not None:
            appointment = await self._appointments.get_by_id(data.appointmentId)
            if not appointment:
                raise ReviewBadRequestError("Запись не найдена")
            if appointment.ownerUsername != current_user_username:
                raise ReviewPermissionError("Нельзя оставить отзыв на чужую запись")
            if appointment.status != 'completed':
                raise ReviewBadRequestError("Можно оставить отзыв только на завершённую мойку")

            if await self._reviews.exists_for_user_appointment(current_user_id, data.appointmentId):
                raise ReviewDuplicateError("Отзыв на эту запись уже существует")

        review = Review(
            userId=current_user_id,
            userName=current_user_display_name,
            rating=data.rating,
            comment=data.comment,
            isPublished=0,
            createdAt=datetime.now(timezone.utc).isoformat(),
            appointmentId=data.appointmentId,
        )
        self._db.add(review)
        try:
            await self._db.commit()
        except IntegrityError:
            await self._db.rollback()
            raise
        await self._db.refresh(review)
        return review

    async def list_all_reviews(self, limit: int) -> list[Review]:
        return await self._reviews.list_all(limit)

    async def moderate_review(self, review_id: int, data: ReviewModerateRequest) -> Review:
        review = await self._reviews.get_by_id(review_id)
        if not review:
            raise ReviewNotFoundError()
        review.isPublished = 1 if data.isPublished else 0
        await self._db.commit()
        await self._db.refresh(review)
        return review

    async def delete_review(self, review_id: int) -> None:
        review = await self._reviews.get_by_id(review_id)
        if not review:
            raise ReviewNotFoundError()
        await self._db.delete(review)
        await self._db.commit()
