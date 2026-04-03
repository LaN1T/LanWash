from fastapi import APIRouter
from database import get_db
from models import ConsumableRequest, ConsumableResponse
from datetime import datetime

router = APIRouter(prefix="/api/consumables", tags=["consumables"])


def _from_row(row) -> dict:
    return {
        "id": row["id"],
        "mechanicName": row["mechanicName"],
        "item": row["item"],
        "quantity": row["quantity"],
        "telegramId": row["telegramId"],
        "createdAt": row["createdAt"],
    }


@router.get("/", response_model=list[ConsumableResponse])
async def get_all():
    """Все записи расходников (для админа)."""
    db = await get_db()
    try:
        cursor = await db.execute(
            "SELECT * FROM consumables ORDER BY createdAt DESC"
        )
        rows = await cursor.fetchall()
        return [_from_row(r) for r in rows]
    finally:
        await db.close()


@router.post("/", response_model=ConsumableResponse)
async def create(req: ConsumableRequest):
    """Записать расходник (из бота)."""
    db = await get_db()
    try:
        now = datetime.now().isoformat()
        cursor = await db.execute(
            "INSERT INTO consumables (mechanicName, item, quantity, telegramId, createdAt) VALUES (?,?,?,?,?)",
            (req.mechanicName, req.item, req.quantity, req.telegramId, now),
        )
        await db.commit()
        row_id = cursor.lastrowid
        cursor2 = await db.execute("SELECT * FROM consumables WHERE id = ?", (row_id,))
        row = await cursor2.fetchone()
        return _from_row(row)
    finally:
        await db.close()


@router.delete("/{consumable_id}")
async def delete_consumable(consumable_id: int):
    db = await get_db()
    try:
        await db.execute("DELETE FROM consumables WHERE id = ?", (consumable_id,))
        await db.commit()
        return {"ok": True}
    finally:
        await db.close()
