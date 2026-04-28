from fastapi import APIRouter, HTTPException, Depends, status
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, update, delete, func
from database import get_db
from models import NoteRequest, NoteResponse
from db_models import WasherNote, User
from datetime import datetime
from services.auth_service import get_current_user, check_roles

router = APIRouter(prefix="/api/notes", tags=["notes"])

@router.get("/", response_model=list[NoteResponse])
async def get_all(db: AsyncSession = Depends(get_db), current_user: User = Depends(check_roles(['admin']))):
    """Все заметки (для админа)."""
    result = await db.execute(select(WasherNote).order_by(WasherNote.createdAt.desc()))
    return result.scalars().all()

@router.get("/by-user/{username}", response_model=list[NoteResponse])
async def get_by_user(username: str, db: AsyncSession = Depends(get_db), current_user: User = Depends(get_current_user)):
    """Заметки конкретного мойщика."""
    if current_user.username != username.lower() and current_user.role != 'admin':
        raise HTTPException(status.HTTP_403_FORBIDDEN, "У вас нет доступа к чужим заметкам")
    
    result = await db.execute(
        select(WasherNote).where(WasherNote.username == username.lower()).order_by(WasherNote.createdAt.desc())
    )
    return result.scalars().all()

@router.get("/unread-count")
async def unread_count(db: AsyncSession = Depends(get_db), current_user: User = Depends(check_roles(['admin']))):
    """Количество непрочитанных заметок (для бейджа у админа)."""
    result = await db.execute(select(func.count(WasherNote.id)).where(WasherNote.isRead == 0))
    count = result.scalar()
    return {"count": count}

@router.post("/", response_model=NoteResponse)
async def create(username: str, req: NoteRequest, db: AsyncSession = Depends(get_db), current_user: User = Depends(check_roles(['washer', 'admin']))):
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
async def mark_read(note_id: int, db: AsyncSession = Depends(get_db), current_user: User = Depends(check_roles(['admin']))):
    """Отметить заметку как прочитанную (админ)."""
    await db.execute(update(WasherNote).where(WasherNote.id == note_id).values(isRead=1))
    await db.commit()
    return {"ok": True}

@router.put("/read-all")
async def mark_all_read(db: AsyncSession = Depends(get_db), current_user: User = Depends(check_roles(['admin']))):
    """Отметить все заметки как прочитанные."""
    await db.execute(update(WasherNote).values(isRead=1))
    await db.commit()
    return {"ok": True}

@router.delete("/{note_id}")
async def delete_note(note_id: int, db: AsyncSession = Depends(get_db), current_user: User = Depends(check_roles(['admin']))):
    await db.execute(delete(WasherNote).where(WasherNote.id == note_id))
    await db.commit()
    return {"ok": True}
