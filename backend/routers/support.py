from datetime import datetime
from typing import Optional

from fastapi import APIRouter, Depends, HTTPException, Query, Request, status
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, desc

from core.limiter import limiter
from database import get_db
from db_models import SupportChat, SupportMessage, User
from models import (
    SupportChatCreateRequest,
    SupportChatResponse,
    SupportMessageCreateRequest,
    SupportMessageResponse,
    AiDraftResponse,
)
from services.auth_service import get_current_user, check_roles
from services.ai_draft_service import classify_and_reply, generate_admin_draft
from services.fcm_service import fcm_service
import structlog

logger = structlog.get_logger()
router = APIRouter(prefix="/api/support", tags=["support"])


async def _admin_tokens(db: AsyncSession, exclude_user_ids: Optional[set[int]] = None) -> list[str]:
    from db_models import FcmToken
    stmt = (
        select(FcmToken.token)
        .join(User, FcmToken.username == User.username)
        .where(User.role == 'admin')
    )
    if exclude_user_ids:
        stmt = stmt.where(User.id.not_in(exclude_user_ids))
    res = await db.execute(stmt)
    return [r[0] for r in res.all() if r[0]]


async def _user_tokens(db: AsyncSession, user_id: int) -> list[str]:
    from db_models import FcmToken
    user_res = await db.execute(select(User.username).where(User.id == user_id))
    username = user_res.scalar_one_or_none()
    if not username:
        return []
    res = await db.execute(select(FcmToken.token).where(FcmToken.username == username))
    return [r[0] for r in res.all() if r[0]]


def _to_message_response(msg: SupportMessage, users: dict[int, User]) -> SupportMessageResponse:
    sender = users.get(msg.senderId) if msg.senderId else None
    return SupportMessageResponse(
        id=msg.id,
        chatId=msg.chatId,
        senderRole=msg.senderRole,
        senderId=msg.senderId,
        senderName=sender.displayName if sender else ("Ассистент" if msg.senderRole == "ai" else None),
        content=msg.content,
        isAiDraft=bool(msg.isAiDraft),
        createdAt=msg.createdAt,
    )


def _to_chat_response(chat: SupportChat, users: dict[int, User], last_msg: Optional[str]) -> SupportChatResponse:
    user = users.get(chat.userId)
    admin = users.get(chat.assignedAdminId) if chat.assignedAdminId else None
    return SupportChatResponse(
        id=chat.id,
        userId=chat.userId,
        userName=user.displayName if user else "Unknown",
        userPhone=user.phone if user else None,
        status=chat.status,
        assignedAdminId=chat.assignedAdminId,
        assignedAdminName=admin.displayName if admin else None,
        unreadByUser=chat.unreadByUser,
        unreadByAdmin=chat.unreadByAdmin,
        lastMessageAt=chat.lastMessageAt,
        lastMessagePreview=(last_msg[:80] + "...") if last_msg and len(last_msg) > 80 else last_msg,
        createdAt=chat.createdAt,
    )


@router.post("/chats", response_model=SupportChatResponse)
@limiter.limit("10/minute")
async def create_chat(
    request: Request,
    req: SupportChatCreateRequest,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    now = datetime.now().isoformat()
    chat = SupportChat(
        userId=current_user.id,
        status="open",
        unreadByUser=0,
        unreadByAdmin=1,
        lastMessageAt=now,
        createdAt=now,
        updatedAt=now,
    )
    db.add(chat)
    await db.flush()

    msg = SupportMessage(
        chatId=chat.id,
        senderRole="client",
        senderId=current_user.id,
        content=req.firstMessage.strip(),
        createdAt=now,
    )
    db.add(msg)
    await db.commit()

    # Try auto-reply
    ai_text = await classify_and_reply(db, chat, [msg])
    if ai_text:
        ai_msg = SupportMessage(
            chatId=chat.id,
            senderRole="ai",
            content=ai_text,
            createdAt=datetime.now().isoformat(),
        )
        db.add(ai_msg)
        chat.status = "ai_handled"
        chat.unreadByAdmin = 0
        chat.unreadByUser += 1
        chat.lastMessageAt = ai_msg.createdAt
        await db.commit()
        try:
            from main import _broadcast_to_chat
            users_map = {current_user.id: current_user}
            await _broadcast_to_chat(chat.id, {
                "type": "new_message",
                "data": _to_message_response(ai_msg, users_map).model_dump(),
            })
        except Exception:
            pass
    else:
        chat.status = "waiting_admin"
        await db.commit()
        try:
            from main import _ws_connections
            connected_user_ids = {uid for _, uid in _ws_connections.get(chat.id, [])}
        except Exception:
            connected_user_ids = set()
        tokens = await _admin_tokens(db, exclude_user_ids=connected_user_ids or None)
        if tokens:
            try:
                await fcm_service.send_notification_to_tokens(
                    tokens,
                    title="Новое обращение",
                    body=f"Сообщение от {current_user.displayName}",
                    data={"type": "support_chat", "chat_id": str(chat.id)},
                )
            except Exception as e:
                logger.warning("support_push_failed", error=str(e))

    users = {current_user.id: current_user}
    return _to_chat_response(chat, users, req.firstMessage)


@router.get("/chats/my", response_model=list[SupportChatResponse])
@limiter.limit("60/minute")
async def list_my_chats(
    request: Request,
    limit: int = Query(50, ge=1, le=200),
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    res = await db.execute(
        select(SupportChat)
        .where(SupportChat.userId == current_user.id)
        .order_by(desc(SupportChat.lastMessageAt))
        .limit(limit)
    )
    chats = res.scalars().all()
    if not chats:
        return []
    user_ids = {c.userId for c in chats} | {c.assignedAdminId for c in chats if c.assignedAdminId}
    users_res = await db.execute(select(User).where(User.id.in_(user_ids)))
    users = {u.id: u for u in users_res.scalars().all()}

    chat_ids = [c.id for c in chats]
    msg_res = await db.execute(
        select(SupportMessage.chatId, SupportMessage.content)
        .where(SupportMessage.chatId.in_(chat_ids))
        .order_by(SupportMessage.createdAt.desc())
    )
    last_msgs: dict[int, str] = {}
    for row in msg_res.all():
        if row[0] not in last_msgs:
            last_msgs[row[0]] = row[1]

    return [_to_chat_response(c, users, last_msgs.get(c.id)) for c in chats]


@router.get("/chats", response_model=list[SupportChatResponse])
@limiter.limit("60/minute")
async def list_all_chats(
    request: Request,
    status: Optional[str] = None,
    limit: int = Query(50, ge=1, le=200),
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(check_roles(["admin"])),
):
    stmt = select(SupportChat).order_by(desc(SupportChat.lastMessageAt))
    if status:
        stmt = stmt.where(SupportChat.status == status)
    stmt = stmt.limit(limit)
    res = await db.execute(stmt)
    chats = res.scalars().all()
    if not chats:
        return []

    user_ids = {c.userId for c in chats} | {c.assignedAdminId for c in chats if c.assignedAdminId} | {current_user.id}
    users_res = await db.execute(select(User).where(User.id.in_(user_ids)))
    users = {u.id: u for u in users_res.scalars().all()}

    chat_ids = [c.id for c in chats]
    msg_res = await db.execute(
        select(SupportMessage.chatId, SupportMessage.content)
        .where(SupportMessage.chatId.in_(chat_ids))
        .order_by(SupportMessage.createdAt.desc())
    )
    last_msgs: dict[int, str] = {}
    for row in msg_res.all():
        if row[0] not in last_msgs:
            last_msgs[row[0]] = row[1]

    return [_to_chat_response(c, users, last_msgs.get(c.id)) for c in chats]


@router.get("/chats/{chat_id}/messages", response_model=list[SupportMessageResponse])
@limiter.limit("60/minute")
async def list_messages(
    request: Request,
    chat_id: int,
    limit: int = Query(100, ge=1, le=500),
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    chat_res = await db.execute(select(SupportChat).where(SupportChat.id == chat_id))
    chat = chat_res.scalar_one_or_none()
    if not chat:
        raise HTTPException(status.HTTP_404_NOT_FOUND, "Chat not found")
    if current_user.role != "admin" and chat.userId != current_user.id:
        raise HTTPException(status.HTTP_403_FORBIDDEN, "Access denied")

    res = await db.execute(
        select(SupportMessage)
        .where(SupportMessage.chatId == chat_id)
        .order_by(SupportMessage.createdAt.asc())
        .limit(limit)
    )
    msgs = res.scalars().all()
    user_ids = {m.senderId for m in msgs if m.senderId}
    users_res = await db.execute(select(User).where(User.id.in_(user_ids)))
    users = {u.id: u for u in users_res.scalars().all()}
    return [_to_message_response(m, users) for m in msgs]


@router.post("/chats/{chat_id}/messages", response_model=SupportMessageResponse)
@limiter.limit("30/minute")
async def send_message(
    request: Request,
    chat_id: int,
    req: SupportMessageCreateRequest,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    chat_res = await db.execute(select(SupportChat).where(SupportChat.id == chat_id))
    chat = chat_res.scalar_one_or_none()
    if not chat:
        raise HTTPException(status.HTTP_404_NOT_FOUND, "Chat not found")

    is_admin = current_user.role == "admin"
    if not is_admin and chat.userId != current_user.id:
        raise HTTPException(status.HTTP_403_FORBIDDEN, "Access denied")

    now = datetime.now().isoformat()
    role = "admin" if is_admin else "client"
    msg = SupportMessage(
        chatId=chat_id,
        senderRole=role,
        senderId=current_user.id,
        content=req.content.strip(),
        createdAt=now,
    )
    db.add(msg)

    chat.lastMessageAt = now
    chat.updatedAt = now
    if is_admin:
        chat.unreadByUser += 1
        if chat.status != "closed":
            chat.status = "admin_assigned"
    else:
        chat.unreadByAdmin += 1
        chat.status = "open"

    await db.commit()

    users = {current_user.id: current_user}
    try:
        from main import _broadcast_to_chat
        await _broadcast_to_chat(chat_id, {
            "type": "new_message",
            "data": _to_message_response(msg, users).model_dump(),
        })
    except Exception:
        pass

    # Push notification
    if is_admin:
        tokens = await _user_tokens(db, chat.userId)
        if tokens:
            try:
                await fcm_service.send_notification_to_tokens(
                    tokens,
                    title="Ответ от поддержки",
                    body="Администратор ответил на ваше сообщение",
                    data={"type": "support_chat", "chat_id": str(chat.id)},
                )
            except Exception as e:
                logger.warning("support_push_failed", error=str(e))
    else:
        # Client sent new message — try auto-reply for FAQ
        all_msgs_res = await db.execute(
            select(SupportMessage)
            .where(SupportMessage.chatId == chat_id)
            .order_by(SupportMessage.createdAt.asc())
        )
        all_msgs = all_msgs_res.scalars().all()
        ai_text = await classify_and_reply(db, chat, all_msgs)
        if ai_text:
            ai_msg = SupportMessage(
                chatId=chat_id,
                senderRole="ai",
                content=ai_text,
                createdAt=datetime.now().isoformat(),
            )
            db.add(ai_msg)
            chat.status = "ai_handled"
            chat.unreadByAdmin = 0
            chat.unreadByUser += 1
            chat.lastMessageAt = ai_msg.createdAt
            await db.commit()
            try:
                from main import _broadcast_to_chat
                await _broadcast_to_chat(chat_id, {
                    "type": "new_message",
                    "data": _to_message_response(ai_msg, users).model_dump(),
                })
            except Exception:
                pass
        else:
            chat.status = "waiting_admin"
            await db.commit()
            try:
                from main import _ws_connections
                connected_user_ids = {uid for _, uid in _ws_connections.get(chat.id, [])}
            except Exception:
                connected_user_ids = set()
            tokens = await _admin_tokens(db, exclude_user_ids=connected_user_ids or None)
            if tokens:
                try:
                    await fcm_service.send_notification_to_tokens(
                        tokens,
                        title="Новое обращение",
                        body=f"Сообщение от {current_user.displayName}",
                        data={"type": "support_chat", "chat_id": str(chat.id)},
                    )
                except Exception as e:
                    logger.warning("support_push_failed", error=str(e))

    return _to_message_response(msg, users)


@router.post("/chats/{chat_id}/ai-draft", response_model=AiDraftResponse)
@limiter.limit("20/minute")
async def ai_draft(
    request: Request,
    chat_id: int,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(check_roles(["admin"])),
):
    chat_res = await db.execute(select(SupportChat).where(SupportChat.id == chat_id))
    chat = chat_res.scalar_one_or_none()
    if not chat:
        raise HTTPException(status.HTTP_404_NOT_FOUND, "Chat not found")

    msgs_res = await db.execute(
        select(SupportMessage)
        .where(SupportMessage.chatId == chat_id)
        .order_by(SupportMessage.createdAt.asc())
    )
    msgs = msgs_res.scalars().all()
    draft = await generate_admin_draft(db, chat, msgs)
    return AiDraftResponse(draft=draft)


@router.post("/chats/{chat_id}/assign")
@limiter.limit("30/minute")
async def assign_chat(
    request: Request,
    chat_id: int,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(check_roles(["admin"])),
):
    chat_res = await db.execute(select(SupportChat).where(SupportChat.id == chat_id))
    chat = chat_res.scalar_one_or_none()
    if not chat:
        raise HTTPException(status.HTTP_404_NOT_FOUND, "Chat not found")
    chat.assignedAdminId = current_user.id
    chat.status = "admin_assigned"
    chat.updatedAt = datetime.now().isoformat()
    await db.commit()
    try:
        from main import _broadcast_to_chat
        await _broadcast_to_chat(chat_id, {"type": "status_update", "data": {"assignedAdminId": current_user.id, "status": chat.status}})
    except Exception:
        pass

    # Notify assigned admin
    try:
        client_res = await db.execute(select(User).where(User.id == chat.userId))
        client = client_res.scalar_one_or_none()
        client_name = client.displayName if client else "клиента"
    except Exception:
        client_name = "клиента"
    tokens = await _user_tokens(db, current_user.id)
    if tokens:
        try:
            await fcm_service.send_notification_to_tokens(
                tokens,
                title="Обращение назначено вам",
                body=f"Обращение от {client_name}",
                data={"type": "support_chat", "chat_id": str(chat.id)},
            )
        except Exception as e:
            logger.warning("support_push_failed", error=str(e))

    return {"ok": True}


@router.post("/chats/{chat_id}/close")
@limiter.limit("30/minute")
async def close_chat(
    request: Request,
    chat_id: int,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(check_roles(["admin"])),
):
    chat_res = await db.execute(select(SupportChat).where(SupportChat.id == chat_id))
    chat = chat_res.scalar_one_or_none()
    if not chat:
        raise HTTPException(status.HTTP_404_NOT_FOUND, "Chat not found")
    chat.status = "closed"
    chat.updatedAt = datetime.now().isoformat()
    await db.commit()
    try:
        from main import _broadcast_to_chat
        await _broadcast_to_chat(chat_id, {"type": "status_update", "data": {"status": chat.status}})
    except Exception:
        pass
    return {"ok": True}


@router.post("/chats/{chat_id}/read")
@limiter.limit("60/minute")
async def mark_read(
    request: Request,
    chat_id: int,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    chat_res = await db.execute(select(SupportChat).where(SupportChat.id == chat_id))
    chat = chat_res.scalar_one_or_none()
    if not chat:
        raise HTTPException(status.HTTP_404_NOT_FOUND, "Chat not found")

    if current_user.role == "admin":
        chat.unreadByAdmin = 0
    elif chat.userId == current_user.id:
        chat.unreadByUser = 0
    else:
        raise HTTPException(status.HTTP_403_FORBIDDEN, "Access denied")

    chat.updatedAt = datetime.now().isoformat()
    await db.commit()
    return {"ok": True}
