import os
import uuid
from datetime import datetime, timedelta, timezone
import re
from typing import Optional, List
import jwt
from jwt import PyJWTError as JWTError
from passlib.context import CryptContext
from fastapi import Depends, HTTPException, status
from fastapi.security import OAuth2PasswordBearer
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select
from database import get_db
from db_models import User
from core.config import get_settings
from core.redis_client import get_redis

settings = get_settings()

SECRET_KEY = settings.jwt_secret_key
if len(SECRET_KEY) < 32:
    raise RuntimeError("JWT_SECRET_KEY слишком короткий. Минимум 32 символа для безопасности.")

ALGORITHM = "HS256"
ACCESS_TOKEN_EXPIRE_MINUTES = int(os.getenv("ACCESS_TOKEN_EXPIRE_MINUTES", "60"))

BLACKLIST_PREFIX = "jwt_blacklist:"

pwd_context = CryptContext(
    schemes=["argon2"],
    deprecated="auto",
    argon2__memory_cost=65536,
    argon2__time_cost=3,
    argon2__parallelism=4,
    argon2__hash_len=32,
    argon2__salt_len=16,
)
oauth2_scheme = OAuth2PasswordBearer(tokenUrl="api/auth/login")


def _get_redis():
    try:
        return get_redis()
    except Exception:
        return None


def blacklist_token(jti: str, expires_in_seconds: int):
    """Add a JWT jti to the blacklist with TTL."""
    r = _get_redis()
    if r:
        try:
            r.setex(f"{BLACKLIST_PREFIX}{jti}", expires_in_seconds, "1")
        except Exception:
            pass


def is_token_blacklisted(jti: str) -> bool:
    """Check if a JWT jti is blacklisted."""
    r = _get_redis()
    if r:
        try:
            return r.exists(f"{BLACKLIST_PREFIX}{jti}") == 1
        except Exception:
            return False
    return False


def validate_password_strength(password: str) -> Optional[str]:
    if len(password) < 8:
        return "Пароль должен содержать минимум 8 символов."
    if not re.search(r"[A-Z]", password):
        return "Пароль должен содержать хотя бы одну заглавную букву."
    if not re.search(r"[a-z]", password):
        return "Пароль должен содержать хотя бы одну строчную букву."
    if not re.search(r"\d", password):
        return "Пароль должен содержать хотя бы одну цифру."
    if not re.search(r"[@$!%*?&_]", password):
        return "Пароль должен содержать хотя бы один специальный символ (@$!%*?&_)."
    return None


def verify_password(plain_password: str, hashed_password: str) -> bool:
    return pwd_context.verify(plain_password, hashed_password)


def get_password_hash(password: str) -> str:
    return pwd_context.hash(password)


def create_access_token(data: dict, expires_delta: Optional[timedelta] = None):
    to_encode = data.copy()
    jti = str(uuid.uuid4())
    if expires_delta:
        expire = datetime.now(timezone.utc) + expires_delta
    else:
        expire = datetime.now(timezone.utc) + timedelta(minutes=15)
    to_encode.update({"exp": expire, "jti": jti})
    encoded_jwt = jwt.encode(to_encode, SECRET_KEY, algorithm=ALGORITHM)
    return encoded_jwt


async def get_current_user(token: str = Depends(oauth2_scheme), db: AsyncSession = Depends(get_db)) -> User:
    credentials_exception = HTTPException(
        status_code=status.HTTP_401_UNAUTHORIZED,
        detail="Не удалось проверить учетные данные",
        headers={"WWW-Authenticate": "Bearer"},
    )
    try:
        payload = jwt.decode(token, SECRET_KEY, algorithms=[ALGORITHM])
        username: str = payload.get("sub")
        jti: str = payload.get("jti")
        if username is None:
            raise credentials_exception
        if jti and is_token_blacklisted(jti):
            raise credentials_exception
    except JWTError:
        raise credentials_exception

    result = await db.execute(select(User).where(User.username == username))
    user = result.scalar_one_or_none()
    if user is None:
        raise credentials_exception
    return user


def check_roles(allowed_roles: List[str]):
    async def role_checker(current_user: User = Depends(get_current_user)):
        if current_user.role not in allowed_roles:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="У вас недостаточно прав для выполнения этого действия"
            )
        return current_user
    return role_checker
