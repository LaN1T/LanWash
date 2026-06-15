from fastapi import APIRouter, Depends, HTTPException, Query, Request, status
from sqlalchemy.ext.asyncio import AsyncSession

from core.limiter import limiter
from core.pagination import PaginationParams
from database import get_db
from models import User
from models import NoteRequest, NoteResponse
from services.auth_service import check_roles, get_current_user
from services.notes_service import NotesService

router = APIRouter(
    prefix="/api/notes",
    tags=["notes"],
)


@router.get("/", response_model=list[NoteResponse])
@limiter.limit("60/minute")
async def get_all(request: Request, pagination: PaginationParams = Depends(), db: AsyncSession = Depends(get_db), current_user: User = Depends(check_roles(['admin']))):
    """Все заметки (для админа)."""
    svc = NotesService(db)
    return await svc.get_all(pagination.per_page, pagination.offset)


@router.get("/by-user/{username}", response_model=list[NoteResponse])
@limiter.limit("60/minute")
async def get_by_user(request: Request, username: str, pagination: PaginationParams = Depends(), db: AsyncSession = Depends(get_db), current_user: User = Depends(get_current_user)):
    """Заметки конкретного мойщика."""
    if current_user.username != username.lower() and current_user.role != 'admin':
        raise HTTPException(status.HTTP_403_FORBIDDEN, "У вас нет доступа к чужим заметкам")

    svc = NotesService(db)
    return await svc.get_by_user(username.lower(), pagination.per_page, pagination.offset)


@router.get("/unread-count")
@limiter.limit("60/minute")
async def unread_count(request: Request, db: AsyncSession = Depends(get_db), current_user: User = Depends(check_roles(['admin']))):
    """Количество непрочитанных заметок (для бейджа у админа)."""
    svc = NotesService(db)
    count = await svc.unread_count()
    return {"count": count}


@router.post("/", response_model=NoteResponse)
@limiter.limit("10/minute")
async def create(request: Request, username: str, req: NoteRequest, db: AsyncSession = Depends(get_db), current_user: User = Depends(check_roles(['washer', 'admin']))):
    """Создать заметку (мойщик)."""
    if current_user.username != username.lower() and current_user.role != 'admin':
        raise HTTPException(status.HTTP_403_FORBIDDEN, "Вы не можете создавать заметки от имени другого пользователя")

    svc = NotesService(db)
    return await svc.create_note(username.lower(), req.title, req.message, req.category)


@router.put("/{note_id}/read")
@limiter.limit("10/minute")
async def mark_read(request: Request, note_id: int, db: AsyncSession = Depends(get_db), current_user: User = Depends(check_roles(['admin']))):
    """Отметить заметку как прочитанную (админ)."""
    svc = NotesService(db)
    await svc.mark_read(note_id)
    return {"ok": True}


@router.put("/read-all")
@limiter.limit("10/minute")
async def mark_all_read(request: Request, db: AsyncSession = Depends(get_db), current_user: User = Depends(check_roles(['admin']))):
    """Отметить все заметки как прочитанные."""
    svc = NotesService(db)
    await svc.mark_all_read()
    return {"ok": True}


@router.delete("/{note_id}")
@limiter.limit("10/minute")
async def delete_note(request: Request, note_id: int, db: AsyncSession = Depends(get_db), current_user: User = Depends(check_roles(['admin']))):
    svc = NotesService(db)
    await svc.delete_note(note_id)
    return {"ok": True}
