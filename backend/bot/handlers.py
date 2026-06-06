from aiogram import Router, types
from aiogram.filters import Command

router = Router()

@router.message(Command("start"))
async def cmd_start(message: types.Message):
    """Send welcome message with WebApp button."""
    web_app_url = "https://t.me/lanwash_bot/LanWash"  # Will be configured properly later
    await message.answer(
        "🚗 Добро пожаловать в LanWash!\n\n"
        "Запишитесь на мойку прямо здесь:",
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
