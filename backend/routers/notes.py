from fastapi import APIRouter, HTTPException, Depends, status, Request
from sqlalchemy.ext.asyncio import AsyncSession
from core.limiter import limiter
from sqlalchemy import select, update, delete, func
from database import get_db
from models import NoteRequest, NoteResponse
from db_models import WasherNote, User
from datetime import datetime
from services.auth_service import get_current_user, check_roles

router = APIRouter(prefix="/api/notes", tags=["notes"])

@router.get("/", response_model=list[NoteResponse])
@limiter.limit("60/minute")
async def get_all(request: Request, db: AsyncSession = Depends(get_db), current_user: User = Depends(check_roles(['admin']))):
    """Все заметки (для админа)."""
    result = await db.execute(select(WasherNote).order_by(WasherNote.createdAt.desc()))
    return result.scalars().all()

@router.get("/by-user/{username}", response_model=list[NoteResponse])
@limiter.limit("60/minute")
async def get_by_user(request: Request, username: str, db: AsyncSession = Depends(get_db), current_user: User = Depends(get_current_user)):
    """Заметки конкретного мойщика."""
    if current_user.username != username.lower() and current_user.role != 'admin':
        raise HTTPException(status.HTTP_403_FORBIDDEN, "У вас нет доступа к чужим заметкам")
    
    result = await db.execute(
        select(WasherNote).where(WasherNote.username == username.lower()).order_by(WasherNote.createdAt.desc())
    )
    return result.scalars().all()

@router.get("/unread-count")
@limiter.limit("60/minute")
async def unread_count(request: Request, db: AsyncSession = Depends(get_db), current_user: User = Depends(check_roles(['admin']))):
    """Количество непрочитанных заметок (для бейджа у админа)."""
    result = await db.execute(select(func.count(WasherNote.id)).where(WasherNote.isRead == 0))
    count = result.scalar()
    return {"count": count}

@router.post("/", response_model=NoteResponse)
@limiter.limit("10/minute")
async def create(request: Request, username: str, req: NoteRequest, db: AsyncSession = Depends(get_db), current_user: User = Depends(check_roles(['washer', 'admin']))):
    """Создать заметку (мойщик)."""
    if current_user.username != username.lower() and current_user.role != 'admin':
        raise HTTPException(status.HTTP_403_FORBIDDEN, "Вы не можете создавать заметки от имени другого пользователя")

    new_note = WasherNote(
        username=username.lower(),
        title=req.title,
        message=req.message,
        category=req.category,
        isRead=0,
        createdAt=datetime.now().isoformat()
    )
    db.add(new_note)
    await db.commit()
    await db.refresh(new_note)
    return new_note

@router.put("/{note_id}/read")
@limiter.limit("10/minute")
async def mark_read(request: Request, note_id: int, db: AsyncSession = Depends(get_db), current_user: User = Depends(check_roles(['admin']))):
    """Отметить заметку как прочитанную (админ)."""
    await db.execute(update(WasherNote).where(WasherNote.id == note_id).values(isRead=1))
    await db.commit()
    return {"ok": True}

@router.put("/read-all")
@limiter.limit("10/minute")
async def mark_all_read(request: Request, db: AsyncSession = Depends(get_db), current_user: User = Depends(check_roles(['admin']))):
    """Отметить все заметки как прочитанные."""
    await db.execute(update(WasherNote).values(isRead=1))
    await db.commit()
    return {"ok": True}

@router.delete("/{note_id}")
@limiter.limit("10/minute")
async def delete_note(request: Request, note_id: int, db: AsyncSession = Depends(get_db), current_user: User = Depends(check_roles(['admin']))):
    await db.execute(delete(WasherNote).where(WasherNote.id == note_id))
    await db.commit()
    return {"ok": True}
