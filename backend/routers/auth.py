from fastapi import APIRouter, HTTPException, Depends, status, Request
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, update
from database import get_db
from models import LoginRequest, RegisterRequest, UserResponse, UpdateProfileRequest, FcmTokenRequest, LoginResponse
from db_models import User, FcmToken
from datetime import datetime, timedelta
from services.auth_service import (
    get_password_hash, 
    verify_password, 
    create_access_token, 
    ACCESS_TOKEN_EXPIRE_MINUTES,
    get_current_user,
    validate_password_strength
)
import hashlib
from core.security import encrypt_token

from slowapi import _rate_limit_exceeded_handler

# Для использования limiter.limit в роутере, нужно получить его из core.limiter
from core.limiter import limiter

router = APIRouter(prefix="/api/auth", tags=["auth"])

def old_hash_password(password: str) -> str:
    return hashlib.sha256(password.encode()).hexdigest()

@router.post("/login", response_model=LoginResponse)
@limiter.limit("5/minute") # P2: Ограничение 5 запросов в минуту на эндпоинт логина
async def login(req: LoginRequest, request: Request, db: AsyncSession = Depends(get_db)):
    result = await db.execute(select(User).where(User.username == req.username.lower().strip()))
    user = result.scalar_one_or_none()
    
    if not user:
        raise HTTPException(status.HTTP_401_UNAUTHORIZED, "Неверный логин или пароль")

    is_valid = False
    # Пытаемся проверить bcrypt
    try:
        if verify_password(req.password, user.passwordHash):
            is_valid = True
    except Exception:
        # Если это не bcrypt (старый формат), проверяем sha256
        if user.passwordHash == old_hash_password(req.password):
            is_valid = True
            # Мигрируем на bcrypt
            user.passwordHash = get_password_hash(req.password)
            await db.commit()
            await db.refresh(user)

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

@router.post("/register", response_model=LoginResponse)
@limiter.limit("2/minute") # P2: Ограничение 2 запроса в минуту на эндпоинт регистрации
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

@router.get("/washers", response_model=list[UserResponse])
async def get_washers(db: AsyncSession = Depends(get_db), current_user: User = Depends(get_current_user)):
    result = await db.execute(select(User).where(User.role == 'washer').order_by(User.displayName.asc()))
    return result.scalars().all()

@router.put("/profile/{user_id}", response_model=UserResponse)
async def update_profile(user_id: int, req: UpdateProfileRequest, db: AsyncSession = Depends(get_db), current_user: User = Depends(get_current_user)):
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
    if req.newPassword is not None: 
        if len(req.newPassword) < 8:
            raise HTTPException(400, "Новый пароль минимум 8 символов")
        updates["passwordHash"] = get_password_hash(req.newPassword)

    if updates:
        await db.execute(update(User).where(User.id == user_id).values(updates))
        await db.commit()
        await db.refresh(user)
        
    return user

@router.post("/fcm-token")
async def save_fcm_token(req: FcmTokenRequest, db: AsyncSession = Depends(get_db), current_user: User = Depends(get_current_user)):
    # Проверяем, что токен сохраняется для текущего пользователя (или админ сохраняет кому угодно - но обычно клиент сам за себя)
    if current_user.username != req.username and current_user.role != 'admin':
        raise HTTPException(status.HTTP_403_FORBIDDEN, "Вы не можете менять FCM токен другого пользователя")

    result = await db.execute(select(FcmToken).where(FcmToken.username == req.username))
    existing = result.scalar_one_or_none()
    
    if existing:
        existing.token = encrypt_token(req.token)
        existing.platform = req.platform
        existing.updatedAt = datetime.now().isoformat()
    else:
        new_token = FcmToken(
            username=req.username,
            token=encrypt_token(req.token),
            platform=req.platform,
            updatedAt=datetime.now().isoformat()
        )
        db.add(new_token)
    
    await db.commit()
    return {"status": "ok"}
