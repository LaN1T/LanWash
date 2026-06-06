import asyncio
from aiogram import Bot
from sqlalchemy.ext.asyncio import AsyncSession, create_async_engine
from sqlalchemy.orm import sessionmaker
from core.config import get_settings
from services.notification_service import get_pending_notifications, mark_sent

settings = get_settings()

# Use the same DATABASE_URL from settings
database_url = settings.database_url
engine = create_async_engine(database_url, echo=False)
async_session = sessionmaker(engine, class_=AsyncSession, expire_on_commit=False)


async def poll_notifications(bot: Bot):
    """Poll notification queue and send messages every 30 seconds."""
    while True:
        await asyncio.sleep(30)
        try:
            async with async_session() as db:
                notifications = await get_pending_notifications(db, limit=100)
                for notification in notifications:
                    try:
                        await bot.send_message(
                            chat_id=int(notification.telegramId),
                            text=notification.message,
                        )
                        await mark_sent(db, notification.id)
                    except Exception as e:
                        print(f"Failed to send notification {notification.id}: {e}")
        except Exception as e:
            print(f"Notification poller error: {e}")
