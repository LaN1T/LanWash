import asyncio

from aiogram import Bot
from sqlalchemy.ext.asyncio import AsyncSession

from db.session import AsyncSessionLocal
from services.notification_service import get_pending_notifications, mark_sent_batch


async def poll_notifications(bot: Bot):
    """Poll notification queue and send messages every 30 seconds."""
    while True:
        await asyncio.sleep(30)
        try:
            async with AsyncSessionLocal() as db:
                notifications = await get_pending_notifications(db, limit=100)
                sent_ids = []
                for notification in notifications:
                    try:
                        await bot.send_message(
                            chat_id=int(notification.telegramId),
                            text=notification.message,
                        )
                        sent_ids.append(notification.id)
                    except Exception as e:
                        print(f"Failed to send notification {notification.id}: {e}")
                if sent_ids:
                    await mark_sent_batch(db, sent_ids)
        except Exception as e:
            print(f"Notification poller error: {e}")
