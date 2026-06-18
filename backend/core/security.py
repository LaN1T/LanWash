import os

from cryptography.fernet import Fernet

from core.config import get_settings

settings = get_settings()

# Получаем ключ из .env — обязателен для production
_key_str = os.getenv("FCM_ENCRYPTION_KEY")
if not _key_str:
    if settings.is_production:
        raise RuntimeError(
            "FCM_ENCRYPTION_KEY must be set in production. Generate one with: "
            "python -c 'from cryptography.fernet import Fernet; "
            "print(Fernet.generate_key().decode())'"
        )
    # Fallback для dev/testing только — сгенерировать временный ключ
    from cryptography.fernet import Fernet as _Fernet

    _key_str = _Fernet.generate_key().decode()

key = _key_str.encode()
cipher_suite = Fernet(key)


def encrypt_token(token: str) -> str:
    return cipher_suite.encrypt(token.encode()).decode()


def decrypt_token(encrypted_token: str) -> str:
    return cipher_suite.decrypt(encrypted_token.encode()).decode()
