import os
import uuid
import shutil
import json
from fastapi import APIRouter, HTTPException, Depends, status, Request, UploadFile, File
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, update, func, and_
from database import get_db
from models import (
    LoginRequest, RegisterRequest, UserResponse, UpdateProfileRequest,
    FcmTokenRequest, LoginResponse, UserStatsResponse
)
from db_models import User, FcmToken, Appointment, WashType, Shift
from datetime import datetime, timedelta
from services.auth_service import (
    get_password_hash,
    verify_password,
    create_access_token,
    ACCESS_TOKEN_EXPIRE_MINUTES,
    get_current_user,
    validate_password_strength
)
from core.security import encrypt_token

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
        raise HTTPException(status.HTTP_401_UNAUTHORIZED, "Неверный логин или пароль")

    is_valid = verify_password(req.password, user.passwordHash)

    if not is_valid:
        raise HTTPException(status.HTTP_401_UNAUTHORIZED, "Неверный логин или пароль")
    
    access_token_expires = timedelta(minutes=ACCESS_TOKEN_EXPIRE_MINUTES)
    access_token = create_access_token(
        data={"sub": user.username, "role": user.role}, 
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
    if not req.username.strip():
        raise HTTPException(400, "Введите логин")
    
    # P2: Валидация сложности пароля
    password_error = validate_password_strength(req.password)
    if password_error:
        raise HTTPException(status.HTTP_400_BAD_REQUEST, detail=password_error)

    if not req.displayName.strip():
        raise HTTPException(400, "Введите имя")

    result = await db.execute(select(User).where(User.username == req.username.lower().strip()))
    if result.scalar_one_or_none():
        raise HTTPException(400, "Пользователь уже существует")

    new_user = User(
        username=req.username.lower().strip(),
        passwordHash=get_password_hash(req.password),
        role="client",
        displayName=req.displayName.strip(),
        phone=req.phone.strip(),
        carModel=req.carModel.strip(),
        carNumber=req.carNumber.strip(),
        createdAt=datetime.now().isoformat(),
        isFavoriteAdmin=0
    )
    db.add(new_user)
    await db.commit()
    await db.refresh(new_user)
    
    access_token_expires = timedelta(minutes=ACCESS_TOKEN_EXPIRE_MINUTES)
    access_token = create_access_token(
        data={"sub": new_user.username, "role": new_user.role}, 
        expires_delta=access_token_expires
    )
    
    return {
        "user": new_user,
        "access_token": access_token,
        "token_type": "bearer"
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
async def update_profile(request: Request, user_id: int, req: UpdateProfileRequest, db: AsyncSession = Depends(get_db), current_user: User = Depends(get_current_user)):
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
        password_error = validate_password_strength(req.newPassword)
        if password_error:
            raise HTTPException(status.HTTP_400_BAD_REQUEST, detail=password_error)
        updates["passwordHash"] = get_password_hash(req.newPassword)

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

    max_size = 5 * 1024 * 1024  # 5 MB
    content = await file.read()
    if len(content) > max_size:
        raise HTTPException(400, "Файл слишком большой. Максимум 5 МБ")

    # Восстанавливаем file для дальнейшего использования
    from io import BytesIO
    file.file = BytesIO(content)

    # Сохраняем файл — валидируем расширение и используем безопасное имя
    allowed_exts = {"jpg", "jpeg", "png", "webp"}
    ext = file.filename.split(".")[-1].lower() if "." in file.filename else "jpg"
    if ext not in allowed_exts:
        raise HTTPException(400, "Недопустимое расширение файла. Допустимы: JPEG, PNG, WebP")
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
        res_explicit = await db.execute(
            select(Appointment).where(
                Appointment.assignedWasher.like(f'%"{username.lower()}"%'),
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



