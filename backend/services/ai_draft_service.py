import os
from typing import List, Optional
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select
from google import genai
from google.genai import types

from db_models import SupportChat, SupportMessage, User, Appointment
from core.config import get_settings

settings = get_settings()

FAQ_TEXT = """Ты — ассистент автомойки LanWash.
Если вопрос клиента можно ответить по FAQ — дай краткий вежливый ответ.
Если вопрос требует администратора (жалоба, конкретная ситуация с записью, просьба перенести/отменить) — ответь только: ADMIN_NEEDED

FAQ:
- Экспресс-мойка: 500₽, 15 минут
- Стандартная мойка: 800₽, 30 минут
- Комплексная: 1500₽, 60 минут
- Премиум: 2500₽, 90 минут
- Работаем с 8:00 до 22:00 без выходных
- Записаться можно в приложении в разделе "Запись"
"""


def _client():
    key = settings.gemini_api_key or os.environ.get("GEMINI_API_KEY")
    if not key:
        raise RuntimeError("GEMINI_API_KEY not configured")
    return genai.Client(api_key=key)


def _build_history(messages: List[SupportMessage]) -> str:
    lines = []
    for m in messages:
        role = "Клиент" if m.senderRole == "client" else "Админ" if m.senderRole == "admin" else "Ассистент"
        lines.append(f"{role}: {m.content}")
    return "\n".join(lines)


async def classify_and_reply(
    db: AsyncSession,
    chat: SupportChat,
    messages: List[SupportMessage],
) -> Optional[str]:
    """Returns the AI reply text, or None if admin is needed."""
    client = _client()
    history = _build_history(messages)
    prompt = f"{FAQ_TEXT}\n\nИстория диалога:\n{history}\n\nОтветь на последнее сообщение клиента."

    response = await client.aio.models.generate_content(
        model="gemini-1.5-flash-latest",
        contents=prompt,
        config=types.GenerateContentConfig(max_output_tokens=200),
    )
    text = (response.text or "").strip()
    if text == "ADMIN_NEEDED" or not text:
        return None
    return text


async def generate_admin_draft(
    db: AsyncSession,
    chat: SupportChat,
    messages: List[SupportMessage],
) -> str:
    client = _client()

    # Fetch user details
    user_res = await db.execute(select(User).where(User.id == chat.userId))
    user = user_res.scalar_one_or_none()
    user_info = f"Клиент: {user.displayName if user else 'Неизвестно'}, телефон: {user.phone if user else '—'}"

    # Fetch last appointments
    appts_res = await db.execute(
        select(Appointment)
        .where(Appointment.ownerUsername == (user.username if user else ""))
        .order_by(Appointment.dateTime.desc())
        .limit(5)
    )
    appts = appts_res.scalars().all()
    appt_lines = [f"- {a.dateTime}: {a.carModel}, статус {a.status}" for a in appts]
    appt_info = "История записей:\n" + "\n".join(appt_lines) if appt_lines else "История записей отсутствует."

    history = _build_history(messages)
    prompt = (
        f"Ты — опытный администратор автомойки LanWash.\n"
        f"{user_info}\n"
        f"{appt_info}\n\n"
        f"Диалог:\n{history}\n\n"
        f"Напиши вежливый, профессиональный ответ клиенту. "
        f"Будь кратким (не более 3-4 предложений). "
        f"Если не хватает информации — предложи клиенту уточнить детали."
    )

    response = await client.aio.models.generate_content(
        model="gemini-1.5-flash-latest",
        contents=prompt,
        config=types.GenerateContentConfig(max_output_tokens=300),
    )
    return (response.text or "").strip() or "Здравствуйте! Уточните, пожалуйста, детали, чтобы я мог помочь."
