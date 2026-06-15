import os
import re
import uuid
from datetime import datetime, timedelta, timezone
from typing import List, Optional

import jwt
import redis
import structlog
from fastapi import Depends, HTTPException, status
from fastapi.security import OAuth2PasswordBearer
from jwt import PyJWTError as JWTError
from passlib.context import CryptContext
from sqlalchemy.ext.asyncio import AsyncSession

from core.cache import cache
from core.config import get_settings
from core.redis_client import get_redis
from core.transaction import atomic
from db.session import get_db
from models import FcmToken, Referral, User
from repositories import (
    AppointmentRepository,
    FcmTokenRepository,
    ReferralRepository,
    UserRepository,
)

logger = structlog.get_logger()

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


async def _get_redis():
    try:
        client = get_redis()
        if client is not None:
            await client.ping()
        return client
    except Exception:
        return None


async def blacklist_token(jti: str, expires_in_seconds: int):
    """Add a JWT jti to the blacklist with TTL."""
    r = await _get_redis()
    if r:
        try:
            await r.setex(f"{BLACKLIST_PREFIX}{jti}", expires_in_seconds, "1")
        except Exception:
            pass


async def is_token_blacklisted(jti: str) -> bool:
    """Check if a JWT jti is blacklisted."""
    r = await _get_redis()
    if r:
        try:
            return await r.exists(f"{BLACKLIST_PREFIX}{jti}") == 1
        except redis.RedisError as e:
            logger.critical("redis_blacklist_unavailable", error=str(e))
            raise HTTPException(status.HTTP_503_SERVICE_UNAVAILABLE, "Service temporarily unavailable")
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


import asyncio


def verify_password(plain_password: str, hashed_password: str) -> bool:
    return pwd_context.verify(plain_password, hashed_password)


def get_password_hash(password: str) -> str:
    return pwd_context.hash(password)


async def async_verify_password(plain_password: str, hashed_password: str) -> bool:
    return await asyncio.to_thread(verify_password, plain_password, hashed_password)


async def async_get_password_hash(password: str) -> str:
    return await asyncio.to_thread(get_password_hash, password)


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
        if jti and await is_token_blacklisted(jti):
            raise credentials_exception
    except JWTError:
        raise credentials_exception

    user_repo = UserRepository(db)
    user = await user_repo.get_by_username(username)
    if user is None:
        raise credentials_exception
    token_pwd_ver = payload.get("pwd_ver")
    user_pwd_ver = user.passwordVersion if user.passwordVersion is not None else 1
    if token_pwd_ver != user_pwd_ver:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Password changed. Please log in again.",
            headers={"WWW-Authenticate": "Bearer"},
        )
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


class InvalidCredentialsError(Exception):
    pass


class UserNotFoundError(Exception):
    pass


class UsernameAlreadyExistsError(Exception):
    pass


class InvalidReferralCodeError(Exception):
    pass


class SelfReferralError(Exception):
    pass


class ProfileAccessDeniedError(Exception):
    pass


class StatsAccessDeniedError(Exception):
    pass


class FcmTokenAccessDeniedError(Exception):
    pass


class AvatarAccessDeniedError(Exception):
    pass


# Dummy hash for constant-time login (prevents user enumeration via timing)
_DUMMY_ARGON2_HASH = "$argon2id$v=19$m=65536,t=3,p=4$fw/hvFdqba015jynFCJE6A$VHeA4BTTk+oc195w+F46DmejGXJK/bzxYCREJ/OGnbw"

# Referral code alphabet: excludes ambiguous chars 0, O, I, l, 1
_REFERRAL_ALPHABET = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"
_REFERRAL_CODE_LENGTH = 8


def _generate_referral_code() -> str:
    import secrets
    return ''.join(secrets.choice(_REFERRAL_ALPHABET) for _ in range(_REFERRAL_CODE_LENGTH))


async def _ensure_unique_referral_code(db: AsyncSession) -> str:
    """Generate a referral code and ensure it's unique in the DB."""
    user_repo = UserRepository(db)
    while True:
        code = _generate_referral_code()
        existing = await user_repo.get_by_referral_code(code)
        if existing is None:
            return code


class AuthService:
    """Business logic for authentication and user management."""

    def __init__(self, db: AsyncSession) -> None:
        self._db = db
        self._user_repo = UserRepository(db)
        self._referral_repo = ReferralRepository(db)
        self._fcm_repo = FcmTokenRepository(db)
        self._appointment_repo = AppointmentRepository(db)

    async def login(self, username: str, password: str) -> dict:
        user = await self._user_repo.get_by_username(username)
        if not user:
            # Constant-time dummy verification to prevent user enumeration
            await async_verify_password(password, _DUMMY_ARGON2_HASH)
            raise InvalidCredentialsError("Неверный логин или пароль")

        if not await async_verify_password(password, user.passwordHash):
            raise InvalidCredentialsError("Неверный логин или пароль")

        access_token_expires = timedelta(minutes=ACCESS_TOKEN_EXPIRE_MINUTES)
        access_token = create_access_token(
            data={"sub": user.username, "role": user.role, "pwd_ver": user.passwordVersion},
            expires_delta=access_token_expires,
        )
        return {"user": user, "access_token": access_token, "token_type": "bearer"}

    @atomic
    async def register(self, req) -> dict:
        from schemas import RegisterRequest
        if not isinstance(req, RegisterRequest):
            raise TypeError("req must be RegisterRequest")

        username = req.username.lower().strip()

        # Check referral code first (before duplicate check) so we can return specific error
        referrer = None
        if req.referralCode is not None and req.referralCode.strip():
            ref_code = req.referralCode.strip().upper()
            referrer = await self._user_repo.get_by_referral_code(ref_code)
            if not referrer:
                raise InvalidReferralCodeError("Неверный реферальный код.")
            if referrer.username == username:
                raise SelfReferralError("Нельзя использовать свой реферальный код.")

        if await self._user_repo.get_by_username(username):
            raise UsernameAlreadyExistsError("Регистрация не удалась. Проверьте введённые данные.")

        referral_code = await _ensure_unique_referral_code(self._db)

        new_user = User(
            username=username,
            passwordHash=await async_get_password_hash(req.password),
            role="client",
            displayName=req.displayName.strip(),
            email=req.email.strip().lower(),
            phone=req.phone.strip(),
            carModel=req.carModel.strip(),
            carNumber=req.carNumber.strip(),
            createdAt=datetime.now().isoformat(),
            isFavoriteAdmin=0,
            referralCode=referral_code,
        )
        await self._user_repo.add(new_user)
        await self._db.flush()

        if referrer is not None:
            referral_row = Referral(
                referrerId=referrer.id,
                referredId=new_user.id,
                rewardClaimed=False,
                createdAt=datetime.now().isoformat(),
            )
            await self._referral_repo.add(referral_row)

        await self._db.refresh(new_user)

        access_token_expires = timedelta(minutes=ACCESS_TOKEN_EXPIRE_MINUTES)
        access_token = create_access_token(
            data={"sub": new_user.username, "role": new_user.role, "pwd_ver": new_user.passwordVersion},
            expires_delta=access_token_expires,
        )

        return {"user": new_user, "access_token": access_token, "token_type": "bearer"}

    @atomic
    async def _create_telegram_user(
        self, username: str, display_name: str, photo_url: str, telegram_id: str
    ) -> User:
        """Atomic helper: create a new user coming from Telegram auth."""
        import secrets
        import string

        referral_code = await _ensure_unique_referral_code(self._db)
        random_password = ''.join(
            secrets.choice(string.ascii_letters + string.digits) for _ in range(16)
        )
        new_user = User(
            username=username.lower().strip(),
            passwordHash=await async_get_password_hash(random_password),
            role="client",
            displayName=display_name,
            phone="",
            carModel="",
            carNumber="",
            avatarUrl=photo_url,
            createdAt=datetime.now().isoformat(),
            isFavoriteAdmin=0,
            telegramId=telegram_id,
            referralCode=referral_code,
        )
        await self._user_repo.add(new_user)
        await self._db.flush()
        await self._db.refresh(new_user)
        return new_user

    async def telegram_auth(self, init_data: str) -> dict:
        from services.telegram_auth_service import verify_telegram_init_data

        user_data = verify_telegram_init_data(init_data)
        if not user_data:
            raise InvalidCredentialsError("Неверные данные Telegram")

        telegram_id = str(user_data.get("id"))
        username = user_data.get("username") or f"tg_{telegram_id}"
        display_name = user_data.get("first_name") or username
        photo_url = user_data.get("photo_url", "")

        user = await self._user_repo.get_by_telegram_id(telegram_id)

        if not user:
            user = await self._user_repo.get_by_username(username.lower().strip())
            if user:
                user.telegramId = telegram_id
                await self._db.commit()
                await self._db.refresh(user)
            else:
                user = await self._create_telegram_user(
                    username, display_name, photo_url, telegram_id
                )

        access_token_expires = timedelta(minutes=ACCESS_TOKEN_EXPIRE_MINUTES)
        access_token = create_access_token(
            data={"sub": user.username, "role": user.role, "pwd_ver": user.passwordVersion},
            expires_delta=access_token_expires,
        )

        return {"user": user, "access_token": access_token, "token_type": "bearer"}

    async def link_telegram(self, username: str, password: str, telegram_id: str) -> dict:
        user = await self._user_repo.get_by_username(username.lower().strip())

        if not user:
            raise InvalidCredentialsError("Неверный логин или пароль")

        if not await async_verify_password(password, user.passwordHash):
            raise InvalidCredentialsError("Неверный логин или пароль")

        user.telegramId = telegram_id.strip()
        await self._db.commit()

        access_token_expires = timedelta(minutes=ACCESS_TOKEN_EXPIRE_MINUTES)
        access_token = create_access_token(
            data={"sub": user.username, "role": user.role, "pwd_ver": user.passwordVersion},
            expires_delta=access_token_expires,
        )

        return {"user": user, "access_token": access_token, "token_type": "bearer"}

    async def get_washers(self) -> list[dict]:
        cache_key = "washers:list"
        cached = await cache.get(cache_key)
        if cached is not None:
            return cached

        users = await self._user_repo.list_washers()
        data = [
            {
                "id": u.id,
                "username": u.username,
                "displayName": u.displayName,
                "avatarUrl": u.avatarUrl or "",
            }
            for u in users
        ]
        await cache.set(cache_key, data, ttl=300)
        return data

    async def update_profile(self, user_id: int, current_user: User, req, token: str) -> User:
        from schemas import UpdateProfileRequest
        if not isinstance(req, UpdateProfileRequest):
            raise TypeError("req must be UpdateProfileRequest")

        if current_user.id != user_id and current_user.role != "admin":
            raise ProfileAccessDeniedError("Вы не можете редактировать чужой профиль")

        user = await self._user_repo.get_by_id(user_id)
        if not user:
            raise UserNotFoundError("Пользователь не найден")

        updates = {}
        if req.displayName is not None:
            updates["displayName"] = req.displayName
        if req.phone is not None:
            updates["phone"] = req.phone
        if req.carModel is not None:
            updates["carModel"] = req.carModel
        if req.carNumber is not None:
            updates["carNumber"] = req.carNumber
        if req.avatarUrl is not None:
            updates["avatarUrl"] = req.avatarUrl
        if req.newPassword is not None:
            if not req.currentPassword or not await async_verify_password(req.currentPassword, user.passwordHash):
                raise ProfileAccessDeniedError("Неверный текущий пароль")
            password_error = validate_password_strength(req.newPassword)
            if password_error:
                raise ValueError(password_error)
            updates["passwordHash"] = await async_get_password_hash(req.newPassword)
            updates["passwordVersion"] = (user.passwordVersion or 1) + 1
            # Blacklist current token after password change
            try:
                payload = jwt.decode(token, get_settings().jwt_secret_key, algorithms=["HS256"])
                jti = payload.get("jti")
                exp = payload.get("exp")
                if jti and exp:
                    ttl = max(0, int(exp - datetime.now(timezone.utc).timestamp()))
                    await blacklist_token(jti, ttl)
            except jwt.JWTError:
                pass

        if updates:
            await self._user_repo.update_fields(user_id, updates)
            await self._db.commit()
            await self._db.refresh(user)
            if user.role == "washer":
                await cache.delete("washers:list")

        return user

    async def save_fcm_token(self, req, current_user: User) -> dict:
        from schemas import FcmTokenRequest
        if not isinstance(req, FcmTokenRequest):
            raise TypeError("req must be FcmTokenRequest")

        if current_user.username != req.username and current_user.role != "admin":
            raise FcmTokenAccessDeniedError("Вы не можете менять FCM токен другого пользователя")

        existing = await self._fcm_repo.get_by_username(req.username)

        from core.security import encrypt_token

        if existing:
            existing.token = encrypt_token(req.token)
            existing.platform = req.platform
            existing.updatedAt = datetime.now().isoformat()
        else:
            new_token = FcmToken(
                username=req.username,
                token=encrypt_token(req.token),
                platform=req.platform,
                updatedAt=datetime.now().isoformat(),
            )
            await self._fcm_repo.add(new_token)

        await self._db.commit()
        return {"status": "ok"}

    async def update_avatar(self, user_id: int, current_user: User, avatar_url: str) -> User:
        if current_user.id != user_id and current_user.role != "admin":
            raise AvatarAccessDeniedError("Нет доступа к этому профилю")

        await self._user_repo.update_fields(user_id, {"avatarUrl": avatar_url})
        await self._db.commit()

        user = await self._user_repo.get_by_id(user_id)
        if user is None:
            raise UserNotFoundError("Пользователь не найден")
        return user

    async def get_user_stats(self, username: str, current_user: User) -> dict:
        if current_user.username != username.lower() and current_user.role != "admin":
            raise StatsAccessDeniedError("Нет доступа к статистике")

        target_user = await self._user_repo.get_by_username(username.lower())
        if not target_user:
            raise UserNotFoundError("Пользователь не найден")

        if target_user.role == "washer":
            safe_username = username.lower().replace("%", r"\%").replace("_", r"\_")
            explicit = await self._appointment_repo.list_completed_assigned_washer_like(
                safe_username
            )
            explicit_ids = {a.id for a in explicit}

            shift_based = [
                a
                for a in await self._appointment_repo.list_completed_by_shift_for_user(
                    target_user.id
                )
                if a.id not in explicit_ids
            ]

            all_washed = explicit + shift_based
            total_appointments = len(all_washed)
            total_spent = 0
            favorite_wash_type = "-"
            if total_appointments == 0:
                level = "Новичок"
                level_progress = 0
            elif total_appointments <= 19:
                level = "Опытный"
                level_progress = (total_appointments * 100) // 20
            elif total_appointments <= 49:
                level = "Профи"
                level_progress = ((total_appointments - 20) * 100) // 30
            else:
                level = "Мастер"
                level_progress = 100
        else:
            total_appointments = await self._appointment_repo.count_completed_by_owner(
                username.lower()
            )
            total_spent = int(
                await self._appointment_repo.sum_paid_price_completed_by_owner(
                    username.lower()
                )
            )
            favorite_wash_type = (
                await self._appointment_repo.get_favorite_wash_type_completed_by_owner(
                    username.lower()
                )
                or "-"
            )

            if total_appointments == 0:
                level = "Новичок"
                level_progress = 0
            elif total_appointments <= 2:
                level = "Постоянный"
                level_progress = ((total_appointments) * 100) // 3
            elif total_appointments <= 9:
                level = "Любимый клиент"
                level_progress = ((total_appointments - 2) * 100) // 8
            else:
                level = "VIP"
                level_progress = 100

        points = total_appointments

        return {
            "totalAppointments": total_appointments,
            "totalSpent": total_spent,
            "favoriteWashType": favorite_wash_type,
            "level": level,
            "levelProgress": level_progress,
            "points": points,
        }

    async def logout(self, token: str) -> dict:
        try:
            payload = jwt.decode(token, get_settings().jwt_secret_key, algorithms=["HS256"])
            jti = payload.get("jti")
            exp = payload.get("exp")
            if jti and exp:
                ttl = max(0, int(exp - datetime.now(timezone.utc).timestamp()))
                await blacklist_token(jti, ttl)
        except jwt.JWTError:
            pass
        return {"status": "ok"}
