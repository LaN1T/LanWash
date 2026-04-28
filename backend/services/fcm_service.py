import firebase_admin
from firebase_admin import credentials, messaging
from typing import List, Dict, Any
import os

class FCMService:
    _instance = None

    def __new__(cls):
        if cls._instance is None:
            cls._instance = super(FCMService, cls).__new__(cls)
            cls._instance._initialize_firebase()
        return cls._instance

    def _initialize_firebase(self):
        if not firebase_admin._apps:
            project_id = os.getenv("FIREBASE_PROJECT_ID")
            if project_id:
                cred_dict = {
                    "type": "service_account",
                    "project_id": project_id,
                    "private_key_id": os.getenv("FIREBASE_PRIVATE_KEY_ID"),
                    "private_key": os.getenv("FIREBASE_PRIVATE_KEY", "").replace(r'\n', '\n'),
                    "client_email": os.getenv("FIREBASE_CLIENT_EMAIL"),
                    "client_id": os.getenv("FIREBASE_CLIENT_ID"),
                    "auth_uri": os.getenv("FIREBASE_AUTH_URI"),
                    "token_uri": os.getenv("FIREBASE_TOKEN_URI"),
                    "auth_provider_x509_cert_url": os.getenv("FIREBASE_AUTH_PROVIDER_X509_CERT_URL"),
                    "client_x509_cert_url": os.getenv("FIREBASE_CLIENT_X509_CERT_URL"),
                }
                try:
                    cred = credentials.Certificate(cred_dict)
                    firebase_admin.initialize_app(cred)
                    print("Firebase Admin SDK initialized successfully via Environment Variables.")
                except Exception as e:
                    print(f"Error initializing Firebase via Env Vars: {e}")
            else:
                print("WARNING: Firebase env vars not set. Notifications will not work.")

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
            response = messaging.send_each_for_multicast(message)
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