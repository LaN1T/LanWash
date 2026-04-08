import json
from fastapi import APIRouter, HTTPException
from database import get_db
from models import AppointmentRequest, AppointmentResponse, AssignWasherRequest
from datetime import datetime

router = APIRouter(prefix="/api/appointments", tags=["appointments"])


def _from_row(row) -> dict:
    return {
        "id": row["id"],
        "userId": row["userId"],
        "clientName": row["clientName"],
        "carModel": row["carModel"],
        "carNumber": row["carNumber"],
        "dateTime": row["dateTime"],
        "washType": row["washType"],
        "additionalServices": row["additionalServices"],
        "status": row["status"],
        "notes": row["notes"],
        "isFavorite": bool(row["isFavorite"]),
        "ownerUsername": row["ownerUsername"],
        "promoPrice": row["promoPrice"],
        "paidPrice": row["paidPrice"],
        "isModifiedByAdmin": bool(row["isModifiedByAdmin"]) if "isModifiedByAdmin" in row.keys() else False,
        "originalPrice": row["originalPrice"] if "originalPrice" in row.keys() else 0,
        "assignedWasher": row["assignedWasher"] if "assignedWasher" in row.keys() else "[]",
    }


@router.get("/", response_model=list[AppointmentResponse])
async def get_all():
    db = await get_db()
    try:
        cursor = await db.execute("SELECT * FROM appointments ORDER BY dateTime ASC")
        rows = await cursor.fetchall()
        return [_from_row(r) for r in rows]
    finally:
        await db.close()


@router.get("/by-owner/{username}", response_model=list[AppointmentResponse])
async def get_by_owner(username: str):
    db = await get_db()
    try:
        cursor = await db.execute(
            "SELECT * FROM appointments WHERE ownerUsername = ? ORDER BY dateTime ASC",
            (username.lower(),),
        )
        rows = await cursor.fetchall()
        return [_from_row(r) for r in rows]
    finally:
        await db.close()


@router.get("/by-washer/{username}", response_model=list[AppointmentResponse])
async def get_by_washer(username: str):
    db = await get_db()
    try:
        # Search for username inside JSON array stored in assignedWasher
        cursor = await db.execute(
            "SELECT * FROM appointments WHERE assignedWasher LIKE ? ORDER BY dateTime ASC",
            (f'%"{username.lower()}"%',),
        )
        rows = await cursor.fetchall()
        return [_from_row(r) for r in rows]
    finally:
        await db.close()


@router.post("/", response_model=AppointmentResponse)
async def create(req: AppointmentRequest):
    db = await get_db()
    try:
        await db.execute(
            """INSERT OR REPLACE INTO appointments
               (id, userId, clientName, carModel, carNumber, dateTime, washType,
                additionalServices, status, notes, isFavorite, ownerUsername, promoPrice, paidPrice, isModifiedByAdmin, originalPrice, assignedWasher)
               VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?)""",
            (
                req.id, None, req.clientName, req.carModel, req.carNumber,
                req.dateTime, req.washType, req.additionalServices, req.status,
                req.notes, int(req.isFavorite), req.ownerUsername, req.promoPrice, req.paidPrice,
                int(req.isModifiedByAdmin), req.originalPrice, req.assignedWasher,
            ),
        )
        await db.commit()
        cursor = await db.execute("SELECT * FROM appointments WHERE id = ?", (req.id,))
        row = await cursor.fetchone()
        return _from_row(row)
    finally:
        await db.close()


@router.put("/{appt_id}", response_model=AppointmentResponse)
async def update(appt_id: str, req: AppointmentRequest):
    db = await get_db()
    try:
        await db.execute(
            """UPDATE appointments SET clientName=?, carModel=?, carNumber=?, dateTime=?,
               washType=?, additionalServices=?, status=?, notes=?, isFavorite=?,
               ownerUsername=?, promoPrice=?, paidPrice=?, isModifiedByAdmin=?, originalPrice=?, assignedWasher=? WHERE id=?""",
            (
                req.clientName, req.carModel, req.carNumber, req.dateTime,
                req.washType, req.additionalServices, req.status, req.notes,
                int(req.isFavorite), req.ownerUsername, req.promoPrice, req.paidPrice,
                int(req.isModifiedByAdmin), req.originalPrice, req.assignedWasher, appt_id,
            ),
        )
        await db.commit()
        cursor = await db.execute("SELECT * FROM appointments WHERE id = ?", (appt_id,))
        row = await cursor.fetchone()
        if not row:
            raise HTTPException(404, "Запись не найдена")
        return _from_row(row)
    finally:
        await db.close()


@router.delete("/{appt_id}")
async def delete(appt_id: str):
    from datetime import datetime
    db = await get_db()
    try:
        # Проверяем есть ли владелец — если да, пишем уведомление
        cursor = await db.execute("SELECT ownerUsername FROM appointments WHERE id = ?", (appt_id,))
        row = await cursor.fetchone()
        if row and row["ownerUsername"]:
            await db.execute(
                "INSERT INTO deleted_notifications (username, createdAt) VALUES (?, ?)",
                (row["ownerUsername"], datetime.now().isoformat()),
            )
        await db.execute("DELETE FROM appointments WHERE id = ?", (appt_id,))
        await db.commit()
        return {"ok": True}
    finally:
        await db.close()


@router.post("/{appt_id}/toggle-favorite")
async def toggle_favorite(appt_id: str):
    db = await get_db()
    try:
        await db.execute(
            "UPDATE appointments SET isFavorite = CASE WHEN isFavorite=1 THEN 0 ELSE 1 END WHERE id=?",
            (appt_id,),
        )
        await db.commit()
        return {"ok": True}
    finally:
        await db.close()


@router.post("/{appt_id}/assign-washer")
async def assign_washer(appt_id: str, req: AssignWasherRequest):
    db = await get_db()
    try:
        cursor = await db.execute("SELECT * FROM appointments WHERE id = ?", (appt_id,))
        row = await cursor.fetchone()
        if not row:
            raise HTTPException(404, "Запись не найдена")

        # Parse current list
        raw = row["assignedWasher"] if "assignedWasher" in row.keys() else "[]"
        try:
            current = json.loads(raw) if raw else []
        except (json.JSONDecodeError, TypeError):
            # Backward compat: old single-string format
            current = [raw] if raw else []

        username = req.washerUsername.lower()
        if username in current:
            # Already assigned — remove (toggle off)
            current.remove(username)
        else:
            if len(current) >= 3:
                raise HTTPException(400, "Максимум 3 мойщика на одну запись")
            current.append(username)

        await db.execute(
            "UPDATE appointments SET assignedWasher = ? WHERE id = ?",
            (json.dumps(current), appt_id),
        )
        await db.commit()
        cursor = await db.execute("SELECT * FROM appointments WHERE id = ?", (appt_id,))
        row = await cursor.fetchone()
        return _from_row(row)
    finally:
        await db.close()


@router.get("/deleted-notification/{username}")
async def get_deleted_notification(username: str):
    db = await get_db()
    try:
        cursor = await db.execute(
            "SELECT COUNT(*) FROM deleted_notifications WHERE username = ?",
            (username.lower(),),
        )
        count = (await cursor.fetchone())[0]
        return {"hasNotification": count > 0}
    finally:
        await db.close()


@router.delete("/deleted-notification/{username}")
async def clear_deleted_notification(username: str):
    db = await get_db()
    try:
        await db.execute(
            "DELETE FROM deleted_notifications WHERE username = ?",
            (username.lower(),),
        )
        await db.commit()
        return {"ok": True}
    finally:
        await db.close()


@router.post("/{appt_id}/clear-admin-flag")
async def clear_admin_flag(appt_id: str):
    db = await get_db()
    try:
        await db.execute(
            "UPDATE appointments SET isModifiedByAdmin = 0 WHERE id=?",
            (appt_id,),
        )
        await db.commit()
        return {"ok": True}
    finally:
        await db.close()


@router.get("/stats")
async def stats():
    db = await get_db()
    try:
        c1 = await db.execute("SELECT COUNT(*) FROM appointments")
        total = (await c1.fetchone())[0]
        c2 = await db.execute("SELECT COUNT(*) FROM appointments WHERE status='scheduled'")
        scheduled = (await c2.fetchone())[0]
        c3 = await db.execute("SELECT COUNT(*) FROM appointments WHERE status='completed'")
        completed = (await c3.fetchone())[0]
        return {"total": total, "scheduled": scheduled, "completed": completed}
    finally:
        await db.close()
