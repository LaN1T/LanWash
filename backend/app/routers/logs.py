from typing import Optional

from fastapi import APIRouter, Depends, HTTPException, Request, Response, status
from sqlalchemy.ext.asyncio import AsyncSession

from core.limiter import limiter
from core.pagination import CursorParams, PaginationParams, decode_cursor, encode_cursor
from db.session import get_db
from models import LogEntry, User
from schemas import LogRequest, LogResponse
from services.auth_service import get_current_user
from services.logs_service import LogsService

router = APIRouter(
    prefix="/api/logs",
    tags=["logs"],
)


def _wants_cursor(request: Request) -> bool:
    return "cursor" in request.query_params or "limit" in request.query_params


def _set_next_cursor(
    response: Response, items: list[LogEntry], limit: int
) -> list[LogEntry]:
    if len(items) > limit:
        next_item = items[-1]
        response.headers["X-Next-Cursor"] = encode_cursor(
            {"t": next_item.timestamp, "id": next_item.id}
        )
        return items[:-1]
    return items


@router.get("/", response_model=list[LogResponse])
@limiter.limit("60/minute")
async def get_all(
    request: Request,
    response: Response,
    pagination: PaginationParams = Depends(),
    cursor_params: CursorParams = Depends(),
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    if current_user.role != "admin":
        raise HTTPException(
            status.HTTP_403_FORBIDDEN, "Доступ к логам только для администраторов."
        )
    svc = LogsService(db)
    if _wants_cursor(request):
        cursor = decode_cursor(cursor_params.cursor) if cursor_params.cursor else None
        items = await svc.get_all(limit=cursor_params.limit, cursor=cursor)
        return _set_next_cursor(response, items, cursor_params.limit)
    return await svc.get_all(limit=pagination.per_page, offset=pagination.offset)


@router.get("/by-user/{username}", response_model=list[LogResponse])
@limiter.limit("60/minute")
async def get_by_user(
    request: Request,
    response: Response,
    username: str,
    pagination: PaginationParams = Depends(),
    cursor_params: CursorParams = Depends(),
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    if current_user.username != username.lower() and current_user.role != "admin":
        raise HTTPException(
            status.HTTP_403_FORBIDDEN, "У вас нет доступа к логам этого пользователя."
        )
    svc = LogsService(db)
    username = username.lower()
    if _wants_cursor(request):
        cursor = decode_cursor(cursor_params.cursor) if cursor_params.cursor else None
        items = await svc.get_by_user(
            username, limit=cursor_params.limit, cursor=cursor
        )
        return _set_next_cursor(response, items, cursor_params.limit)
    return await svc.get_by_user(
        username, limit=pagination.per_page, offset=pagination.offset
    )


@router.post("/", response_model=Optional[LogResponse])
@limiter.limit("30/minute")
async def create(request: Request, req: LogRequest, db: AsyncSession = Depends(get_db)):
    # Эндпоинт публичный, так как используется для записи логина/регистрации
    # до авторизации. Записи создаются только для admin и washer.
    svc = LogsService(db)
    return await svc.create_log(req.username.lower(), req.action, req.details)


@router.delete("/")
@limiter.limit("10/minute")
async def clear_all(
    request: Request,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    if current_user.role != "admin":
        raise HTTPException(
            status.HTTP_403_FORBIDDEN, "Только администраторы могут очищать логи."
        )
    svc = LogsService(db)
    await svc.clear_all()
    return {"ok": True}
