from fastapi import APIRouter
from database import get_db
from models import LogRequest, LogResponse
from datetime import datetime

router = APIRouter(prefix="/api/logs", tags=["logs"])


def _from_row(row) -> dict:
    return {
        "id": row["id"],
        "username": row["username"],
        "action": row["action"],
        "details": row["details"],
        "timestamp": row["timestamp"],
    }


@router.get("/", response_model=list[LogResponse])
async def get_all(limit: int = 200):
    db = await get_db()
    try:
        cursor = await db.execute(
            "SELECT * FROM logs ORDER BY timestamp DESC LIMIT ?", (limit,)
        )
        rows = await cursor.fetchall()
        return [_from_row(r) for r in rows]
    finally:
        await db.close()


@router.get("/by-user/{username}", response_model=list[LogResponse])
async def get_by_user(username: str):
    db = await get_db()
    try:
        cursor = await db.execute(
            "SELECT * FROM logs WHERE username = ? ORDER BY timestamp DESC",
            (username.lower(),),
        )
        rows = await cursor.fetchall()
        return [_from_row(r) for r in rows]
    finally:
        await db.close()


@router.post("/", response_model=LogResponse)
async def create(req: LogRequest):
    db = await get_db()
    try:
        now = datetime.now().isoformat()
        cursor = await db.execute(
            "INSERT INTO logs (username, action, details, timestamp) VALUES (?,?,?,?)",
            (req.username.lower(), req.action, req.details, now),
        )
        await db.commit()
        log_id = cursor.lastrowid
        cursor2 = await db.execute("SELECT * FROM logs WHERE id = ?", (log_id,))
        row = await cursor2.fetchone()
        return _from_row(row)
    finally:
        await db.close()


@router.delete("/")
async def clear_all():
    db = await get_db()
    try:
        await db.execute("DELETE FROM logs")
        await db.commit()
        return {"ok": True}
    finally:
        await db.close()
