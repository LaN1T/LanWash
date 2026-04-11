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



async def _track_consumables_usage(db, appt_id, wash_type, additional_services_json):
    # Получаем все услуги, нормализуем имена для поиска
    cursor = await db.execute("SELECT id, name FROM services")
    services = await cursor.fetchall()
    service_map = {row["name"].strip().lower(): row["id"] for row in services}
    # Собираем все оказанные услуги
    all_services = [wash_type.strip().lower()]
    try:
        additional = json.loads(additional_services_json)
        if isinstance(additional, list):
            all_services.extend([s.strip().lower() for s in additional])
    except:
        pass

    print(f"DEBUG: All services extracted: {all_services}")
    print(f"DEBUG: Available services in DB: {list(service_map.keys())}")

    # Для каждой услуги ищем связанные расходники
    for service_name in all_services:
        service_id = None
        for name_in_db, id_in_db in service_map.items():
            if name_in_db in service_name or service_name in name_in_db:
                service_id = id_in_db
                break

        if not service_id:
            print(f"DEBUG: Service NOT FOUND for name: '{service_name}'")
            continue

        print(f"DEBUG: Found service '{service_name}' with ID '{service_id}'")

        cursor = await db.execute(
            "SELECT consumableId, quantity_per_service FROM service_consumables WHERE serviceId = ?",
            (service_id,)
        )
        consumables = await cursor.fetchall()
        print(f"DEBUG: Found {len(consumables)} consumables for service '{service_name}'")
        for c in consumables:
            await db.execute(
                "INSERT INTO consumable_usage_log (appointmentId, consumableId, quantityUsed, timestamp) VALUES (?,?,?,?)",
                (appt_id, c["consumableId"], c["quantity_per_service"], datetime.now().isoformat())
            )

@router.put("/{appt_id}", response_model=AppointmentResponse)
async def update(appt_id: str, req: AppointmentRequest):
    db = await get_db()
    try:
        # Проверяем старый статус
        cursor = await db.execute("SELECT status FROM appointments WHERE id = ?", (appt_id,))
        old_row = await cursor.fetchone()
        
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
        
        # Если статус изменился на completed, трекаем расходники
        if old_row and old_row["status"] != "completed" and req.status == "completed":
            await _track_consumables_usage(db, appt_id, req.washType, req.additionalServices)
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
