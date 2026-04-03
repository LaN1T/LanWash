from fastapi import APIRouter, HTTPException
from database import get_db
from models import NoteRequest, NoteResponse
from datetime import datetime

router = APIRouter(prefix="/api/notes", tags=["notes"])


def _from_row(row) -> dict:
    return {
        "id": row["id"],
        "username": row["username"],
        "title": row["title"],
        "message": row["message"],
        "category": row["category"],
        "isRead": bool(row["isRead"]),
        "createdAt": row["createdAt"],
    }


@router.get("/", response_model=list[NoteResponse])
async def get_all():
    """Все заметки (для админа)."""
    db = await get_db()
    try:
        cursor = await db.execute(
            "SELECT * FROM washer_notes ORDER BY createdAt DESC"
        )
        rows = await cursor.fetchall()
        return [_from_row(r) for r in rows]
    finally:
        await db.close()


@router.get("/by-user/{username}", response_model=list[NoteResponse])
async def get_by_user(username: str):
    """Заметки конкретного мойщика."""
    db = await get_db()
    try:
        cursor = await db.execute(
            "SELECT * FROM washer_notes WHERE username = ? ORDER BY createdAt DESC",
            (username.lower(),),
        )
        rows = await cursor.fetchall()
        return [_from_row(r) for r in rows]
    finally:
        await db.close()


@router.get("/unread-count")
async def unread_count():
    """Количество непрочитанных заметок (для бейджа у админа)."""
    db = await get_db()
    try:
        cursor = await db.execute(
            "SELECT COUNT(*) FROM washer_notes WHERE isRead = 0"
        )
        count = (await cursor.fetchone())[0]
        return {"count": count}
    finally:
        await db.close()


@router.post("/", response_model=NoteResponse)
async def create(username: str, req: NoteRequest):
    """Создать заметку (мойщик)."""
    db = await get_db()
    try:
        now = datetime.now().isoformat()
        cursor = await db.execute(
            "INSERT INTO washer_notes (username, title, message, category, isRead, createdAt) VALUES (?,?,?,?,0,?)",
            (username.lower(), req.title, req.message, req.category, now),
        )
        await db.commit()
        note_id = cursor.lastrowid
        cursor2 = await db.execute("SELECT * FROM washer_notes WHERE id = ?", (note_id,))
        row = await cursor2.fetchone()
        return _from_row(row)
    finally:
        await db.close()


@router.put("/{note_id}/read")
async def mark_read(note_id: int):
    """Отметить заметку как прочитанную (админ)."""
    db = await get_db()
    try:
        await db.execute(
            "UPDATE washer_notes SET isRead = 1 WHERE id = ?", (note_id,)
        )
        await db.commit()
        return {"ok": True}
    finally:
        await db.close()


@router.put("/read-all")
async def mark_all_read():
    """Отметить все заметки как прочитанные."""
    db = await get_db()
    try:
        await db.execute("UPDATE washer_notes SET isRead = 1")
        await db.commit()
        return {"ok": True}
    finally:
        await db.close()


@router.delete("/{note_id}")
async def delete_note(note_id: int):
    db = await get_db()
    try:
        await db.execute("DELETE FROM washer_notes WHERE id = ?", (note_id,))
        await db.commit()
        return {"ok": True}
    finally:
        await db.close()
