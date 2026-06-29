import asyncio
from typing import Any, Dict, List

import firebase_admin
import structlog
from firebase_admin import credentials, messaging

from core.config import get_settings

logger = structlog.get_logger()


class FCMService:
    _instance = None

    def __new__(cls):
        if cls._instance is None:
            cls._instance = super(FCMService, cls).__new__(cls)
            cls._instance._initialize_firebase()
        return cls._instance

    def _initialize_firebase(self):
        if firebase_admin._apps:
            return
        settings = get_settings()
        project_id = settings.firebase_project_id
        if not project_id:
            logger.warning("firebase_project_id_not_set")
            return
        cred_dict = {
            "type": "service_account",
            "project_id": project_id,
            "private_key_id": settings.firebase_private_key_id,
            "private_key": settings.firebase_private_key.replace(r"\n", "\n"),
            "client_email": settings.firebase_client_email,
            "client_id": settings.firebase_client_id,
            "auth_uri": settings.firebase_auth_uri,
            "token_uri": settings.firebase_token_uri,
            "auth_provider_x509_cert_url": (
                settings.firebase_auth_provider_x509_cert_url
            ),
            "client_x509_cert_url": settings.firebase_client_x509_cert_url,
        }
        try:
            cred = credentials.Certificate(cred_dict)
            firebase_admin.initialize_app(cred)
            logger.info("firebase_initialized")
        except Exception as e:
            logger.error("firebase_init_failed", error=str(e))
            if settings.is_production:
                raise RuntimeError(
                    f"Firebase initialization failed in production: {e}"
                ) from e

    async def send_notification_to_tokens(
        self, tokens: List[str], title: str, body: str, data: Dict[str, Any] = None
    ):
        if not firebase_admin._apps:
            logger.warning("fcm_not_initialized")
            return
        if not tokens:
            return

        # FCM multicast supports up to 500 tokens per request.
        batch_size = 500
        total_success = 0
        total_failure = 0
        for i in range(0, len(tokens), batch_size):
            batch = tokens[i : i + batch_size]
            message = messaging.MulticastMessage(
                notification=messaging.Notification(title=title, body=body),
                data=data,
                tokens=batch,
            )
            try:
                response = await asyncio.wait_for(
                    asyncio.to_thread(messaging.send_each_for_multicast, message),
                    timeout=10.0,
                )
                total_success += response.success_count
                total_failure += response.failure_count
                if response.failure_count > 0:
                    for resp in response.responses:
                        if not resp.success:
                            logger.warning(
                                "fcm_token_failed", error=str(resp.exception)
                            )
            except asyncio.TimeoutError:
                logger.error("fcm_send_timeout")
            except Exception as e:
                logger.error("fcm_send_error", error=str(e))
        logger.info("fcm_message_sent", success=total_success, failure=total_failure)

    async def send_notification_to_topic(
        self, topic: str, title: str, body: str, data: Dict[str, Any] = None
    ):
        if not firebase_admin._apps:
            logger.warning("fcm_not_initialized")
            return

        message = messaging.Message(
            notification=messaging.Notification(title=title, body=body),
            data=data,
            topic=topic,
        )
        try:
            response = await asyncio.wait_for(
                asyncio.to_thread(messaging.send, message),
                timeout=10.0,
            )
            logger.info("fcm_topic_sent", topic=topic, response=str(response))
            return response
        except asyncio.TimeoutError:
            logger.error("fcm_topic_timeout", topic=topic)
        except Exception as e:
            logger.error("fcm_topic_error", topic=topic, error=str(e))


fcm_service = FCMService()
