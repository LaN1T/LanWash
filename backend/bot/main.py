import asyncio
import os
import sys

# Add parent directory to path so we can import backend modules
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from aiogram import Bot, Dispatcher
from core.config import get_settings
from bot.handlers import router as handlers_router
from bot.notifications import poll_notifications

settings = get_settings()

if not settings.telegram_bot_token:
    print("TELEGRAM_BOT_TOKEN is not set. Bot cannot start.")
    sys.exit(1)

bot = Bot(token=settings.telegram_bot_token)
dp = Dispatcher()
dp.include_router(handlers_router)


async def main():
    print("Starting LanWash bot...")
    # Start notification poller in background
    poller_task = asyncio.create_task(poll_notifications(bot))
    # Start polling for bot updates
    await dp.start_polling(bot)
    poller_task.cancel()
    try:
        await poller_task
    except asyncio.CancelledError:
        pass


if __name__ == "__main__":
    asyncio.run(main())
