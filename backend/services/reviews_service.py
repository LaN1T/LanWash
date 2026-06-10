from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select
from sqlalchemy.exc import IntegrityError
from datetime import datetime, timezone
from typing import Optional
from db_models import Review, Appointment
from models import ReviewCreateRequest, ReviewModerateRequest


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

    async def list_reviews(
        self, published_only: bool, limit: int
    ) -> list[Review]:
        stmt = select(Review)
        if published_only:
            stmt = stmt.where(Review.isPublished == 1)
        stmt = stmt.order_by(Review.createdAt.desc()).limit(limit)
        result = await self._db.execute(stmt)
        return list(result.scalars().all())

    async def list_my_reviews(self, user_id: int, limit: int) -> list[Review]:
        stmt = (
            select(Review)
            .where(Review.userId == user_id)
            .order_by(Review.createdAt.desc())
            .limit(limit)
        )
        result = await self._db.execute(stmt)
        return list(result.scalars().all())

    async def has_review(self, user_id: int, appointment_id: str) -> bool:
        result = await self._db.execute(
            select(Review).where(
                Review.userId == user_id,
                Review.appointmentId == appointment_id,
            )
        )
        return result.scalar_one_or_none() is not None

    async def create_review(
        self, data: ReviewCreateRequest, current_user_id: int, current_user_username: str, current_user_display_name: str
    ) -> Review:
        if data.appointmentId is not None:
            result = await self._db.execute(
                select(Appointment).where(Appointment.id == data.appointmentId)
            )
            appointment = result.scalar_one_or_none()
            if not appointment:
                raise ReviewBadRequestError("Запись не найдена")
            if appointment.ownerUsername != current_user_username:
                raise ReviewPermissionError("Нельзя оставить отзыв на чужую запись")
            if appointment.status != 'completed':
                raise ReviewBadRequestError("Можно оставить отзыв только на завершённую мойку")

            existing = await self._db.execute(
                select(Review).where(
                    Review.userId == current_user_id,
                    Review.appointmentId == data.appointmentId,
                )
            )
            if existing.scalar_one_or_none() is not None:
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
        stmt = select(Review).order_by(Review.createdAt.desc()).limit(limit)
        result = await self._db.execute(stmt)
        return list(result.scalars().all())

    async def moderate_review(self, review_id: int, data: ReviewModerateRequest) -> Review:
        result = await self._db.execute(select(Review).where(Review.id == review_id))
        review = result.scalar_one_or_none()
        if not review:
            raise ReviewNotFoundError()
        review.isPublished = 1 if data.isPublished else 0
        await self._db.commit()
        await self._db.refresh(review)
        return review

    async def delete_review(self, review_id: int) -> None:
        result = await self._db.execute(select(Review).where(Review.id == review_id))
        review = result.scalar_one_or_none()
        if not review:
            raise ReviewNotFoundError()
        await self._db.delete(review)
        await self._db.commit()
