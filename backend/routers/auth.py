import os
import uuid
import shutil
import json
import re
from fastapi import APIRouter, HTTPException, Depends, status, Request, UploadFile, File
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, update, func, and_
from sqlalchemy.exc import IntegrityError
from database import get_db
from models import (
    LoginRequest, RegisterRequest, UserResponse, UpdateProfileRequest,
    FcmTokenRequest, LoginResponse, UserStatsResponse,
    TelegramAuthRequest, TelegramLinkRequest, TelegramAuthResponse
)
from db_models import User, FcmToken, Appointment, WashType, Shift, Referral
from services.telegram_auth_service import verify_telegram_init_data
import secrets
import string
from datetime import datetime, timedelta
from services.auth_service import (
    get_password_hash,
    verify_password,
    create_access_token,
    ACCESS_TOKEN_EXPIRE_MINUTES,
    get_current_user,
    validate_password_strength,
    blacklist_token,
    oauth2_scheme,
)
import jwt
from core.config import get_settings
from core.security import encrypt_token

USERNAME_PATTERN = re.compile(r'^[a-z0-9_]{3,30}$')

# Referral code alphabet: excludes ambiguous chars 0, O, I, l, 1
_REFERRAL_ALPHABET = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"
_REFERRAL_CODE_LENGTH = 8


def _generate_referral_code() -> str:
    return ''.join(secrets.choice(_REFERRAL_ALPHABET) for _ in range(_REFERRAL_CODE_LENGTH))


async def _ensure_unique_referral_code(db: AsyncSession) -> str:
    """Generate a referral code and ensure it's unique in the DB."""
    while True:
        code = _generate_referral_code()
        result = await db.execute(select(User).where(User.referralCode == code))
        if result.scalar_one_or_none() is None:
            return code


# Dummy hash for constant-time login (prevents user enumeration via timing)
_DUMMY_ARGON2_HASH = "$argon2id$v=19$m=65536,t=3,p=4$fw/hvFdqba015jynFCJE6A$VHeA4BTTk+oc195w+F46DmejGXJK/bzxYCREJ/OGnbw"

# Директория для загрузки аватарок
UPLOAD_DIR = os.path.join(os.path.dirname(os.path.dirname(__file__)), "uploads", "avatars")
os.makedirs(UPLOAD_DIR, exist_ok=True)

import structlog
logger = structlog.get_logger()

from slowapi import _rate_limit_exceeded_handler

# Для использования limiter.limit в роутере, нужно получить его из core.limiter
from core.limiter import limiter

router = APIRouter(
    prefix="/api/auth",
    tags=["auth"],
    
)

@router.post(
    "/login",
    response_model=LoginResponse,
    summary="Вход в систему",
    
)
@limiter.limit("5/minute")
async def login(req: LoginRequest, request: Request, db: AsyncSession = Depends(get_db)):
    result = await db.execute(select(User).where(User.username == req.username.lower().strip()))
    user = result.scalar_one_or_none()
    if not user:
        # Constant-time dummy verification to prevent user enumeration
        verify_password(req.password, _DUMMY_ARGON2_HASH)
        raise HTTPException(status.HTTP_401_UNAUTHORIZED, "Неверный логин или пароль")

    is_valid = verify_password(req.password, user.passwordHash)

    if not is_valid:
        raise HTTPException(status.HTTP_401_UNAUTHORIZED, "Неверный логин или пароль")
    
    access_token_expires = timedelta(minutes=ACCESS_TOKEN_EXPIRE_MINUTES)
    access_token = create_access_token(
        data={"sub": user.username, "role": user.role, "pwd_ver": user.passwordVersion}, 
        expires_delta=access_token_expires
    )
    
    return {
        "user": user,
        "access_token": access_token,
        "token_type": "bearer"
    }

@router.post(
    "/register",
    response_model=LoginResponse,
    summary="Регистрация нового пользователя",
    
)
@limiter.limit("2/minute")
async def register(req: RegisterRequest, request: Request, db: AsyncSession = Depends(get_db)):
    generic_error = HTTPException(status.HTTP_400_BAD_REQUEST, "Регистрация не удалась. Проверьте введённые данные.")

    if not req.username.strip():
        raise generic_error
    
    if not USERNAME_PATTERN.match(req.username.lower().strip()):
        raise generic_error
    
    # P2: Валидация сложности пароля
    password_error = validate_password_strength(req.password)
    if password_error:
        raise generic_error

    if not req.displayName.strip():
        raise generic_error

    # Handle referral code if provided (before duplicate check so we can return specific error)
    referrer = None
    if req.referralCode is not None and req.referralCode.strip():
        ref_code = req.referralCode.strip().upper()
        res = await db.execute(select(User).where(User.referralCode == ref_code))
        referrer = res.scalar_one_or_none()
        if not referrer:
            raise HTTPException(status.HTTP_400_BAD_REQUEST, "Неверный реферальный код.")
        if referrer.username == req.username.lower().strip():
            raise HTTPException(status.HTTP_400_BAD_REQUEST, "Нельзя использовать свой реферальный код.")

    result = await db.execute(select(User).where(User.username == req.username.lower().strip()))
    if result.scalar_one_or_none():
        raise generic_error

    new_user = User(
        username=req.username.lower().strip(),
        passwordHash=get_password_hash(req.password),
        role="client",
        displayName=req.displayName.strip(),
        phone=req.phone.strip(),
        carModel=req.carModel.strip(),
        carNumber=req.carNumber.strip(),
        createdAt=datetime.now().isoformat(),
        isFavoriteAdmin=0,
    )

    for _ in range(10):
        code = _generate_referral_code()
        new_user.referralCode = code
        try:
            db.add(new_user)
            await db.flush()
            break
        except IntegrityError:
            await db.rollback()
            continue
    else:
        raise HTTPException(500, "Could not generate unique referral code")

    # Create referral record if referrer exists
    if referrer is not None:
        referral_row = Referral(
            referrerId=referrer.id,
            referredId=new_user.id,
            rewardClaimed=False,
            createdAt=datetime.now().isoformat(),
        )
        db.add(referral_row)

    await db.commit()
    await db.refresh(new_user)
    
    access_token_expires = timedelta(minutes=ACCESS_TOKEN_EXPIRE_MINUTES)
    access_token = create_access_token(
        data={"sub": new_user.username, "role": new_user.role, "pwd_ver": new_user.passwordVersion}, 
        expires_delta=access_token_expires
    )
    
    return {
        "user": new_user,
        "access_token": access_token,
        "token_type": "bearer"
    }

@router.post(
    "/telegram",
    response_model=TelegramAuthResponse,
    summary="Авторизация через Telegram Mini App",
)
@limiter.limit("10/minute")
async def telegram_auth(
    req: TelegramAuthRequest,
    request: Request,
    db: AsyncSession = Depends(get_db),
):
    user_data = verify_telegram_init_data(req.initData)
    if not user_data:
        raise HTTPException(status.HTTP_401_UNAUTHORIZED, "Неверные данные Telegram")

    telegram_id = str(user_data.get("id"))
    username = user_data.get("username") or f"tg_{telegram_id}"
    display_name = user_data.get("first_name") or username
    photo_url = user_data.get("photo_url", "")

    # Try to find by telegram_id
    result = await db.execute(select(User).where(User.telegramId == telegram_id))
    user = result.scalar_one_or_none()

    if not user:
        # Try to find by username
        result = await db.execute(select(User).where(User.username == username.lower().strip()))
        user = result.scalar_one_or_none()
        if user:
            user.telegramId = telegram_id
            await db.commit()
            await db.refresh(user)
        else:
            # Create new user
            random_password = ''.join(secrets.choice(string.ascii_letters + string.digits) for _ in range(16))
            new_user = User(
                username=username.lower().strip(),
                passwordHash=get_password_hash(random_password),
                role="client",
                displayName=display_name,
                phone="",
                carModel="",
                carNumber="",
                avatarUrl=photo_url,
                createdAt=datetime.now().isoformat(),
                isFavoriteAdmin=0,
                telegramId=telegram_id,
            )

            for _ in range(10):
                code = _generate_referral_code()
                new_user.referralCode = code
                try:
                    db.add(new_user)
                    await db.flush()
                    break
                except IntegrityError:
                    await db.rollback()
                    continue
            else:
                raise HTTPException(500, "Could not generate unique referral code")

            await db.commit()
            await db.refresh(new_user)
            user = new_user

    access_token_expires = timedelta(minutes=ACCESS_TOKEN_EXPIRE_MINUTES)
    access_token = create_access_token(
        data={"sub": user.username, "role": user.role, "pwd_ver": user.passwordVersion},
        expires_delta=access_token_expires,
    )

    return {
        "user": user,
        "access_token": access_token,
        "token_type": "bearer",
    }


@router.post(
    "/link-telegram",
    response_model=TelegramAuthResponse,
    summary="Привязка Telegram к существующему аккаунту",
)
@limiter.limit("5/minute")
async def link_telegram(
    req: TelegramLinkRequest,
    request: Request,
    db: AsyncSession = Depends(get_db),
):
    result = await db.execute(select(User).where(User.username == req.username.lower().strip()))
    user = result.scalar_one_or_none()

    if not user:
        raise HTTPException(status.HTTP_401_UNAUTHORIZED, "Неверный логин или пароль")

    if not verify_password(req.password, user.passwordHash):
        raise HTTPException(status.HTTP_401_UNAUTHORIZED, "Неверный логин или пароль")

    access_token_expires = timedelta(minutes=ACCESS_TOKEN_EXPIRE_MINUTES)
    access_token = create_access_token(
        data={"sub": user.username, "role": user.role, "pwd_ver": user.passwordVersion},
        expires_delta=access_token_expires,
    )

    return {
        "user": user,
        "access_token": access_token,
        "token_type": "bearer",
    }

@router.get(
    "/washers",
    response_model=list[UserResponse],
    summary="Список мойщиков",
    
)
@limiter.limit("60/minute")
async def get_washers(request: Request, db: AsyncSession = Depends(get_db), current_user: User = Depends(get_current_user)):
    result = await db.execute(select(User).where(User.role == 'washer').order_by(User.displayName.asc()))
    return result.scalars().all()

@router.put(
    "/profile/{user_id}",
    response_model=UserResponse,
    summary="Обновление профиля",
    
)
@limiter.limit("10/minute")
async def update_profile(request: Request, user_id: int, req: UpdateProfileRequest, db: AsyncSession = Depends(get_db), current_user: User = Depends(get_current_user), token: str = Depends(oauth2_scheme)):
    if current_user.id != user_id and current_user.role != 'admin':
        raise HTTPException(status.HTTP_403_FORBIDDEN, "Вы не можете редактировать чужой профиль")

    result = await db.execute(select(User).where(User.id == user_id))
    user = result.scalar_one_or_none()
    if not user:
        raise HTTPException(404, "Пользователь не найден")

    updates = {}
    if req.displayName is not None: updates["displayName"] = req.displayName
    if req.phone is not None: updates["phone"] = req.phone
    if req.carModel is not None: updates["carModel"] = req.carModel
    if req.carNumber is not None: updates["carNumber"] = req.carNumber
    if req.avatarUrl is not None: updates["avatarUrl"] = req.avatarUrl
    if req.newPassword is not None:
        if not req.currentPassword or not verify_password(req.currentPassword, user.passwordHash):
            raise HTTPException(status.HTTP_403_FORBIDDEN, "Неверный текущий пароль")
        password_error = validate_password_strength(req.newPassword)
        if password_error:
            raise HTTPException(status.HTTP_400_BAD_REQUEST, detail=password_error)
        updates["passwordHash"] = get_password_hash(req.newPassword)
        updates["passwordVersion"] = (user.passwordVersion or 1) + 1
        # Blacklist current token after password change
        try:
            payload = jwt.decode(token, get_settings().jwt_secret_key, algorithms=["HS256"])
            jti = payload.get("jti")
            exp = payload.get("exp")
            if jti and exp:
                ttl = max(0, int(exp - datetime.now(timezone.utc).timestamp()))
                blacklist_token(jti, ttl)
        except jwt.JWTError:
            pass

    if updates:
        await db.execute(update(User).where(User.id == user_id).values(updates))
        await db.commit()
        await db.refresh(user)

    return user

@router.post(
    "/fcm-token",
    summary="Сохранение FCM-токена",
    
)
@limiter.limit("10/minute")
async def save_fcm_token(request: Request, req: FcmTokenRequest, db: AsyncSession = Depends(get_db), current_user: User = Depends(get_current_user)):
    logger.debug("save_fcm_token", user=current_user.username, req_user=req.username)
    # Проверяем, что токен сохраняется для текущего пользователя (или админ сохраняет кому угодно - но обычно клиент сам за себя)
    if current_user.username != req.username and current_user.role != 'admin':
        raise HTTPException(status.HTTP_403_FORBIDDEN, "Вы не можете менять FCM токен другого пользователя")

    result = await db.execute(select(FcmToken).where(FcmToken.username == req.username))
    existing = result.scalar_one_or_none()
    
    if existing:
        logger.debug("updating_fcm_token", username=req.username)
        existing.token = encrypt_token(req.token)
        existing.platform = req.platform
        existing.updatedAt = datetime.now().isoformat()
    else:
        logger.debug("creating_fcm_token", username=req.username)
        new_token = FcmToken(
            username=req.username,
            token=encrypt_token(req.token),
            platform=req.platform,
            updatedAt=datetime.now().isoformat()
        )
        db.add(new_token)
    
    await db.commit()
    logger.debug("fcm_token_saved")
    return {"status": "ok"}


@router.post("/avatar/{user_id}", response_model=UserResponse)
@limiter.limit("10/minute")
async def upload_avatar(
    request: Request,
    user_id: int,
    file: UploadFile = File(...),
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    if current_user.id != user_id and current_user.role != 'admin':
        raise HTTPException(status.HTTP_403_FORBIDDEN, "Нет доступа к этому профилю")

    # Проверяем формат и размер (макс 5 МБ)
    allowed = {"image/jpeg", "image/png", "image/webp"}
    if file.content_type not in allowed:
        raise HTTPException(400, "Допустимы только JPEG, PNG, WebP")

    allowed_exts = {"jpg", "jpeg", "png", "webp"}
    ext = file.filename.split(".")[-1].lower() if "." in file.filename else "jpg"
    if ext not in allowed_exts:
        raise HTTPException(400, "Недопустимое расширение файла. Допустимы: JPEG, PNG, WebP")

    max_size = 5 * 1024 * 1024  # 5 MB
    content = await file.read()
    if len(content) > max_size:
        raise HTTPException(400, "Файл слишком большой. Максимум 5 МБ")

    # Проверка magic bytes (JPEG, PNG, WebP)
    if content.startswith(b'\xff\xd8\xff'):
        detected = {'jpg', 'jpeg'}
    elif content.startswith(b'\x89PNG\r\n\x1a\n'):
        detected = {'png'}
    elif len(content) >= 12 and content.startswith(b'RIFF') and content[8:12] == b'WEBP':
        detected = {'webp'}
    else:
        raise HTTPException(400, "Файл не является валидным изображением")
    if ext not in detected:
        raise HTTPException(400, "Содержимое файла не соответствует расширению")

    # Восстанавливаем file для дальнейшего использования
    from io import BytesIO
    file.file = BytesIO(content)

    # Сохраняем файл — используем безопасное имя
    filename = f"{uuid.uuid4().hex}.{ext}"
    filepath = os.path.join(UPLOAD_DIR, os.path.basename(filename))

    with open(filepath, "wb") as buffer:
        shutil.copyfileobj(file.file, buffer)

    avatar_url = f"/uploads/avatars/{filename}"

    await db.execute(update(User).where(User.id == user_id).values(avatarUrl=avatar_url))
    await db.commit()

    result = await db.execute(select(User).where(User.id == user_id))
    user = result.scalar_one()
    return user


@router.get("/stats/{username}", response_model=UserStatsResponse)
@limiter.limit("60/minute")
async def get_user_stats(
    request: Request,
    username: str,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    # IDOR: только себе или админ
    if current_user.username != username.lower() and current_user.role != 'admin':
        raise HTTPException(status.HTTP_403_FORBIDDEN, "Нет доступа к статистике")

    # Определяем роль пользователя, чья статистика запрошена
    user_res = await db.execute(select(User).where(User.username == username.lower()))
    target_user = user_res.scalar_one_or_none()
    if not target_user:
        raise HTTPException(404, "Пользователь не найден")

    if target_user.role == 'washer':
        # ─── Статистика мойщика: количество помытых им машин ─────────────────
        # 1. Явно назначенные завершённые записи
        safe_username = username.lower().replace('%', r'\%').replace('_', r'\_')
        res_explicit = await db.execute(
            select(Appointment).where(
                Appointment.assignedWasher.like(f'%"{safe_username}"%', escape='\\'),
                Appointment.status == 'completed'
            )
        )
        explicit = list(res_explicit.scalars().all())
        explicit_ids = {a.id for a in explicit}

        # 2. Завершённые записи по смене
        appt_date = func.substr(Appointment.dateTime, 1, 10)
        appt_time = func.substr(Appointment.dateTime, 12, 5)
        res_shift = await db.execute(
            select(Appointment)
            .join(Shift, and_(
                Shift.userId == target_user.id,
                Shift.date == appt_date,
                appt_time >= Shift.startTime,
                appt_time <= Shift.endTime,
            ))
            .where(Appointment.status == 'completed')
        )
        shift_based = [a for a in res_shift.scalars().all() if a.id not in explicit_ids]

        all_washed = explicit + shift_based
        total_appointments = len(all_washed)
        total_spent = 0
        favorite_wash_type = '-'
        # У мойщика своя шкала: Новичок / Опытный / Профи
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
        # ─── Статистика клиента ──────────────────────────────────────────────
        res_count = await db.execute(
            select(func.count(Appointment.id)).where(
                Appointment.ownerUsername == username.lower(),
                Appointment.status == 'completed'
            )
        )
        total_appointments = res_count.scalar() or 0

        res_spent = await db.execute(
            select(func.sum(Appointment.paidPrice)).where(
                Appointment.ownerUsername == username.lower(),
                Appointment.status == 'completed'
            )
        )
        total_spent = res_spent.scalar() or 0

        res_fav = await db.execute(
            select(WashType.name, func.count(Appointment.id))
            .join(Appointment, Appointment.washTypeId == WashType.id)
            .where(
                Appointment.ownerUsername == username.lower(),
                Appointment.status == 'completed'
            )
            .group_by(WashType.name)
            .order_by(func.count(Appointment.id).desc())
            .limit(1)
        )
        fav_row = res_fav.first()
        favorite_wash_type = fav_row[0] if fav_row else '-'

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

    return UserStatsResponse(
        totalAppointments=total_appointments,
        totalSpent=total_spent,
        favoriteWashType=favorite_wash_type,
        level=level,
        levelProgress=level_progress,
        points=points
    )


@router.post("/logout")
@limiter.limit("10/minute")
async def logout(
    request: Request,
    current_user: User = Depends(get_current_user),
):
    """Invalidate the current JWT token by blacklisting its jti."""
    auth_header = request.headers.get("Authorization", "")
    if auth_header.startswith("Bearer "):
        token = auth_header[7:]
        try:
            payload = jwt.decode(token, get_settings().jwt_secret_key, algorithms=["HS256"])
            jti = payload.get("jti")
            exp = payload.get("exp")
            if jti and exp:
                ttl = max(0, int(exp - datetime.now(timezone.utc).timestamp()))
                blacklist_token(jti, ttl)
        except jwt.JWTError:
            pass
    return {"status": "ok"}


