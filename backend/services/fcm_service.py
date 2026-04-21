import firebase_admin
from firebase_admin import credentials, messaging
from typing import List, Dict, Any
import os

# Путь к файлу ключа сервисного аккаунта Firebase
# ВАЖНО: Тебе нужно будет скачать этот файл из консоли Firebase и положить его в директорию backend/
# Project settings -> Service accounts -> Generate new private key
SERVICE_ACCOUNT_KEY_PATH = os.path.join(os.path.dirname(__file__), "..", "serviceAccountKey.json")

class FCMService:
    _instance = None

    def __new__(cls):
        if cls._instance is None:
            cls._instance = super(FCMService, cls).__new__(cls)
            cls._instance._initialize_firebase()
        return cls._instance

    def _initialize_firebase(self):
        if not firebase_admin._apps:
            if os.path.exists(SERVICE_ACCOUNT_KEY_PATH):
                cred = credentials.Certificate(SERVICE_ACCOUNT_KEY_PATH)
                firebase_admin.initialize_app(cred)
                print("Firebase Admin SDK initialized successfully.")
            else:
                print(f"WARNING: Firebase service account key not found at {SERVICE_ACCOUNT_KEY_PATH}")
                print("Push notifications will not work until you add the serviceAccountKey.json file.")

    async def send_notification_to_tokens(self, tokens: List[str], title: str, body: str, data: Dict[str, Any] = None):
        if not firebase_admin._apps:
            print("FCMService not initialized. Cannot send notifications.")
            return
        if not tokens:
            return

        message = messaging.MulticastMessage(
            notification=messaging.Notification(title=title, body=body),
            data=data,
            tokens=tokens,
        )
        try:
            response = messaging.send_multicast(message)
            print(f"Successfully sent message: {response.success_count} successful, {response.failure_count} failed.")
            if response.failure_count > 0:
                for resp in response.responses:
                    if not resp.success:
                        print(f"Failed to send to token: {resp.exception}")
            return response
        except Exception as e:
            print(f"Error sending FCM message: {e}")

    async def send_notification_to_topic(self, topic: str, title: str, body: str, data: Dict[str, Any] = None):
        if not firebase_admin._apps:
            print("FCMService not initialized. Cannot send notifications.")
            return
        
        message = messaging.Message(
            notification=messaging.Notification(title=title, body=body),
            data=data,
            topic=topic,
        )
        try:
            response = messaging.send(message)
            print(f"Successfully sent message to topic {topic}: {response}")
            return response
        except Exception as e:
            print(f"Error sending FCM message to topic {topic}: {e}")

fcm_service = FCMService()