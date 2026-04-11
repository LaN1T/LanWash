from fastapi import APIRouter, HTTPException
from database import get_db
from models import ServiceRequest, ServiceResponse, ToggleFavoriteRequest, ToggleExtraFavoriteRequest
from datetime import datetime

router = APIRouter(prefix="/api/services", tags=["services"])


def _from_row(row) -> dict:
    return {
        "id": row["id"],
        "name": row["name"],
        "description": row["description"],
        "price": row["price"],
        "durationMinutes": row["durationMinutes"],
        "category": row["category"],
        "isFavorite": bool(row["isFavorite"]),
        "isFromApi": bool(row["isFromApi"]),
    }


@router.get("/", response_model=list[ServiceResponse])
async def get_all():
    db = await get_db()
    try:
        cursor = await db.execute("SELECT * FROM services ORDER BY category ASC, name ASC")
        rows = await cursor.fetchall()
        return [_from_row(r) for r in rows]
    finally:
        await db.close()


@router.get("/categories")
async def get_categories():
    db = await get_db()
    try:
        cursor = await db.execute(
            "SELECT DISTINCT category FROM services ORDER BY category"
        )
        rows = await cursor.fetchall()
        return [r["category"] for r in rows]
    finally:
        await db.close()


@router.post("/", response_model=ServiceResponse)
async def create(req: ServiceRequest):
    db = await get_db()
    try:
        now = datetime.now().isoformat()
        await db.execute(
            """INSERT OR REPLACE INTO services
               (id, name, description, price, durationMinutes, category, isFavorite, isFromApi, updatedAt)
               VALUES (?,?,?,?,?,?,?,?,?)""",
            (req.id, req.name, req.description, req.price, req.durationMinutes,
             req.category, int(req.isFavorite), int(req.isFromApi), now),
        )
        await db.commit()
        cursor = await db.execute("SELECT * FROM services WHERE id = ?", (req.id,))
        row = await cursor.fetchone()
        return _from_row(row)
    finally:
        await db.close()


@router.put("/{service_id}", response_model=ServiceResponse)
async def update(service_id: str, req: ServiceRequest):
    db = await get_db()
    try:
        now = datetime.now().isoformat()
        await db.execute(
            """UPDATE services SET name=?, description=?, price=?, durationMinutes=?,
               category=?, isFavorite=?, isFromApi=?, updatedAt=? WHERE id=?""",
            (req.name, req.description, req.price, req.durationMinutes,
             req.category, int(req.isFavorite), int(req.isFromApi), now, service_id),
        )
        await db.commit()
        cursor = await db.execute("SELECT * FROM services WHERE id = ?", (service_id,))
        row = await cursor.fetchone()
        if not row:
            raise HTTPException(404, "Услуга не найдена")
        return _from_row(row)
    finally:
        await db.close()


@router.delete("/{service_id}")
async def delete(service_id: str):
    db = await get_db()
    try:
        await db.execute("DELETE FROM services WHERE id = ?", (service_id,))
        await db.commit()
        return {"ok": True}
    finally:
        await db.close()


# ─── Service Favorites ───────────────────────────────────────────────────────
@router.get("/favorites/{username}")
async def get_service_favorites(username: str):
    db = await get_db()
    try:
        cursor = await db.execute(
            "SELECT serviceId FROM service_favorites WHERE username = ?",
            (username.lower(),),
        )
        rows = await cursor.fetchall()
        return [r["serviceId"] for r in rows]
    finally:
        await db.close()


@router.post("/favorites/toggle")
async def toggle_service_favorite(req: ToggleFavoriteRequest):
    db = await get_db()
    try:
        username = req.username.lower()
        cursor = await db.execute(
            "SELECT 1 FROM service_favorites WHERE username=? AND serviceId=?",
            (username, req.serviceId),
        )
        exists = await cursor.fetchone()
        if exists:
            await db.execute(
                "DELETE FROM service_favorites WHERE username=? AND serviceId=?",
                (username, req.serviceId),
            )
        else:
            await db.execute(
                "INSERT INTO service_favorites (username, serviceId) VALUES (?,?)",
                (username, req.serviceId),
            )
        await db.commit()
        return {"ok": True, "isFavorite": not exists}
    finally:
        await db.close()


# ─── Extra Favorites ─────────────────────────────────────────────────────────
@router.get("/extra-favorites/{username}")
async def get_extra_favorites(username: str):
    db = await get_db()
    try:
        cursor = await db.execute(
            "SELECT serviceName FROM extra_favorites WHERE username = ?",
            (username.lower(),),
        )
        rows = await cursor.fetchall()
        return [r["serviceName"] for r in rows]
    finally:
        await db.close()


@router.post("/extra-favorites/toggle")
async def toggle_extra_favorite(req: ToggleExtraFavoriteRequest):
    db = await get_db()
    try:
        username = req.username.lower()
        cursor = await db.execute(
            "SELECT 1 FROM extra_favorites WHERE username=? AND serviceName=?",
            (username, req.serviceName),
        )
        exists = await cursor.fetchone()
        if exists:
            await db.execute(
                "DELETE FROM extra_favorites WHERE username=? AND serviceName=?",
                (username, req.serviceName),
            )
        else:
            await db.execute(
                "INSERT INTO extra_favorites (username, serviceName) VALUES (?,?)",
                (username, req.serviceName),
            )
        await db.commit()
        return {"ok": True, "isFavorite": not exists}
    finally:
        await db.close()
