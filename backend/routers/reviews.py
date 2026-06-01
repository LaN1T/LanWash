from fastapi import APIRouter, Depends, HTTPException, Query, Request
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select
from typing import List
from datetime import datetime, timezone

from database import get_db
from db_models import Review, User
from models import ReviewCreateRequest, ReviewResponse, ReviewModerateRequest
from services.auth_service import get_current_user
from core.limiter import limiter

router = APIRouter(prefix="/api/reviews", tags=["reviews"])


@router.get("/", response_model=List[ReviewResponse])
@limiter.limit("60/minute")
async def list_reviews(
    request: Request,
    published: bool = Query(False, description="Filter only published reviews"),
    limit: int = Query(10, ge=1, le=100),
    db: AsyncSession = Depends(get_db)
):
    stmt = select(Review)
    if published:
        stmt = stmt.where(Review.isPublished == 1)
    stmt = stmt.order_by(Review.createdAt.desc()).limit(limit)
    result = await db.execute(stmt)
    return result.scalars().all()


@router.post("/", response_model=ReviewResponse)
@limiter.limit("10/minute")
async def create_review(
    request: Request,
    data: ReviewCreateRequest,
    db: AsyncSession = Depends(get_db)
):
    review = Review(
        userId=data.userId,
        userName=data.userName,
        rating=data.rating,
        comment=data.comment,
        isPublished=0,
        createdAt=datetime.now(timezone.utc).isoformat(),
    )
    db.add(review)
    await db.commit()
    await db.refresh(review)
    return review


# ─── Admin endpoints ─────────────────────────────────────────────────────────

@router.get("/admin/all", response_model=List[ReviewResponse])
@limiter.limit("60/minute")
async def list_all_reviews(
    request: Request,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    if current_user.role != "admin":
        raise HTTPException(status_code=403, detail="Admin required")
    stmt = select(Review).order_by(Review.createdAt.desc())
    result = await db.execute(stmt)
    return result.scalars().all()


@router.patch("/admin/{review_id}", response_model=ReviewResponse)
@limiter.limit("60/minute")
async def moderate_review(
    request: Request,
    review_id: int,
    data: ReviewModerateRequest,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    if current_user.role != "admin":
        raise HTTPException(status_code=403, detail="Admin required")
    result = await db.execute(select(Review).where(Review.id == review_id))
    review = result.scalar_one_or_none()
    if not review:
        raise HTTPException(status_code=404, detail="Review not found")
    review.isPublished = 1 if data.isPublished else 0
    await db.commit()
    await db.refresh(review)
    return review


@router.delete("/admin/{review_id}")
@limiter.limit("60/minute")
async def delete_review(
    request: Request,
    review_id: int,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    if current_user.role != "admin":
        raise HTTPException(status_code=403, detail="Admin required")
    result = await db.execute(select(Review).where(Review.id == review_id))
    review = result.scalar_one_or_none()
    if not review:
        raise HTTPException(status_code=404, detail="Review not found")
    await db.delete(review)
    await db.commit()
    return {"ok": True}
