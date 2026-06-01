from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy.orm import Session
from typing import List
from datetime import datetime, timezone

from backend.database import get_db
from backend.db_models import Review
from backend.models import ReviewCreateRequest, ReviewResponse, ReviewModerateRequest
from backend.core.security import get_current_user

router = APIRouter(prefix="/api/reviews", tags=["reviews"])


@router.get("/", response_model=List[ReviewResponse])
def list_reviews(
    published: bool = Query(False, description="Filter only published reviews"),
    limit: int = Query(10, ge=1, le=100),
    db: Session = Depends(get_db)
):
    query = db.query(Review)
    if published:
        query = query.filter(Review.isPublished == 1)
    return (
        query.order_by(Review.createdAt.desc())
        .limit(limit)
        .all()
    )


@router.post("/", response_model=ReviewResponse)
def create_review(
    data: ReviewCreateRequest,
    db: Session = Depends(get_db)
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
    db.commit()
    db.refresh(review)
    return review


# ─── Admin endpoints ─────────────────────────────────────────────────────────

@router.get("/admin/all", response_model=List[ReviewResponse])
def list_all_reviews(
    current_user=Depends(get_current_user),
    db: Session = Depends(get_db)
):
    if current_user.role != "admin":
        raise HTTPException(status_code=403, detail="Admin required")
    return db.query(Review).order_by(Review.createdAt.desc()).all()


@router.patch("/admin/{review_id}", response_model=ReviewResponse)
def moderate_review(
    review_id: int,
    data: ReviewModerateRequest,
    current_user=Depends(get_current_user),
    db: Session = Depends(get_db)
):
    if current_user.role != "admin":
        raise HTTPException(status_code=403, detail="Admin required")
    review = db.query(Review).filter(Review.id == review_id).first()
    if not review:
        raise HTTPException(status_code=404, detail="Review not found")
    review.isPublished = 1 if data.isPublished else 0
    db.commit()
    db.refresh(review)
    return review


@router.delete("/admin/{review_id}")
def delete_review(
    review_id: int,
    current_user=Depends(get_current_user),
    db: Session = Depends(get_db)
):
    if current_user.role != "admin":
        raise HTTPException(status_code=403, detail="Admin required")
    review = db.query(Review).filter(Review.id == review_id).first()
    if not review:
        raise HTTPException(status_code=404, detail="Review not found")
    db.delete(review)
    db.commit()
    return {"ok": True}
