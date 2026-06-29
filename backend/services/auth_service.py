import asyncio
import os
import re
import uuid
from datetime import datetime, timedelta, timezone
from functools import lru_cache
from typing import List, Optional

import jwt
import redis
import structlog
from fastapi import Depends, HTTPException, status
from fastapi.security import OAuth2PasswordBearer
from jwt import PyJWTError as JWTError
from passlib.context import CryptContext
from sqlalchemy.exc import IntegrityError
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
from schemas import TelegramRegisterRequest
from services.telegram_auth_service import verify_telegram_init_data

logger = structlog.get_logger()

settings = get_settings()

ALGORITHM = "HS256"
ACCESS_TOKEN_EXPIRE_MINUTES = int(os.getenv("ACCESS_TOKEN_EXPIRE_MINUTES", "60"))


@lru_cache(maxsize=1)
def _get_secret_key() -> str:
    """Return the current JWT secret key (cached per process).

    Call ``_get_secret_key.cache_clear()`` after rotating the secret to force
    a reload without restarting the process.
    """
    key = get_settings().jwt_secret_key
    if len(key) < 32:
        raise RuntimeError(
            "JWT_SECRET_KEY слишком короткий. Минимум 32 символа для безопасности."
        )
    return key

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
        return get_redis()
    except Exception as e:
        if settings.is_production:
            raise RuntimeError(f"Redis is required in production: {e}") from e
        logger.warning("redis_unavailable", error=str(e))
        return None


async def blacklist_token(jti: str, expires_in_seconds: int):
    """Add a JWT jti to the blacklist with TTL."""
    r = await _get_redis()
    if r is None:
        if settings.is_production:
            raise RuntimeError(
                "Cannot blacklist token: Redis is not available in production"
            )
        return
    try:
        await r.setex(f"{BLACKLIST_PREFIX}{jti}", expires_in_seconds, "1")
    except redis.RedisError as e:
        logger.critical("token_blacklist_write_failed", jti=jti, error=str(e))
        if settings.is_production:
            raise RuntimeError(f"Failed to blacklist token in production: {e}") from e


async def is_token_blacklisted(jti: str) -> bool:
    """Check if a JWT jti is blacklisted."""
    r = await _get_redis()
    if r is None:
        if settings.is_production:
            raise RuntimeError(
                "Cannot check token blacklist: Redis is not available in production"
            )
        return False
    try:
        return await r.exists(f"{BLACKLIST_PREFIX}{jti}") == 1
    except redis.RedisError as e:
        logger.critical("redis_blacklist_unavailable", error=str(e))
        if settings.is_production:
            raise HTTPException(
                status.HTTP_503_SERVICE_UNAVAILABLE, "Service temporarily unavailable"
            ) from e
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
    to_encode.update(
        {
            "exp": expire,
            "jti": jti,
            "type": "access",
            "iss": settings.jwt_issuer,
            "aud": settings.jwt_audience,
        }
    )
    encoded_jwt = jwt.encode(to_encode, _get_secret_key(), algorithm=ALGORITHM)
    return encoded_jwt


def create_refresh_token(data: dict) -> str:
    to_encode = data.copy()
    jti = str(uuid.uuid4())
    expire = datetime.now(timezone.utc) + timedelta(
        days=settings.jwt_refresh_token_expire_days
    )
    to_encode.update(
        {
            "exp": expire,
            "jti": jti,
            "type": "refresh",
            "iss": settings.jwt_issuer,
            "aud": settings.jwt_audience,
        }
    )
    encoded_jwt = jwt.encode(to_encode, _get_secret_key(), algorithm=ALGORITHM)
    return encoded_jwt


async def get_current_user(
    token: str = Depends(oauth2_scheme), db: AsyncSession = Depends(get_db)
) -> User:
    credentials_exception = HTTPException(
        status_code=status.HTTP_401_UNAUTHORIZED,
        detail="Не удалось проверить учетные данные",
        headers={"WWW-Authenticate": "Bearer"},
    )
    try:
        payload = jwt.decode(
            token,
            _get_secret_key(),
            algorithms=[ALGORITHM],
            issuer=settings.jwt_issuer,
            audience=settings.jwt_audience,
        )
        username: str = payload.get("sub")
        jti: str = payload.get("jti")
        token_type: str = payload.get("type", "access")
        if username is None:
            raise credentials_exception
        if token_type != "access":  # nosec: B105 (token type comparison, not a password)
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
                detail="У вас недостаточно прав для выполнения этого действия",
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


class TelegramNotLinkedError(Exception):
    """Telegram ID is not linked to any existing account."""


class TelegramAlreadyLinkedError(Exception):
    """Telegram ID is already linked to another account."""


# Dummy hash for constant-time login (prevents user enumeration via timing)
_DUMMY_ARGON2_HASH = "$argon2id$v=19$m=65536,t=3,p=4$fw/hvFdqba015jynFCJE6A$VHeA4BTTk+oc195w+F46DmejGXJK/bzxYCREJ/OGnbw"  # noqa: E501

# Referral code alphabet: excludes ambiguous chars 0, O, I, l, 1
_REFERRAL_ALPHABET = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"
_REFERRAL_CODE_LENGTH = 8


def _generate_referral_code() -> str:
    import secrets

    return "".join(
        secrets.choice(_REFERRAL_ALPHABET) for _ in range(_REFERRAL_CODE_LENGTH)
    )


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

    def _issue_token_pair(self, user: User) -> dict:
        access_token_expires = timedelta(minutes=ACCESS_TOKEN_EXPIRE_MINUTES)
        token_data = {
            "sub": user.username,
            "role": user.role,
            "pwd_ver": user.passwordVersion,
        }
        access_token = create_access_token(
            data=token_data, expires_delta=access_token_expires
        )
        refresh_token = create_refresh_token(token_data)
        return {
            "user": user,
            "access_token": access_token,
            "refresh_token": refresh_token,
            # OAuth2 token type, not a password.
            "token_type": "bearer",  # nosec: B105
        }

    async def login(self, username: str, password: str) -> dict:
        user = await self._user_repo.get_by_username(username)
        if not user:
            # Constant-time dummy verification to prevent user enumeration
            await async_verify_password(password, _DUMMY_ARGON2_HASH)
            raise InvalidCredentialsError("Неверный логин или пароль")

        if not await async_verify_password(password, user.passwordHash):
            raise InvalidCredentialsError("Неверный логин или пароль")

        return self._issue_token_pair(user)

    @atomic
    async def register(self, req) -> dict:
        from schemas import RegisterRequest

        if not isinstance(req, RegisterRequest):
            raise TypeError("req must be RegisterRequest")

        username = req.username.lower().strip()

        # Check referral code first (before duplicate check)
        # so we can return specific error
        referrer = None
        if req.referralCode is not None and req.referralCode.strip():
            ref_code = req.referralCode.strip().upper()
            referrer = await self._user_repo.get_by_referral_code(ref_code)
            if not referrer:
                raise InvalidReferralCodeError("Неверный реферальный код.")
            if referrer.username == username:
                raise SelfReferralError("Нельзя использовать свой реферальный код.")

        if await self._user_repo.get_by_username(username):
            raise UsernameAlreadyExistsError(
                "Регистрация не удалась. Проверьте введённые данные."
            )

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
            createdAt=datetime.now(),
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
                createdAt=datetime.now(),
            )
            await self._referral_repo.add(referral_row)

        await self._db.refresh(new_user)

        return self._issue_token_pair(new_user)

    async def telegram_auth(self, init_data: str) -> dict:
        from services.telegram_auth_service import verify_telegram_init_data

        user_data = verify_telegram_init_data(init_data)
        if not user_data:
            raise InvalidCredentialsError("Неверные или устаревшие данные Telegram")

        telegram_id = str(user_data.get("id"))
        if not telegram_id:
            raise InvalidCredentialsError("Неверные данные Telegram")

        user = await self._user_repo.get_by_telegram_id(telegram_id)
        if not user:
            raise TelegramNotLinkedError("Telegram не привязан к аккаунту")

        return self._issue_token_pair(user)

    async def _merge_telegram_user_data(
        self, target_user: User, telegram_id: str
    ) -> None:
        from sqlalchemy import update
        from models import (
            Appointment,
            Car,
            Review,
            ShiftTemplate,
            Subscription,
            SupportChat,
        )

        old_user = await self._user_repo.get_by_telegram_id(telegram_id)
        if not old_user or old_user.id == target_user.id:
            return

        # Models linked by userId FK
        for model in (Car, Subscription, Review, SupportChat):
            await self._db.execute(
                update(model)
                .where(model.userId == old_user.id)
                .values(userId=target_user.id)
            )

        # Models linked by ownerUsername
        await self._db.execute(
            update(Appointment)
            .where(Appointment.ownerUsername == old_user.username)
            .values(ownerUsername=target_user.username, userId=target_user.id)
        )
        await self._db.execute(
            update(ShiftTemplate)
            .where(ShiftTemplate.ownerUsername == old_user.username)
            .values(ownerUsername=target_user.username)
        )

        await self._db.delete(old_user)
        await self._db.flush()

    async def link_telegram(
        self, init_data: str, username: str, password: str
    ) -> dict:
        from services.telegram_auth_service import verify_telegram_init_data

        user_data = verify_telegram_init_data(init_data)
        if not user_data:
            raise InvalidCredentialsError("Неверные данные Telegram")

        telegram_id = str(user_data.get("id"))
        if not telegram_id:
            raise InvalidCredentialsError("Неверные данные Telegram")

        user = await self._user_repo.get_by_username(username.lower().strip())
        if not user:
            # Constant-time dummy verification to prevent username enumeration
            await async_verify_password(password, _DUMMY_ARGON2_HASH)
            raise InvalidCredentialsError("Неверный логин или пароль")

        if not await async_verify_password(password, user.passwordHash):
            raise InvalidCredentialsError("Неверный логин или пароль")

        existing_by_tg = await self._user_repo.get_by_telegram_id(telegram_id)
        if existing_by_tg:
            if existing_by_tg.id == user.id:
                # Idempotent: already linked to this user
                return self._issue_token_pair(user)
            if not existing_by_tg.username.startswith("tg_"):
                raise TelegramAlreadyLinkedError(
                    "Этот Telegram уже привязан к другому аккаунту"
                )
            # Auto-created tg_<id> dummy account: merge data into the real account
            await self._merge_telegram_user_data(user, telegram_id)

        user.telegramId = telegram_id.strip()
        try:
            await self._db.commit()
            await self._db.refresh(user)
        except IntegrityError as exc:
            await self._db.rollback()
            raise TelegramAlreadyLinkedError(
                "Этот Telegram уже привязан к другому аккаунту"
            ) from exc

        return self._issue_token_pair(user)

    @atomic
    async def register_telegram_user(self, req: TelegramRegisterRequest) -> dict:
        if not isinstance(req, TelegramRegisterRequest):
            raise TypeError("req must be TelegramRegisterRequest")

        user_data = verify_telegram_init_data(req.initData)
        if not user_data:
            raise InvalidCredentialsError("Неверные данные Telegram")

        telegram_id = str(user_data.get("id"))
        if not telegram_id:
            raise InvalidCredentialsError("Неверные данные Telegram")

        existing_tg = await self._user_repo.get_by_telegram_id(telegram_id)
        if existing_tg:
            raise TelegramAlreadyLinkedError("Этот Telegram уже используется")

        username = req.username.lower().strip()

        password_error = validate_password_strength(req.password)
        if password_error:
            raise ValueError(password_error)

        # Check referral code before duplicate checks (same as regular register)
        referrer = None
        if req.referralCode is not None and req.referralCode.strip():
            ref_code = req.referralCode.strip().upper()
            referrer = await self._user_repo.get_by_referral_code(ref_code)
            if not referrer:
                raise InvalidReferralCodeError("Неверный реферальный код.")
            if referrer.username == username:
                raise SelfReferralError("Нельзя использовать свой реферальный код.")

        existing_user = await self._user_repo.get_by_username(username)
        if existing_user:
            raise UsernameAlreadyExistsError("Логин уже занят")

        referral_code = await _ensure_unique_referral_code(self._db)
        new_user = User(
            username=username,
            passwordHash=await async_get_password_hash(req.password),
            role="client",
            displayName=req.displayName.strip(),
            phone=req.phone or "",
            carModel=req.carModel or "",
            carNumber=req.carNumber or "",
            avatarUrl=user_data.get("photo_url") or "",
            createdAt=datetime.now(timezone.utc),
            isFavoriteAdmin=0,
            telegramId=telegram_id,
            referralCode=referral_code,
        )

        await self._user_repo.add(new_user)
        await self._db.flush()

        if referrer is not None:
            referral = Referral(
                referrerId=referrer.id,
                referredId=new_user.id,
                rewardClaimed=False,
                createdAt=datetime.now(timezone.utc),
            )
            await self._referral_repo.add(referral)

        await self._db.refresh(new_user)

        return self._issue_token_pair(new_user)

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

    async def update_profile(
        self, user_id: int, current_user: User, req, token: str
    ) -> User:
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
        if req.email is not None:
            updates["email"] = req.email
        if req.carModel is not None:
            updates["carModel"] = req.carModel
        if req.carNumber is not None:
            updates["carNumber"] = req.carNumber
        if req.avatarUrl is not None:
            updates["avatarUrl"] = req.avatarUrl
        if req.newPassword is not None:
            if not req.currentPassword or not await async_verify_password(
                req.currentPassword, user.passwordHash
            ):
                raise ProfileAccessDeniedError("Неверный текущий пароль")
            password_error = validate_password_strength(req.newPassword)
            if password_error:
                raise ValueError(password_error)
            updates["passwordHash"] = await async_get_password_hash(req.newPassword)
            updates["passwordVersion"] = (user.passwordVersion or 1) + 1
            # Blacklist current token after password change
            try:
                payload = jwt.decode(
                    token,
                    _get_secret_key(),
                    algorithms=["HS256"],
                    issuer=settings.jwt_issuer,
                    audience=settings.jwt_audience,
                )
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
            raise FcmTokenAccessDeniedError(
                "Вы не можете менять FCM токен другого пользователя"
            )

        existing = await self._fcm_repo.get_by_username(req.username)

        from core.security import encrypt_token

        if existing:
            existing.token = encrypt_token(req.token)
            existing.platform = req.platform
            existing.updatedAt = datetime.now()
        else:
            new_token = FcmToken(
                username=req.username,
                token=encrypt_token(req.token),
                platform=req.platform,
                updatedAt=datetime.now(),
            )
            await self._fcm_repo.add(new_token)

        await self._db.commit()
        return {"status": "ok"}

    async def update_avatar(
        self, user_id: int, current_user: User, avatar_url: str
    ) -> User:
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
            explicit = await self._appointment_repo.list_completed_assigned_to_washer(
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

    async def refresh_access_token(self, refresh_token: str) -> dict:
        credentials_exception = HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Недействительный refresh-токен",
            headers={"WWW-Authenticate": "Bearer"},
        )
        try:
            payload = jwt.decode(
                refresh_token,
                _get_secret_key(),
                algorithms=["HS256"],
                issuer=settings.jwt_issuer,
                audience=settings.jwt_audience,
            )
        except jwt.JWTError:
            raise credentials_exception

        if payload.get("type") != "refresh":
            raise credentials_exception

        jti = payload.get("jti")
        if jti and await is_token_blacklisted(jti):
            raise credentials_exception

        username = payload.get("sub")
        if username is None:
            raise credentials_exception

        user = await self._user_repo.get_by_username(username)
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

        # Blacklist the old refresh token BEFORE issuing a new pair to prevent
        # concurrent replay attacks.
        if jti:
            exp = payload.get("exp")
            if exp:
                ttl = max(0, int(exp - datetime.now(timezone.utc).timestamp()))
                await blacklist_token(jti, ttl)

        return self._issue_token_pair(user)

    async def logout(self, token: str, refresh_token: str | None = None) -> dict:
        for value in (token, refresh_token):
            if not value:
                continue
            try:
                payload = jwt.decode(
                    value,
                    _get_secret_key(),
                    algorithms=["HS256"],
                    issuer=settings.jwt_issuer,
                    audience=settings.jwt_audience,
                )
                jti = payload.get("jti")
                exp = payload.get("exp")
                if jti and exp:
                    ttl = max(0, int(exp - datetime.now(timezone.utc).timestamp()))
                    await blacklist_token(jti, ttl)
            except jwt.JWTError:
                pass
        return {"status": "ok"}
