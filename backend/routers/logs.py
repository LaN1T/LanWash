from fastapi import APIRouter, Depends
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, delete
from database import get_db
from models import LogRequest, LogResponse
from db_models import LogEntry
from datetime import datetime

router = APIRouter(prefix="/api/logs", tags=["logs"])

@router.get("/", response_model=list[LogResponse])
async def get_all(limit: int = 200, db: AsyncSession = Depends(get_db)):
    result = await db.execute(select(LogEntry).order_by(LogEntry.timestamp.desc()).limit(limit))
    return result.scalars().all()

@router.get("/by-user/{username}", response_model=list[LogResponse])
async def get_by_user(username: str, db: AsyncSession = Depends(get_db)):
    result = await db.execute(select(LogEntry).where(LogEntry.username == username.lower()).order_by(LogEntry.timestamp.desc()))
    return result.scalars().all()

@router.post("/", response_model=LogResponse)
async def create(req: LogRequest, db: AsyncSession = Depends(get_db)):
    new_log = LogEntry(
        username=req.username.lower(),
        action=req.action,
        details=req.details,
        timestamp=datetime.now().isoformat()
    )
    db.add(new_log)
    await db.commit()
    await db.refresh(new_log)
    return new_log

@router.delete("/")
async def clear_all(db: AsyncSession = Depends(get_db)):
    await db.execute(delete(LogEntry))
    await db.commit()
    return {"ok": True}
