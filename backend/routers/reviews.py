from typing import List, Optional

from core.limiter import limiter
from database import get_db
from db_models import User
from fastapi import APIRouter, Depends, HTTPException, Query, Request
from fastapi.security import OAuth2PasswordBearer
from models import ReviewCreateRequest, ReviewModerateRequest, ReviewResponse
from services.auth_service import get_current_user
from services.reviews_service import (
    ReviewBadRequestError,
    ReviewDuplicateError,
    ReviewNotFoundError,
    ReviewPermissionError,
    ReviewsService,
)
from sqlalchemy.ext.asyncio import AsyncSession

router = APIRouter(prefix="/api/reviews", tags=["reviews"])

_optional_oauth2 = OAuth2PasswordBearer(tokenUrl="api/auth/login", auto_error=False)


async def get_current_user_optional(
    token: Optional[str] = Depends(_optional_oauth2),
    db: AsyncSession = Depends(get_db),
) -> Optional[User]:
    if not token:
        return None
    try:
        return await get_current_user(token=token, db=db)
    except HTTPException:
        return None


@router.get("/", response_model=List[ReviewResponse])
@limiter.limit("60/minute")
async def list_reviews(
    request: Request,
    published: bool = Query(False, description="Filter only published reviews"),
    limit: int = Query(10, ge=1, le=100),
    db: AsyncSession = Depends(get_db),
    current_user: Optional[User] = Depends(get_current_user_optional),
):
    svc = ReviewsService(db)
    published_only = published or (current_user is None or current_user.role != "admin")
    return await svc.list_reviews(published_only, limit)


@router.get("/my", response_model=List[ReviewResponse])
@limiter.limit("60/minute")
async def list_my_reviews(
    request: Request,
    limit: int = Query(100, ge=1, le=1000),
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    svc = ReviewsService(db)
    return await svc.list_my_reviews(current_user.id, limit)


@router.get("/has-review")
@limiter.limit("60/minute")
async def has_review(
    request: Request,
    appointment_id: str = Query(..., description="ID записи"),
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    svc = ReviewsService(db)
    has = await svc.has_review(current_user.id, appointment_id)
    return {"hasReview": has}


@router.post("/", response_model=ReviewResponse)
@limiter.limit("10/minute")
async def create_review(
    request: Request,
    data: ReviewCreateRequest,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    if current_user.id != data.userId and current_user.role != "admin":
        raise HTTPException(
            status_code=403, detail="Можно оставлять отзыв только от своего имени"
        )

    svc = ReviewsService(db)
    try:
        return await svc.create_review(
            data, current_user.id, current_user.username, current_user.displayName
        )
    except ReviewBadRequestError as e:
        raise HTTPException(status_code=400, detail=str(e))
    except ReviewPermissionError as e:
        raise HTTPException(status_code=403, detail=str(e))
    except ReviewDuplicateError as e:
        raise HTTPException(status_code=409, detail=str(e))


# ─── Admin endpoints ─────────────────────────────────────────────────────────


@router.get("/admin/all", response_model=List[ReviewResponse])
@limiter.limit("60/minute")
async def list_all_reviews(
    request: Request,
    limit: int = Query(100, ge=1, le=1000),
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    if current_user.role != "admin":
        raise HTTPException(status_code=403, detail="Admin required")
    svc = ReviewsService(db)
    return await svc.list_all_reviews(limit)


@router.patch("/admin/{review_id}", response_model=ReviewResponse)
@limiter.limit("60/minute")
async def moderate_review(
    request: Request,
    review_id: int,
    data: ReviewModerateRequest,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    if current_user.role != "admin":
        raise HTTPException(status_code=403, detail="Admin required")
    svc = ReviewsService(db)
    try:
        return await svc.moderate_review(review_id, data)
    except ReviewNotFoundError:
        raise HTTPException(status_code=404, detail="Review not found")


@router.delete("/admin/{review_id}")
@limiter.limit("60/minute")
async def delete_review(
    request: Request,
    review_id: int,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    if current_user.role != "admin":
        raise HTTPException(status_code=403, detail="Admin required")
    svc = ReviewsService(db)
    try:
        await svc.delete_review(review_id)
    except ReviewNotFoundError:
        raise HTTPException(status_code=404, detail="Review not found")
    return {"ok": True}
