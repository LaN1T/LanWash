import os
from cryptography.fernet import Fernet

# Получаем ключ из .env
key = os.getenv("FCM_ENCRYPTION_KEY").encode()
cipher_suite = Fernet(key)

def encrypt_token(token: str) -> str:
    return cipher_suite.encrypt(token.encode()).decode()

def decrypt_token(encrypted_token: str) -> str:
    return cipher_suite.decrypt(encrypted_token.encode()).decode()
