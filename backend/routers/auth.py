from fastapi import APIRouter, HTTPException
from database import get_db, hash_password
from models import LoginRequest, RegisterRequest, UserResponse, UpdateProfileRequest
from datetime import datetime

router = APIRouter(prefix="/api/auth", tags=["auth"])


def _user_from_row(row) -> dict:
    return {
        "id": row["id"],
        "username": row["username"],
        "role": row["role"],
        "displayName": row["displayName"],
        "phone": row["phone"],
        "carModel": row["carModel"],
        "carNumber": row["carNumber"],
        "createdAt": row["createdAt"],
        "isFavoriteAdmin": bool(row["isFavoriteAdmin"]),
    }


@router.post("/login", response_model=UserResponse)
async def login(req: LoginRequest):
    db = await get_db()
    try:
        cursor = await db.execute(
            "SELECT * FROM users WHERE username = ?",
            (req.username.lower().strip(),),
        )
        user = await cursor.fetchone()
        if not user or user["passwordHash"] != hash_password(req.password):
            raise HTTPException(400, "Неверный логин или пароль")
        return _user_from_row(user)
    finally:
        await db.close()


@router.post("/register", response_model=UserResponse)
async def register(req: RegisterRequest):
    if not req.username.strip():
        raise HTTPException(400, "Введите логин")
    if len(req.password) < 4:
        raise HTTPException(400, "Пароль минимум 4 символа")
    if not req.displayName.strip():
        raise HTTPException(400, "Введите имя")

    db = await get_db()
    try:
        cursor = await db.execute(
            "SELECT id FROM users WHERE username = ?",
            (req.username.lower().strip(),),
        )
        if await cursor.fetchone():
            raise HTTPException(400, "Пользователь уже существует")

        now = datetime.now().isoformat()
        await db.execute(
            "INSERT INTO users (username, passwordHash, role, displayName, phone, carModel, carNumber, createdAt, isFavoriteAdmin) VALUES (?,?,?,?,?,?,?,?,?)",
            (
                req.username.lower().strip(),
                hash_password(req.password),
                "client",
                req.displayName.strip(),
                req.phone.strip(),
                req.carModel.strip(),
                req.carNumber.strip(),
                now,
                0,
            ),
        )
        await db.commit()

        cursor = await db.execute(
            "SELECT * FROM users WHERE username = ?",
            (req.username.lower().strip(),),
        )
        user = await cursor.fetchone()
        return _user_from_row(user)
    finally:
        await db.close()


@router.put("/profile/{user_id}", response_model=UserResponse)
async def update_profile(user_id: int, req: UpdateProfileRequest):
    db = await get_db()
    try:
        cursor = await db.execute("SELECT * FROM users WHERE id = ?", (user_id,))
        user = await cursor.fetchone()
        if not user:
            raise HTTPException(404, "Пользователь не найден")

        updates = {}
        if req.displayName is not None:
            updates["displayName"] = req.displayName
        if req.phone is not None:
            updates["phone"] = req.phone
        if req.carModel is not None:
            updates["carModel"] = req.carModel
        if req.carNumber is not None:
            updates["carNumber"] = req.carNumber
        if req.newPassword is not None:
            updates["passwordHash"] = hash_password(req.newPassword)

        if updates:
            sets = ", ".join(f"{k} = ?" for k in updates)
            vals = list(updates.values()) + [user_id]
            await db.execute(f"UPDATE users SET {sets} WHERE id = ?", vals)
            await db.commit()

        cursor = await db.execute("SELECT * FROM users WHERE id = ?", (user_id,))
        user = await cursor.fetchone()
        return _user_from_row(user)
    finally:
        await db.close()
