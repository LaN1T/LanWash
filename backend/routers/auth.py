from fastapi import APIRouter, HTTPException, Depends
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, update
from database import get_db
from models import LoginRequest, RegisterRequest, UserResponse, UpdateProfileRequest
from db_models import User
from datetime import datetime
import hashlib

router = APIRouter(prefix="/api/auth", tags=["auth"])

def hash_password(password: str) -> str:
    return hashlib.sha256(password.encode()).hexdigest()

@router.post("/login", response_model=UserResponse)
async def login(req: LoginRequest, db: AsyncSession = Depends(get_db)):
    result = await db.execute(select(User).where(User.username == req.username.lower().strip()))
    user = result.scalar_one_or_none()
    
    if not user or user.passwordHash != hash_password(req.password):
        raise HTTPException(400, "Неверный логин или пароль")
    return user

@router.post("/register", response_model=UserResponse)
async def register(req: RegisterRequest, db: AsyncSession = Depends(get_db)):
    if not req.username.strip():
        raise HTTPException(400, "Введите логин")
    if len(req.password) < 4:
        raise HTTPException(400, "Пароль минимум 4 символа")
    if not req.displayName.strip():
        raise HTTPException(400, "Введите имя")

    result = await db.execute(select(User).where(User.username == req.username.lower().strip()))
    if result.scalar_one_or_none():
        raise HTTPException(400, "Пользователь уже существует")

    new_user = User(
        username=req.username.lower().strip(),
        passwordHash=hash_password(req.password),
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
    return new_user

@router.get("/washers", response_model=list[UserResponse])
async def get_washers(db: AsyncSession = Depends(get_db)):
    result = await db.execute(select(User).where(User.role == 'washer').order_by(User.displayName.asc()))
    return result.scalars().all()

@router.put("/profile/{user_id}", response_model=UserResponse)
async def update_profile(user_id: int, req: UpdateProfileRequest, db: AsyncSession = Depends(get_db)):
    result = await db.execute(select(User).where(User.id == user_id))
    user = result.scalar_one_or_none()
    if not user:
        raise HTTPException(404, "Пользователь не найден")

    updates = {}
    if req.displayName is not None: updates["displayName"] = req.displayName
    if req.phone is not None: updates["phone"] = req.phone
    if req.carModel is not None: updates["carModel"] = req.carModel
    if req.carNumber is not None: updates["carNumber"] = req.carNumber
    if req.newPassword is not None: updates["passwordHash"] = hash_password(req.newPassword)

    if updates:
        await db.execute(update(User).where(User.id == user_id).values(updates))
        await db.commit()
        await db.refresh(user)
        
    return user
