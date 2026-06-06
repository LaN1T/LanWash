from aiogram import Bot, Dispatcher
from aiogram.types import Update
from core.config import get_settings
from bot.handlers import router as handlers_router

settings = get_settings()

bot = Bot(token=settings.telegram_bot_token) if settings.telegram_bot_token else None
dp = Dispatcher()
dp.include_router(handlers_router)

async def process_update(update_data: dict):
    if not bot:
        return {"ok": False, "error": "Bot token not configured"}
    update = Update.model_validate(update_data)
    await dp.feed_update(bot, update)
    return {"ok": True}

async def set_webhook(url: str):
    if not bot:
        return False
    await bot.set_webhook(url)
    return True

async def delete_webhook():
    if not bot:
        return False
    await bot.delete_webhook()
    return True
