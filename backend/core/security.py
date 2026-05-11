import os
from cryptography.fernet import Fernet

# Получаем ключ из .env с fallback для разработки
_key_str = os.getenv("FCM_ENCRYPTION_KEY")
if not _key_str:
    # Генерируем стабильный ключ из SECRET_KEY если FCM ключ не задан
    # NOTE: для продакшена обязательно задать FCM_ENCRYPTION_KEY!
    _fallback = os.getenv("JWT_SECRET_KEY", "dev-fallback-key-32-chars-long!!")
    # Fernet требует base64-encoded 32 байта
    import base64
    _key_str = base64.urlsafe_b64encode(_fallback.ljust(32)[:32].encode()).decode()

key = _key_str.encode()
cipher_suite = Fernet(key)

def encrypt_token(token: str) -> str:
    return cipher_suite.encrypt(token.encode()).decode()

def decrypt_token(encrypted_token: str) -> str:
    return cipher_suite.decrypt(encrypted_token.encode()).decode()
