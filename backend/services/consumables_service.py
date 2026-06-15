import io
import asyncio
import json
import uuid
from datetime import datetime, timedelta

from sqlalchemy import delete, func, select, update
from sqlalchemy.ext.asyncio import AsyncSession

from core.redis_client import get_redis
from models import (
    Consumable,
    ConsumableRefillLog,
    ConsumableUsageLog,
    Service,
    ServiceConsumable,
)
from models import (
    ConsumableRequest,
    RefillRequest,
    ServiceConsumableRequest,
)
from services.inventory_forecast_service import generate_inventory_forecast

try:
    import openpyxl
    from openpyxl.styles import Alignment, Font, PatternFill
    HAS_OPENPYXL = True
except ImportError:
    HAS_OPENPYXL = False


class ConsumableNotFoundError(Exception):
    pass


class ConsumablesService:
    """Business logic for consumables management."""

    def __init__(self, db: AsyncSession) -> None:
        self._db = db

    async def get_all_consumables(self) -> list[Consumable]:
        result = await self._db.execute(select(Consumable).order_by(Consumable.name.asc()))
        return list(result.scalars().all())

    async def get_consumables_by_service(self, service_id: str) -> list[ServiceConsumable]:
        result = await self._db.execute(
            select(ServiceConsumable)
            .where(ServiceConsumable.serviceId == service_id)
            .order_by(ServiceConsumable.consumableId.asc())
        )
        return list(result.scalars().all())

    async def create_consumable(self, req: ConsumableRequest) -> Consumable:
        new_consumable = Consumable(id=str(uuid.uuid4()), name=req.name, unit=req.unit)
        self._db.add(new_consumable)
        await self._db.commit()
        await self._db.refresh(new_consumable)
        return new_consumable

    async def get_low_stock_alerts(self) -> list[Consumable]:
        result = await self._db.execute(
            select(Consumable)
            .where(Consumable.currentStock < Consumable.minStock)
            .order_by(Consumable.name.asc())
        )
        return list(result.scalars().all())

    _FORECAST_CACHE_TTL_SECONDS = 300

    async def get_inventory_forecast(self):
        cache_key = "inventory:forecast"
        try:
            redis = get_redis()
            if redis:
                cached = await redis.get(cache_key)
                if cached:
                    return json.loads(cached)
        except Exception:
            pass

        forecast = await generate_inventory_forecast(self._db)
        data = forecast.model_dump()

        try:
            redis = get_redis()
            if redis:
                await redis.setex(
                    cache_key, self._FORECAST_CACHE_TTL_SECONDS, json.dumps(data)
                )
        except Exception:
            pass

        return data

    async def get_consumable(self, consumable_id: str) -> Consumable | None:
        result = await self._db.execute(select(Consumable).where(Consumable.id == consumable_id))
        return result.scalar_one_or_none()

    async def update_consumable(self, consumable_id: str, req: ConsumableRequest) -> Consumable | None:
        result = await self._db.execute(
            update(Consumable)
            .where(Consumable.id == consumable_id)
            .values(name=req.name, unit=req.unit)
        )
        await self._db.commit()
        if result.rowcount == 0:
            return None
        return await self.get_consumable(consumable_id)

    async def delete_consumable(self, consumable_id: str) -> bool:
        await self._db.execute(
            delete(ServiceConsumable).where(ServiceConsumable.consumableId == consumable_id)
        )
        result = await self._db.execute(
            delete(Consumable).where(Consumable.id == consumable_id)
        )
        await self._db.commit()
        return result.rowcount > 0

    async def refill_consumable(self, consumable_id: str, req: RefillRequest, refilled_by: str) -> Consumable | None:
        result = await self._db.execute(select(Consumable).where(Consumable.id == consumable_id))
        consumable = result.scalar_one_or_none()
        if not consumable:
            return None
        old_stock = consumable.currentStock
        consumable.currentStock += req.amount
        self._db.add(
            ConsumableRefillLog(
                consumableId=consumable_id,
                amount=req.amount,
                oldStock=old_stock,
                newStock=consumable.currentStock,
                refilledBy=refilled_by,
                timestamp=datetime.now().isoformat(),
            )
        )
        await self._db.commit()
        await self._db.refresh(consumable)
        return consumable

    async def get_refill_history(self, consumable_id: str) -> list[dict]:
        result = await self._db.execute(
            select(ConsumableRefillLog)
            .where(ConsumableRefillLog.consumableId == consumable_id)
            .order_by(ConsumableRefillLog.timestamp.desc())
        )
        logs = result.scalars().all()
        return [
            {
                "id": log.id,
                "amount": log.amount,
                "oldStock": log.oldStock,
                "newStock": log.newStock,
                "refilledBy": log.refilledBy,
                "timestamp": log.timestamp,
            }
            for log in logs
        ]

    async def get_consumable_forecast(self, consumable_id: str) -> dict | None:
        res = await self._db.execute(select(Consumable).where(Consumable.id == consumable_id))
        consumable = res.scalar_one_or_none()
        if not consumable:
            return None

        thirty_days_ago = (datetime.now() - timedelta(days=30)).isoformat()
        usage_res = await self._db.execute(
            select(func.coalesce(func.sum(ConsumableUsageLog.quantityUsed), 0.0))
            .where(
                ConsumableUsageLog.consumableId == consumable_id,
                ConsumableUsageLog.timestamp >= thirty_days_ago,
            )
        )
        total_used_30d = usage_res.scalar() or 0.0

        avg_daily = total_used_30d / 30.0 if total_used_30d > 0 else 0.0
        days_left = None
        if avg_daily > 0:
            days_left = consumable.currentStock / avg_daily

        target = consumable.minStock * 3
        to_buy = max(0.0, target - consumable.currentStock)

        return {
            "currentStock": consumable.currentStock,
            "minStock": consumable.minStock,
            "targetStock": target,
            "avgDailyUsage": round(avg_daily, 2),
            "daysLeft": round(days_left, 1) if days_left is not None else None,
            "suggestedPurchase": round(to_buy, 1),
            "unit": consumable.unit,
        }

    async def link_consumable_to_service(self, req: ServiceConsumableRequest) -> dict:
        res_s = await self._db.execute(select(Service).where(Service.id == req.serviceId))
        if not res_s.scalar_one_or_none():
            raise ConsumableNotFoundError(f"Услуга с id={req.serviceId} не найдена")

        res_c = await self._db.execute(select(Consumable).where(Consumable.id == req.consumableId))
        if not res_c.scalar_one_or_none():
            raise ConsumableNotFoundError(f"Расходник с id={req.consumableId} не найден")

        existing = await self._db.execute(
            select(ServiceConsumable).where(
                ServiceConsumable.serviceId == req.serviceId,
                ServiceConsumable.consumableId == req.consumableId,
            )
        )
        link = existing.scalar_one_or_none()
        if link:
            link.quantity_per_service = req.quantity_per_service
        else:
            self._db.add(
                ServiceConsumable(
                    serviceId=req.serviceId,
                    consumableId=req.consumableId,
                    quantity_per_service=req.quantity_per_service,
                )
            )

        await self._db.commit()
        return {
            "serviceId": req.serviceId,
            "consumableId": req.consumableId,
            "quantity_per_service": req.quantity_per_service,
        }

    async def unlink_consumable_from_service(self, service_id: str, consumable_id: str) -> bool:
        result = await self._db.execute(
            delete(ServiceConsumable).where(
                ServiceConsumable.serviceId == service_id,
                ServiceConsumable.consumableId == consumable_id,
            )
        )
        await self._db.commit()
        return result.rowcount > 0

    # ─── Excel export / import helpers ───────────────────────────────────────

    def _create_workbook(self):
        if not HAS_OPENPYXL:
            raise RuntimeError("openpyxl не установлен")
        return openpyxl.Workbook()

    @staticmethod
    def _style_header(cell):
        cell.font = Font(bold=True, color="FFFFFF")
        cell.fill = PatternFill(start_color="1E88E5", end_color="1E88E5", fill_type="solid")
        cell.alignment = Alignment(horizontal="center", vertical="center")

    @staticmethod
    def _auto_width(worksheet):
        for column in worksheet.columns:
            max_length = 0
            column_letter = column[0].column_letter
            for cell in column:
                try:
                    if cell.value:
                        max_length = max(max_length, len(str(cell.value)))
                except Exception:
                    pass
            adjusted_width = min(max_length + 2, 50)
            worksheet.column_dimensions[column_letter].width = adjusted_width

    @staticmethod
    def _sanitize_excel(val):
        if isinstance(val, str) and val and val[0] in ('=', '+', '-', '@', '\t', '\r'):
            return "'" + val
        return val

    _MAX_EXPORT_DAYS = 90

    async def export_consumables(self, date_from: str | None, date_to: str | None) -> bytes:
        if not HAS_OPENPYXL:
            raise RuntimeError("openpyxl не установлен")

        today = datetime.now().date()
        if not date_to:
            date_to = today.isoformat()
        if not date_from:
            date_from = (datetime.fromisoformat(date_to).date() - timedelta(days=30)).isoformat()

        try:
            from_date = datetime.fromisoformat(date_from).date()
            to_date = datetime.fromisoformat(date_to).date()
        except ValueError:
            raise ValueError("date_from and date_to must be valid ISO dates (YYYY-MM-DD)")

        if from_date > to_date:
            raise ValueError("date_from must not be later than date_to")
        if (to_date - from_date).days > self._MAX_EXPORT_DAYS:
            raise ValueError(f"Export range must not exceed {self._MAX_EXPORT_DAYS} days")

        wb = self._create_workbook()
        wb.remove(wb.active)

        # 1. Лист "Остатки"
        ws_stock = wb.create_sheet("Остатки")
        headers_stock = ["ID", "Название", "Ед. изм.", "Текущий запас", "Мин. запас", "Статус"]
        ws_stock.append(headers_stock)
        for cell in ws_stock[1]:
            self._style_header(cell)

        result = await self._db.execute(select(Consumable).order_by(Consumable.name.asc()))
        for c in result.scalars().all():
            status = "Низкий" if c.currentStock < c.minStock else "В норме"
            ws_stock.append([
                self._sanitize_excel(c.id),
                self._sanitize_excel(c.name),
                self._sanitize_excel(c.unit),
                c.currentStock,
                c.minStock,
                self._sanitize_excel(status),
            ])
        self._auto_width(ws_stock)

        # 2. Лист "Пополнения"
        ws_refill = wb.create_sheet("Пополнения")
        headers_refill = ["Расходник", "Количество", "Было", "Стало", "Кем", "Дата"]
        ws_refill.append(headers_refill)
        for cell in ws_refill[1]:
            self._style_header(cell)

        query_refill = select(ConsumableRefillLog).order_by(ConsumableRefillLog.timestamp.desc())
        if date_from:
            query_refill = query_refill.where(ConsumableRefillLog.timestamp >= date_from)
        if date_to:
            query_refill = query_refill.where(ConsumableRefillLog.timestamp <= date_to)

        refill_logs = (await self._db.execute(query_refill)).scalars().all()
        refill_cids = {log.consumableId for log in refill_logs}
        cons_names: dict[str, str] = {}
        if refill_cids:
            c_res = await self._db.execute(
                select(Consumable.id, Consumable.name).where(Consumable.id.in_(refill_cids))
            )
            cons_names = {cid: name for cid, name in c_res.all()}

        for log in refill_logs:
            name = cons_names.get(log.consumableId, log.consumableId)
            ws_refill.append([
                self._sanitize_excel(name),
                log.amount,
                log.oldStock,
                log.newStock,
                self._sanitize_excel(log.refilledBy),
                self._sanitize_excel(log.timestamp),
            ])
        self._auto_width(ws_refill)

        # 3. Лист "Расход"
        ws_usage = wb.create_sheet("Расход")
        headers_usage = ["Расходник", "Ед. изм.", "Использовано", "Период"]
        ws_usage.append(headers_usage)
        for cell in ws_usage[1]:
            self._style_header(cell)

        query_usage = select(ConsumableUsageLog)
        if date_from:
            query_usage = query_usage.where(ConsumableUsageLog.timestamp >= date_from)
        if date_to:
            query_usage = query_usage.where(ConsumableUsageLog.timestamp <= date_to)
        usage_logs = (await self._db.execute(query_usage)).scalars().all()

        usage_cids = {log.consumableId for log in usage_logs}
        consumables_res = await self._db.execute(
            select(Consumable.id, Consumable.name, Consumable.unit)
            .where(Consumable.id.in_(usage_cids))
        )
        consumables_map = {cid: (name, unit) for cid, name, unit in consumables_res.all()}

        usage_sums: dict[str, float] = {}
        for log in usage_logs:
            usage_sums[log.consumableId] = usage_sums.get(log.consumableId, 0.0) + log.quantityUsed

        period_label = f"{date_from or '...'} - {date_to or '...'}"
        for cid, total in sorted(usage_sums.items(), key=lambda x: x[1], reverse=True):
            name, unit = consumables_map.get(cid, (cid, ""))
            ws_usage.append([
                self._sanitize_excel(name),
                self._sanitize_excel(unit),
                round(total, 2),
                self._sanitize_excel(period_label),
            ])
        self._auto_width(ws_usage)

        # 4. Лист "Прогноз"
        ws_forecast = wb.create_sheet("Прогноз")
        headers_forecast = ["Расходник", "Ед. изм.", "Текущий запас", "Средний расход/день", "Хватит на (дн)", "Реком. закупка"]
        ws_forecast.append(headers_forecast)
        for cell in ws_forecast[1]:
            self._style_header(cell)

        all_consumables = (await self._db.execute(select(Consumable))).scalars().all()
        thirty_days_ago = (datetime.now() - timedelta(days=30)).isoformat()

        usage_sums_res = await self._db.execute(
            select(
                ConsumableUsageLog.consumableId,
                func.coalesce(func.sum(ConsumableUsageLog.quantityUsed), 0.0),
            )
            .where(ConsumableUsageLog.timestamp >= thirty_days_ago)
            .group_by(ConsumableUsageLog.consumableId)
        )
        usage_sums_map = {cid: float(total) for cid, total in usage_sums_res.all()}

        for c in all_consumables:
            total_used = usage_sums_map.get(c.id, 0.0)
            avg_daily = total_used / 30.0 if total_used > 0 else 0.0
            days_left = round(c.currentStock / avg_daily, 1) if avg_daily > 0 else "—"
            target = c.minStock * 3
            to_buy = max(0.0, target - c.currentStock)
            ws_forecast.append([
                self._sanitize_excel(c.name),
                self._sanitize_excel(c.unit),
                c.currentStock,
                round(avg_daily, 2),
                self._sanitize_excel(str(days_left)),
                round(to_buy, 1),
            ])
        self._auto_width(ws_forecast)

        buf = io.BytesIO()
        await asyncio.to_thread(wb.save, buf)
        buf.seek(0)
        return buf.getvalue()

    async def generate_import_template(self) -> bytes:
        if not HAS_OPENPYXL:
            raise RuntimeError("openpyxl не установлен")

        wb = self._create_workbook()
        ws = wb.active
        ws.title = "Пополнения"
        headers = ["name", "amount"]
        ws.append(headers)
        for cell in ws[1]:
            self._style_header(cell)
        ws.append(["Автошампунь", 10.0])
        ws.append(["Воск", 5.0])
        self._auto_width(ws)

        buf = io.BytesIO()
        await asyncio.to_thread(wb.save, buf)
        buf.seek(0)
        return buf.getvalue()

    async def import_refills(self, content: bytes, refilled_by: str) -> dict:
        if not HAS_OPENPYXL:
            raise RuntimeError("openpyxl не установлен")

        try:
            wb = await asyncio.to_thread(openpyxl.load_workbook, filename=io.BytesIO(content))
        except Exception as e:
            raise ValueError(f"Не удалось открыть файл: {e}")

        ws = wb.active
        if not ws:
            raise ValueError("Файл пуст")

        header_row = [cell.value for cell in ws[1]]
        header_lower = [str(h).lower().strip() if h else "" for h in header_row]

        name_idx = None
        amount_idx = None
        for i, h in enumerate(header_lower):
            if h in ("name", "название", "расходник", "наименование"):
                name_idx = i
            if h in ("amount", "количество", "кол-во", "колво", "сумма"):
                amount_idx = i

        if name_idx is None or amount_idx is None:
            raise ValueError("Колонки 'name' и 'amount' не найдены в первой строке")

        succeeded = 0
        failed = 0
        errors: list[str] = []
        processed = 0

        all_consumables = (await self._db.execute(select(Consumable))).scalars().all()
        consumables_by_name = {c.name.lower(): c for c in all_consumables}

        for row in ws.iter_rows(min_row=2, values_only=True):
            name = str(row[name_idx]).strip() if row[name_idx] else ""
            amount_raw = row[amount_idx]
            if not name:
                continue
            processed += 1

            try:
                amount = float(amount_raw) if amount_raw is not None else 0.0
            except (ValueError, TypeError):
                failed += 1
                errors.append(f"Строка {processed + 1}: '{amount_raw}' не является числом")
                continue

            if amount <= 0:
                failed += 1
                errors.append(f"Строка {processed + 1}: количество должно быть > 0")
                continue

            consumable = consumables_by_name.get(name.lower())
            if not consumable:
                failed += 1
                errors.append(f"Строка {processed + 1}: расходник '{name}' не найден")
                continue

            old_stock = consumable.currentStock
            consumable.currentStock += amount
            self._db.add(
                ConsumableRefillLog(
                    consumableId=consumable.id,
                    amount=amount,
                    oldStock=old_stock,
                    newStock=consumable.currentStock,
                    refilledBy=refilled_by,
                    timestamp=datetime.now().isoformat(),
                )
            )
            succeeded += 1

        await self._db.commit()

        return {
            "processed": processed,
            "succeeded": succeeded,
            "failed": failed,
            "errors": errors[:20],
        }
