from aiogram import Router, types
from aiogram.filters import Command

from core.config import get_settings

router = Router()


@router.message(Command("start"))
async def cmd_start(message: types.Message):
    """Send welcome message with WebApp button."""
    settings = get_settings()
    web_app_url = settings.telegram_mini_app_url or "https://app.lanwash.ru"
    await message.answer(
        "🚗 Добро пожаловать в LanWash!\n\nЗапишитесь на мойку прямо здесь:",
        reply_markup=types.InlineKeyboardMarkup(
            inline_keyboard=[
                [
                    types.InlineKeyboardButton(
                        text="🚿 Открыть LanWash",
                        web_app=types.WebAppInfo(url=web_app_url),
                    )
                ]
            ]
        ),
    )
