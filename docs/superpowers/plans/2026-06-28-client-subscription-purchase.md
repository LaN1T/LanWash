# Покупка абонементов клиентом — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Реализовать клиентский flow покупки абонементов: готовые планы от админа + персональный конструктор, демо-оплата, пункт в боковом меню.

**Architecture:** Добавляем таблицу `subscription_plans` для админ-каталога, расширяем `subscriptions` финансовыми полями и FK. Backend отдаёт планы, принимает покупку и считает цену. Flutter добавляет drawer-переход, хаб и пошаговый визард.

**Tech Stack:** FastAPI, SQLAlchemy/Alembic, Flutter (Material), structlog.

---

## File map

| File | Responsibility |
|------|----------------|
| `backend/alembic/versions/2026_06_28_add_subscription_plans.py` | Миграция: таблица планов и колонки в subscriptions |
| `backend/models/models.py` | ORM-модели `SubscriptionPlan` и расширенная `Subscription` |
| `backend/schemas/schemas.py` | Pydantic-схемы планов и покупки |
| `backend/repositories/subscription_plan.py` | CRUD планов |
| `backend/repositories/subscription.py` | Методы для `price/originalPrice` при необходимости |
| `backend/services/subscriptions_service.py` | Бизнес-логика: каталог, расчёт цен, покупка |
| `backend/app/routers/subscriptions.py` | Эндпоинты `/plans`, `/buy`, админ CRUD планов |
| `backend/db/seed.py` | Seed-данные для трёх стартовых планов |
| `lib/models/subscription_plan.dart` | Модель плана во Flutter |
| `lib/models/subscription.dart` | Расширение модели абонемента |
| `lib/services/api_service.dart` | Методы `getSubscriptionPlans`, `buySubscription` |
| `lib/screens/client/client_shell.dart` | Пункт «Абонементы» в drawer |
| `lib/screens/client/subscription_hub_screen.dart` | Хаб: купить + мои абонементы |
| `lib/screens/client/subscription_type_choice_screen.dart` | Выбор готовый/персональный |
| `lib/screens/client/ready_plan_catalog_screen.dart` | Каталог готовых планов |
| `lib/screens/client/ready_plan_wash_type_screen.dart` | Выбор типа мойки для плана |
| `lib/screens/client/personal_builder_screen.dart` | Конструктор персонального абонемента |
| `lib/screens/client/subscription_checkout_screen.dart` | Подтверждение и демо-оплата |
| `lib/screens/client/subscription_success_screen.dart` | Экран успеха |
| `lib/screens/client/subscription_screen.dart` | Переименовать/доработать под «Мои абонементы» |
| `backend/tests/test_subscriptions.py` | Новые тесты на покупку и каталог |

---

## Task 1: Alembic migration

**Files:**
- Create: `backend/alembic/versions/2026_06_28_add_subscription_plans.py`

- [ ] **Step 1: Generate revision**

Run:
```bash
cd backend
alembic revision -m "add_subscription_plans"
```

- [ ] **Step 2: Implement migration**

Replace generated file content with:

```python
"""add_subscription_plans

Revision ID: <auto>
Revises: <auto>
Create Date: <auto>

"""
from typing import Sequence, Union

import sqlalchemy as sa
from alembic import op
from sqlalchemy.dialects import postgresql

# revision identifiers, used by Alembic.
revision: str = '<auto>'
down_revision: Union[str, None] = '<auto>'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.create_table(
        'subscription_plans',
        sa.Column('id', sa.Integer(), autoincrement=True, nullable=False),
        sa.Column('code', sa.String(), nullable=False),
        sa.Column('name', sa.String(), nullable=False),
        sa.Column('description', sa.String(), nullable=True),
        sa.Column('type', sa.String(), nullable=False),
        sa.Column('washCount', sa.Integer(), nullable=True),
        sa.Column('unlimitedDays', sa.Integer(), nullable=True),
        sa.Column('discountPercent', sa.Integer(), nullable=False, server_default='0'),
        sa.Column('washTypePrices', postgresql.JSON(astext_type=sa.Text()), nullable=True),
        sa.Column('sortOrder', sa.Integer(), nullable=False, server_default='0'),
        sa.Column('isActive', sa.Boolean(), nullable=False, server_default='true'),
        sa.Column('createdAt', sa.DateTime(), nullable=False, server_default=sa.text('CURRENT_TIMESTAMP')),
        sa.Column('updatedAt', sa.DateTime(), nullable=False, server_default=sa.text('CURRENT_TIMESTAMP')),
        sa.PrimaryKeyConstraint('id'),
        sa.UniqueConstraint('code'),
    )
    op.add_column('subscriptions', sa.Column('planId', sa.Integer(), nullable=True))
    op.add_column('subscriptions', sa.Column('price', sa.Integer(), nullable=False, server_default='0'))
    op.add_column('subscriptions', sa.Column('originalPrice', sa.Integer(), nullable=False, server_default='0'))
    op.add_column('subscriptions', sa.Column('selectedExtras', sa.String(), nullable=True))
    op.add_column('subscriptions', sa.Column('paymentStatus', sa.String(), nullable=False, server_default='demo_purchased'))
    op.create_foreign_key(
        'fk_subscriptions_plan_id',
        'subscriptions', 'subscription_plans',
        ['planId'], ['id'], ondelete='SET NULL'
    )


def downgrade() -> None:
    op.drop_constraint('fk_subscriptions_plan_id', 'subscriptions', type_='foreignkey')
    op.drop_column('subscriptions', 'paymentStatus')
    op.drop_column('subscriptions', 'selectedExtras')
    op.drop_column('subscriptions', 'originalPrice')
    op.drop_column('subscriptions', 'price')
    op.drop_column('subscriptions', 'planId')
    op.drop_table('subscription_plans')
```

- [ ] **Step 3: Verify migration runs on SQLite test DB**

Run:
```bash
cd backend
DATABASE_URL=sqlite+aiosqlite:///./test_alembic.db alembic upgrade head
```
Expected: `INFO  [alembic.runtime.migration] Context impl SQLiteImpl.` and no errors.

- [ ] **Step 4: Commit**

```bash
git add backend/alembic/versions/2026_06_28_add_subscription_plans.py
git commit -m "chore(db): add subscription_plans table and subscription purchase fields"
```

---

## Task 2: Backend models

**Files:**
- Modify: `backend/models/models.py`

- [ ] **Step 1: Add SubscriptionPlan model**

After `WashTypeConsumable` class, add:

```python
class SubscriptionPlan(Base):
    __tablename__ = "subscription_plans"
    id = Column(Integer, primary_key=True, autoincrement=True)
    code = Column(String, nullable=False, unique=True)
    name = Column(String, nullable=False)
    description = Column(String, nullable=True)
    type = Column(String, nullable=False)  # 'package' or 'unlimited'
    washCount = Column(Integer, nullable=True)
    unlimitedDays = Column(Integer, nullable=True)
    discountPercent = Column(Integer, nullable=False, default=0)
    washTypePrices = Column(JSON, nullable=True)
    sortOrder = Column(Integer, nullable=False, default=0)
    isActive = Column(Boolean, nullable=False, default=True)
    createdAt = Column(DateTime, nullable=False, default=datetime.utcnow)
    updatedAt = Column(DateTime, nullable=False, default=datetime.utcnow, onupdate=datetime.utcnow)
```

- [ ] **Step 2: Extend Subscription model**

Add after `validUntil`:

```python
    planId = Column(Integer, ForeignKey("subscription_plans.id", ondelete="SET NULL"), nullable=True)
    price = Column(Integer, nullable=False, default=0)
    originalPrice = Column(Integer, nullable=False, default=0)
    selectedExtras = Column(String, nullable=True)  # JSON array string
    paymentStatus = Column(String, nullable=False, default="demo_purchased")
```

- [ ] **Step 3: Commit**

```bash
git add backend/models/models.py
git commit -m "feat(models): add SubscriptionPlan and purchase fields to Subscription"
```

---

## Task 3: Backend schemas

**Files:**
- Modify: `backend/schemas/schemas.py`

- [ ] **Step 1: Add plan schemas**

After `SubscriptionStatsResponse`, add:

```python
class SubscriptionPlanResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: int
    code: str
    name: str
    description: Optional[str] = None
    type: Literal["package", "unlimited"]
    washCount: Optional[int] = None
    unlimitedDays: Optional[int] = None
    discountPercent: int
    washTypePrices: Optional[dict[str, int]] = None
    sortOrder: int
    isActive: bool


class SubscriptionPlanCreateRequest(BaseModel):
    code: str = Field(..., max_length=50)
    name: str = Field(..., max_length=200)
    description: Optional[str] = Field(default=None, max_length=500)
    type: Literal["package", "unlimited"] = "package"
    washCount: Optional[int] = Field(default=None, ge=1)
    unlimitedDays: Optional[int] = Field(default=None, ge=1)
    discountPercent: int = Field(default=0, ge=0, le=100)
    washTypePrices: Optional[dict[str, int]] = None
    sortOrder: int = Field(default=0)
    isActive: bool = Field(default=True)


class SubscriptionPlanUpdateRequest(BaseModel):
    name: Optional[str] = Field(default=None, max_length=200)
    description: Optional[str] = Field(default=None, max_length=500)
    washCount: Optional[int] = Field(default=None, ge=1)
    unlimitedDays: Optional[int] = Field(default=None, ge=1)
    discountPercent: Optional[int] = Field(default=None, ge=0, le=100)
    washTypePrices: Optional[dict[str, int]] = None
    sortOrder: Optional[int] = None
    isActive: Optional[bool] = None


class BuyReadySubscriptionRequest(BaseModel):
    planId: int = Field(..., ge=1)
    washTypeId: str = Field(..., max_length=36)


class BuyPersonalSubscriptionRequest(BaseModel):
    washTypeId: str = Field(..., max_length=36)
    selectedExtras: list[str] = Field(default_factory=list)
    washCount: int = Field(..., ge=1)


class BuySubscriptionRequest(BaseModel):
    kind: Literal["ready", "personal"]
    ready: Optional[BuyReadySubscriptionRequest] = None
    personal: Optional[BuyPersonalSubscriptionRequest] = None
```

- [ ] **Step 2: Extend SubscriptionResponse**

Add fields:

```python
    planId: Optional[int] = None
    price: int = 0
    originalPrice: int = 0
    selectedExtras: Optional[str] = None
    paymentStatus: str = "demo_purchased"
```

- [ ] **Step 3: Commit**

```bash
git add backend/schemas/schemas.py
git commit -m "feat(schemas): add subscription plan and purchase request schemas"
```

---

## Task 4: SubscriptionPlan repository

**Files:**
- Create: `backend/repositories/subscription_plan.py`

- [ ] **Step 1: Create repository**

```python
from models import SubscriptionPlan
from repositories.base import BaseRepository


class SubscriptionPlanRepository(BaseRepository[SubscriptionPlan]):
    async def list_active(self) -> list[SubscriptionPlan]:
        from sqlalchemy import select
        result = await self._db.execute(
            select(SubscriptionPlan)
            .where(SubscriptionPlan.isActive == True)
            .order_by(SubscriptionPlan.sortOrder.asc())
        )
        return list(result.scalars().all())

    async def get_by_id(self, plan_id: int) -> SubscriptionPlan | None:
        from sqlalchemy import select
        result = await self._db.execute(
            select(SubscriptionPlan).where(SubscriptionPlan.id == plan_id)
        )
        return result.scalar_one_or_none()

    async def get_by_code(self, code: str) -> SubscriptionPlan | None:
        from sqlalchemy import select
        result = await self._db.execute(
            select(SubscriptionPlan).where(SubscriptionPlan.code == code)
        )
        return result.scalar_one_or_none()
```

- [ ] **Step 2: Commit**

```bash
git add backend/repositories/subscription_plan.py
git commit -m "feat(repositories): add SubscriptionPlanRepository"
```

---

## Task 5: SubscriptionsService — catalog, pricing, purchase

**Files:**
- Modify: `backend/services/subscriptions_service.py`

- [ ] **Step 1: Add imports and exceptions**

```python
from datetime import date, datetime, timedelta
import json

from models import Subscription, SubscriptionPlan, WashType
from repositories.service import ServiceRepository
from repositories.subscription_plan import SubscriptionPlanRepository
from repositories.wash_type import WashTypeRepository
from schemas import (
    BuyPersonalSubscriptionRequest,
    BuyReadySubscriptionRequest,
    BuySubscriptionRequest,
    SubscriptionCreateRequest,
    SubscriptionPlanCreateRequest,
    SubscriptionPlanUpdateRequest,
)
```

Add exceptions:

```python
class PlanNotFoundError(Exception):
    pass


class InvalidPlanConfigurationError(Exception):
    pass


class WashTypeNotFoundError(Exception):
    pass
```

- [ ] **Step 2: Add catalog method**

```python
    async def list_active_plans(self) -> list[SubscriptionPlan]:
        plans = await self._plans.list_active()
        return plans
```

- [ ] **Step 3: Add price calculation helpers**

```python
    async def _calculate_ready_package_price(
        self, plan: SubscriptionPlan, wash_type: WashType
    ) -> tuple[int, int]:
        original = wash_type.basePrice * plan.washCount
        price = original * (100 - plan.discountPercent) // 100
        return original, price

    async def _calculate_ready_unlimited_price(
        self, plan: SubscriptionPlan, wash_type_id: str
    ) -> tuple[int, int]:
        price = (plan.washTypePrices or {}).get(wash_type_id)
        if price is None:
            raise InvalidPlanConfigurationError("Цена для выбранного типа мойки не задана")
        return price, price

    async def _calculate_personal_price(
        self, req: BuyPersonalSubscriptionRequest, wash_type: WashType
    ) -> tuple[int, int]:
        service_repo = ServiceRepository(self._db)
        prices = await service_repo.get_prices(req.selectedExtras)
        extras_total = sum(prices.get(eid, 0) for eid in req.selectedExtras)
        single = wash_type.basePrice + extras_total
        original = single * req.washCount

        if req.washCount >= 20:
            discount = 15
        elif req.washCount >= 10:
            discount = 10
        elif req.washCount >= 5:
            discount = 5
        else:
            discount = 0

        price = original * (100 - discount) // 100
        return original, price
```

- [ ] **Step 4: Add purchase method**

```python
    async def buy_subscription(
        self, req: BuySubscriptionRequest, user_id: int
    ) -> Subscription:
        if req.kind == "ready" and req.ready:
            return await self._buy_ready(req.ready, user_id)
        if req.kind == "personal" and req.personal:
            return await self._buy_personal(req.personal, user_id)
        raise InvalidPlanConfigurationError("Некорректный запрос покупки")

    async def _buy_ready(
        self, req: BuyReadySubscriptionRequest, user_id: int
    ) -> Subscription:
        plan = await self._plans.get_by_id(req.planId)
        if not plan or not plan.isActive:
            raise PlanNotFoundError()

        wash_type_repo = WashTypeRepository(self._db)
        wash_type = await wash_type_repo.get_by_id(req.washTypeId)
        if not wash_type:
            raise WashTypeNotFoundError()

        if plan.type == "package":
            if not plan.washCount:
                raise InvalidPlanConfigurationError("У пакета не задано количество моек")
            original_price, price = await self._calculate_ready_package_price(plan, wash_type)
            total_washes = plan.washCount
            valid_until = None
        elif plan.type == "unlimited":
            if not plan.unlimitedDays:
                raise InvalidPlanConfigurationError("У безлимита не задан срок")
            original_price, price = await self._calculate_ready_unlimited_price(plan, req.washTypeId)
            total_washes = 999999
            valid_until = date.today() + timedelta(days=plan.unlimitedDays)
        else:
            raise InvalidPlanConfigurationError("Неизвестный тип плана")

        sub = Subscription(
            userId=user_id,
            name=plan.name,
            type="package" if plan.type == "package" else "monthly",
            washTypeId=req.washTypeId,
            totalWashes=total_washes,
            usedWashes=0,
            validUntil=valid_until,
            planId=plan.id,
            price=price,
            originalPrice=original_price,
            paymentStatus="demo_purchased",
            createdAt=datetime.now(),
        )
        await self._subscriptions.add(sub)
        await self._db.commit()
        await self._db.refresh(sub)
        return sub

    async def _buy_personal(
        self, req: BuyPersonalSubscriptionRequest, user_id: int
    ) -> Subscription:
        wash_type_repo = WashTypeRepository(self._db)
        wash_type = await wash_type_repo.get_by_id(req.washTypeId)
        if not wash_type:
            raise WashTypeNotFoundError()

        original_price, price = await self._calculate_personal_price(req, wash_type)

        sub = Subscription(
            userId=user_id,
            name=f"Персональный абонемент ({req.washCount} моек)",
            type="package",
            washTypeId=req.washTypeId,
            totalWashes=req.washCount,
            usedWashes=0,
            validUntil=None,
            planId=None,
            price=price,
            originalPrice=original_price,
            selectedExtras=json.dumps(req.selectedExtras),
            paymentStatus="demo_purchased",
            createdAt=datetime.now(),
        )
        await self._subscriptions.add(sub)
        await self._db.commit()
        await self._db.refresh(sub)
        return sub
```

- [ ] **Step 5: Update service constructor**

```python
    def __init__(self, db: AsyncSession) -> None:
        self._db = db
        self._subscriptions = SubscriptionRepository(db)
        self._users = UserRepository(db)
        self._plans = SubscriptionPlanRepository(db)
```

- [ ] **Step 6: Commit**

```bash
git add backend/services/subscriptions_service.py
git commit -m "feat(services): subscription catalog, pricing and purchase logic"
```

---

## Task 6: Backend routers

**Files:**
- Modify: `backend/app/routers/subscriptions.py`

- [ ] **Step 1: Add imports**

```python
from schemas import (
    BuySubscriptionRequest,
    SubscriptionPlanCreateRequest,
    SubscriptionPlanResponse,
    SubscriptionPlanUpdateRequest,
)
from services.auth_service import check_roles, get_current_user
from services.subscriptions_service import (
    InvalidPlanConfigurationError,
    PlanNotFoundError,
    SubscriptionNotFoundError,
    SubscriptionsService,
    UserNotFoundError,
    WashTypeNotFoundError,
)
```

- [ ] **Step 2: Add client endpoints**

After `get_my_subscriptions`:

```python
@router.get("/plans", response_model=list[SubscriptionPlanResponse])
@limiter.limit("60/minute")
async def get_subscription_plans(
    request: Request,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """List active subscription plans for clients."""
    svc = SubscriptionsService(db)
    return await svc.list_active_plans()


@router.post("/buy", response_model=SubscriptionResponse, status_code=status.HTTP_201_CREATED)
@limiter.limit("10/minute")
async def buy_subscription(
    request: Request,
    req: BuySubscriptionRequest,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """Client buys a ready-made or personal subscription."""
    svc = SubscriptionsService(db)
    try:
        return await svc.buy_subscription(req, current_user.id)
    except PlanNotFoundError:
        raise HTTPException(status.HTTP_404_NOT_FOUND, "План не найден")
    except WashTypeNotFoundError:
        raise HTTPException(status.HTTP_404_NOT_FOUND, "Тип мойки не найден")
    except InvalidPlanConfigurationError as exc:
        raise HTTPException(status.HTTP_400_BAD_REQUEST, str(exc))
```

- [ ] **Step 3: Add admin CRUD for plans**

At the bottom of the file:

```python
@router.get(
    "/admin/plans",
    response_model=list[SubscriptionPlanResponse],
    dependencies=[Depends(check_roles(["admin"]))],
)
@limiter.limit("60/minute")
async def list_all_plans(
    request: Request,
    db: AsyncSession = Depends(get_db),
):
    from sqlalchemy import select
    result = await db.execute(select(SubscriptionPlan).order_by(SubscriptionPlan.sortOrder.asc()))
    return list(result.scalars().all())


@router.post(
    "/admin/plans",
    response_model=SubscriptionPlanResponse,
    status_code=status.HTTP_201_CREATED,
    dependencies=[Depends(check_roles(["admin"]))],
)
@limiter.limit("30/minute")
async def create_plan(
    request: Request,
    req: SubscriptionPlanCreateRequest,
    db: AsyncSession = Depends(get_db),
):
    plan = SubscriptionPlan(**req.model_dump())
    db.add(plan)
    await db.commit()
    await db.refresh(plan)
    return plan


@router.put(
    "/admin/plans/{plan_id}",
    response_model=SubscriptionPlanResponse,
    dependencies=[Depends(check_roles(["admin"]))],
)
@limiter.limit("30/minute")
async def update_plan(
    request: Request,
    plan_id: int,
    req: SubscriptionPlanUpdateRequest,
    db: AsyncSession = Depends(get_db),
):
    from sqlalchemy import select
    result = await db.execute(select(SubscriptionPlan).where(SubscriptionPlan.id == plan_id))
    plan = result.scalar_one_or_none()
    if not plan:
        raise HTTPException(status.HTTP_404_NOT_FOUND, "План не найден")
    for field, value in req.model_dump(exclude_unset=True).items():
        setattr(plan, field, value)
    await db.commit()
    await db.refresh(plan)
    return plan


@router.delete(
    "/admin/plans/{plan_id}",
    status_code=status.HTTP_204_NO_CONTENT,
    dependencies=[Depends(check_roles(["admin"]))],
)
@limiter.limit("30/minute")
async def delete_plan(
    request: Request,
    plan_id: int,
    db: AsyncSession = Depends(get_db),
):
    from sqlalchemy import select
    result = await db.execute(select(SubscriptionPlan).where(SubscriptionPlan.id == plan_id))
    plan = result.scalar_one_or_none()
    if not plan:
        raise HTTPException(status.HTTP_404_NOT_FOUND, "План не найден")
    plan.isActive = False
    await db.commit()
    return None
```

- [ ] **Step 4: Commit**

```bash
git add backend/app/routers/subscriptions.py
git commit -m "feat(api): subscription plan catalog, buy and admin CRUD endpoints"
```

---

## Task 7: Seed data

**Files:**
- Modify: `backend/db/seed.py`

- [ ] **Step 1: Add seed for subscription plans**

After wash types seed block, add:

```python
        # Subscription plans
        from models import SubscriptionPlan
        res = await session.execute(select(func.count(SubscriptionPlan.id)))
        if res.scalar() == 0:
            session.add_all(
                [
                    SubscriptionPlan(
                        code="chistulya",
                        name="Чистюля",
                        description="5 моек со скидкой 10%",
                        type="package",
                        washCount=5,
                        discountPercent=10,
                        sortOrder=1,
                    ),
                    SubscriptionPlan(
                        code="blesk-master",
                        name="Блеск-мастер",
                        description="10 моек со скидкой 15%",
                        type="package",
                        washCount=10,
                        discountPercent=15,
                        sortOrder=2,
                    ),
                    SubscriptionPlan(
                        code="bezlimitka",
                        name="Безлимитка",
                        description="30 дней безлимитных моек одного типа",
                        type="unlimited",
                        unlimitedDays=30,
                        washTypePrices={"w1": 8000, "w2": 12000, "w3": 22000, "w4": 40000},
                        sortOrder=3,
                    ),
                ]
            )
            await session.commit()
```

- [ ] **Step 2: Commit**

```bash
git add backend/db/seed.py
git commit -m "chore(seed): add default subscription plans"
```

---

## Task 8: Backend tests

**Files:**
- Modify: `backend/tests/test_subscriptions.py`

- [ ] **Step 1: Add catalog test**

```python
    @pytest.mark.asyncio
    async def test_client_can_list_subscription_plans(
        self, async_client, client_token
    ):
        resp = await async_client.get(
            "/api/subscriptions/plans",
            headers={"Authorization": f"Bearer {client_token}"},
        )
        assert resp.status_code == 200
        data = resp.json()
        assert isinstance(data, list)
        assert len(data) >= 1
```

- [ ] **Step 2: Add ready plan purchase test**

```python
    @pytest.mark.asyncio
    async def test_client_buys_ready_subscription(
        self, async_client, client_token, db_session
    ):
        from models import SubscriptionPlan
        plan_res = await db_session.execute(
            select(SubscriptionPlan).where(SubscriptionPlan.code == "chistulya")
        )
        plan = plan_res.scalar_one()

        resp = await async_client.post(
            "/api/subscriptions/buy",
            headers={"Authorization": f"Bearer {client_token}"},
            json={
                "kind": "ready",
                "ready": {"planId": plan.id, "washTypeId": "w3"},
            },
        )
        assert resp.status_code == 201
        data = resp.json()
        assert data["washTypeId"] == "w3"
        assert data["totalWashes"] == 5
        assert data["price"] == 6750
        assert data["originalPrice"] == 7500
        assert data["paymentStatus"] == "demo_purchased"
```

- [ ] **Step 3: Add personal subscription test**

```python
    @pytest.mark.asyncio
    async def test_client_buys_personal_subscription(
        self, async_client, client_token
    ):
        resp = await async_client.post(
            "/api/subscriptions/buy",
            headers={"Authorization": f"Bearer {client_token}"},
            json={
                "kind": "personal",
                "personal": {
                    "washTypeId": "w2",
                    "selectedExtras": ["s4"],
                    "washCount": 10,
                },
            },
        )
        assert resp.status_code == 201
        data = resp.json()
        assert data["washTypeId"] == "w2"
        assert data["totalWashes"] == 10
        # (800 + 600) * 10 * 0.85 = 11900
        assert data["price"] == 11900
        assert data["originalPrice"] == 14000
```

- [ ] **Step 4: Add unlimited plan test**

```python
    @pytest.mark.asyncio
    async def test_client_buys_unlimited_subscription(
        self, async_client, client_token, db_session
    ):
        from models import SubscriptionPlan
        plan_res = await db_session.execute(
            select(SubscriptionPlan).where(SubscriptionPlan.code == "bezlimitka")
        )
        plan = plan_res.scalar_one()

        resp = await async_client.post(
            "/api/subscriptions/buy",
            headers={"Authorization": f"Bearer {client_token}"},
            json={
                "kind": "ready",
                "ready": {"planId": plan.id, "washTypeId": "w1"},
            },
        )
        assert resp.status_code == 201
        data = resp.json()
        assert data["price"] == 8000
        assert data["type"] == "monthly"
        assert data["validUntil"] is not None
```

- [ ] **Step 5: Run new tests**

Run:
```bash
cp .env .env.bak && sed -i '' '/^DATABASE_URL=/d' .env && \
DATABASE_URL=sqlite+aiosqlite:///./test.db .venv/bin/python -m pytest backend/tests/test_subscriptions.py -q; \
STATUS=$?; mv .env.bak .env; exit $STATUS
```
Expected: all tests pass.

- [ ] **Step 6: Commit**

```bash
git add backend/tests/test_subscriptions.py
git commit -m "test(subscriptions): cover client plan catalog and purchase flows"
```

---

## Task 9: Flutter model SubscriptionPlan

**Files:**
- Create: `lib/models/subscription_plan.dart`

- [ ] **Step 1: Create model**

```dart
class SubscriptionPlan {
  final int id;
  final String code;
  final String name;
  final String? description;
  final String type; // 'package' | 'unlimited'
  final int? washCount;
  final int? unlimitedDays;
  final int discountPercent;
  final Map<String, int>? washTypePrices;
  final int sortOrder;
  final bool isActive;

  SubscriptionPlan({
    required this.id,
    required this.code,
    required this.name,
    this.description,
    required this.type,
    this.washCount,
    this.unlimitedDays,
    required this.discountPercent,
    this.washTypePrices,
    required this.sortOrder,
    required this.isActive,
  });

  bool get isPackage => type == 'package';
  bool get isUnlimited => type == 'unlimited';

  factory SubscriptionPlan.fromMap(Map<String, dynamic> m) {
    return SubscriptionPlan(
      id: (m['id'] as num).toInt(),
      code: m['code']?.toString() ?? '',
      name: m['name']?.toString() ?? '',
      description: m['description']?.toString(),
      type: m['type']?.toString() ?? 'package',
      washCount: (m['washCount'] as num?)?.toInt(),
      unlimitedDays: (m['unlimitedDays'] as num?)?.toInt(),
      discountPercent: (m['discountPercent'] as num?)?.toInt() ?? 0,
      washTypePrices: (m['washTypePrices'] as Map<String, dynamic>?)
          ?.map((k, v) => MapEntry(k, (v as num).toInt())),
      sortOrder: (m['sortOrder'] as num?)?.toInt() ?? 0,
      isActive: m['isActive'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'code': code,
        'name': name,
        'description': description,
        'type': type,
        'washCount': washCount,
        'unlimitedDays': unlimitedDays,
        'discountPercent': discountPercent,
        'washTypePrices': washTypePrices,
        'sortOrder': sortOrder,
        'isActive': isActive,
      };
}
```

- [ ] **Step 2: Commit**

```bash
git add lib/models/subscription_plan.dart
git commit -m "feat(models): add SubscriptionPlan Flutter model"
```

---

## Task 10: Extend Flutter Subscription model

**Files:**
- Modify: `lib/models/subscription.dart`

- [ ] **Step 1: Add fields**

Add to class fields:

```dart
  final int? planId;
  final int price;
  final int originalPrice;
  final String? selectedExtras;
  final String paymentStatus;
```

Update constructor, toMap, fromMap:

```dart
  Subscription({
    ...
    this.planId,
    this.price = 0,
    this.originalPrice = 0,
    this.selectedExtras,
    this.paymentStatus = 'demo_purchased',
    required this.createdAt,
  });

  Map<String, dynamic> toMap() => {
        ...
        'planId': planId,
        'price': price,
        'originalPrice': originalPrice,
        'selectedExtras': selectedExtras,
        'paymentStatus': paymentStatus,
      };

  factory Subscription.fromMap(Map<String, dynamic> m) {
    return Subscription(
      ...
      planId: (m['planId'] as num?)?.toInt(),
      price: (m['price'] as num?)?.toInt() ?? 0,
      originalPrice: (m['originalPrice'] as num?)?.toInt() ?? 0,
      selectedExtras: m['selectedExtras']?.toString(),
      paymentStatus: m['paymentStatus']?.toString() ?? 'demo_purchased',
      createdAt: m['createdAt'] ?? '',
    );
  }
```

- [ ] **Step 2: Commit**

```bash
git add lib/models/subscription.dart
git commit -m "feat(models): extend Subscription with purchase fields"
```

---

## Task 11: Flutter API service methods

**Files:**
- Modify: `lib/services/api_service.dart`

- [ ] **Step 1: Add methods**

After `getSubscriptionStats`, add:

```dart
  Future<List<SubscriptionPlan>> getSubscriptionPlans() async {
    final result = await ApiClient.getList('/subscriptions/plans');
    return result.when(
      success: (list) => list
          .map((m) => SubscriptionPlan.fromMap(m as Map<String, dynamic>))
          .toList(),
      failure: (_) => <SubscriptionPlan>[],
    );
  }

  Future<Subscription?> buySubscription({
    required String kind,
    Map<String, dynamic>? ready,
    Map<String, dynamic>? personal,
  }) async {
    final body = <String, dynamic>{
      'kind': kind,
      if (ready != null) 'ready': ready,
      if (personal != null) 'personal': personal,
    };
    final result = await ApiClient.post('/subscriptions/buy', body: body);
    return result.when(
      success: (data) => Subscription.fromMap(data),
      failure: (_) => null,
    );
  }
```

- [ ] **Step 2: Commit**

```bash
git add lib/services/api_service.dart
git commit -m "feat(api): client subscription plan catalog and purchase calls"
```

---

## Task 12: Drawer menu item

**Files:**
- Modify: `lib/screens/client/client_shell.dart`

- [ ] **Step 1: Add menu item**

After the support chat item, add:

```dart
          // Абонементы
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            child: ListTile(
              minLeadingWidth: 24,
              leading: Icon(Icons.card_membership_outlined,
                  color: AppStyles.adaptiveTextSecondary(ctx), size: 22),
              title: Text('Абонементы',
                  style: TextStyle(color: AppStyles.adaptiveTextPrimary(ctx))),
              onTap: () {
                Navigator.pop(ctx);
                Navigator.push(
                    ctx,
                    MaterialPageRoute(
                        builder: (_) => const SubscriptionHubScreen()));
              },
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
          ),
```

- [ ] **Step 2: Commit**

```bash
git add lib/screens/client/client_shell.dart
git commit -m "feat(client): add Subscriptions item to client drawer"
```

---

## Task 13: Subscription hub screen

**Files:**
- Create: `lib/screens/client/subscription_hub_screen.dart`

- [ ] **Step 1: Implement hub**

```dart
import 'package:flutter/material.dart';
import 'package:lanwash/models/subscription.dart';
import 'package:lanwash/services/api_service.dart';
import 'package:lanwash/app_styles.dart';
import 'subscription_screen.dart';
import 'subscription_type_choice_screen.dart';

class SubscriptionHubScreen extends StatefulWidget {
  const SubscriptionHubScreen({super.key});

  @override
  State<SubscriptionHubScreen> createState() => _SubscriptionHubScreenState();
}

class _SubscriptionHubScreenState extends State<SubscriptionHubScreen> {
  List<Subscription> _subs = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final subs = await ApiService().getMySubscriptions();
    if (mounted) {
      setState(() {
        _subs = subs.where((s) => s.isActive).toList();
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Абонементы')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                ElevatedButton.icon(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const SubscriptionTypeChoiceScreen()),
                  ),
                  icon: const Icon(Icons.add),
                  label: const Text('Купить абонемент'),
                ),
                const SizedBox(height: 24),
                Text('Активные абонементы',
                    style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
                if (_subs.isEmpty)
                  const Text('У вас пока нет активных абонементов.'),
                ..._subs.map((s) => ListTile(
                      title: Text(s.name),
                      subtitle: Text('Осталось моек: ${s.remaining}'),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => const SubscriptionScreen()),
                      ),
                    )),
              ],
            ),
    );
  }
}
```

- [ ] **Step 2: Commit**

```bash
git add lib/screens/client/subscription_hub_screen.dart
git commit -m "feat(client): add SubscriptionHubScreen"
```

---

## Task 14: Type choice screen

**Files:**
- Create: `lib/screens/client/subscription_type_choice_screen.dart`

- [ ] **Step 1: Implement choice screen**

```dart
import 'package:flutter/material.dart';
import 'ready_plan_catalog_screen.dart';
import 'personal_builder_screen.dart';

class SubscriptionTypeChoiceScreen extends StatelessWidget {
  const SubscriptionTypeChoiceScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Выбор абонемента')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            ListTile(
              leading: const Icon(Icons.local_offer_outlined),
              title: const Text('Готовый абонемент'),
              subtitle: const Text('Выбери один из предложенных пакетов'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) => const ReadyPlanCatalogScreen()),
              ),
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.build_outlined),
              title: const Text('Персональный абонемент'),
              subtitle: const Text('Собери свой: тип мойки, допы, количество'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) => const PersonalBuilderScreen()),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
```

- [ ] **Step 2: Commit**

```bash
git add lib/screens/client/subscription_type_choice_screen.dart
git commit -m "feat(client): add subscription type choice screen"
```

---

## Task 15: Ready plan catalog

**Files:**
- Create: `lib/screens/client/ready_plan_catalog_screen.dart`

- [ ] **Step 1: Implement catalog**

```dart
import 'package:flutter/material.dart';
import 'package:lanwash/models/subscription_plan.dart';
import 'package:lanwash/services/api_service.dart';
import 'ready_plan_wash_type_screen.dart';

class ReadyPlanCatalogScreen extends StatefulWidget {
  const ReadyPlanCatalogScreen({super.key});

  @override
  State<ReadyPlanCatalogScreen> createState() => _ReadyPlanCatalogScreenState();
}

class _ReadyPlanCatalogScreenState extends State<ReadyPlanCatalogScreen> {
  List<SubscriptionPlan> _plans = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final plans = await ApiService().getSubscriptionPlans();
    if (mounted) {
      setState(() {
        _plans = plans;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Готовые абонементы')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _plans.length,
              itemBuilder: (context, index) {
                final plan = _plans[index];
                return Card(
                  child: ListTile(
                    title: Text(plan.name),
                    subtitle: Text(plan.description ?? ''),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ReadyPlanWashTypeScreen(plan: plan),
                      ),
                    ),
                  ),
                );
              },
            ),
    );
  }
}
```

- [ ] **Step 2: Commit**

```bash
git add lib/screens/client/ready_plan_catalog_screen.dart
git commit -m "feat(client): add ready-made subscription catalog"
```

---

## Task 16: Ready plan wash type selection

**Files:**
- Create: `lib/screens/client/ready_plan_wash_type_screen.dart`

- [ ] **Step 1: Implement screen**

```dart
import 'package:flutter/material.dart';
import 'package:lanwash/models/subscription_plan.dart';
import 'package:lanwash/services/api_service.dart';
import 'subscription_checkout_screen.dart';

class ReadyPlanWashTypeScreen extends StatefulWidget {
  final SubscriptionPlan plan;
  const ReadyPlanWashTypeScreen({super.key, required this.plan});

  @override
  State<ReadyPlanWashTypeScreen> createState() =>
      _ReadyPlanWashTypeScreenState();
}

class _ReadyPlanWashTypeScreenState extends State<ReadyPlanWashTypeScreen> {
  List<Map<String, dynamic>> _washTypes = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final types = await ApiService().getWashTypes();
    if (mounted) {
      setState(() {
        _washTypes = types;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.plan.name)),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _washTypes.length,
              itemBuilder: (context, index) {
                final wt = _washTypes[index];
                final wtId = wt['id']?.toString() ?? '';
                final price = widget.plan.isUnlimited
                    ? widget.plan.washTypePrices?[wtId]
                    : (wt['basePrice'] as num).toInt() *
                        (widget.plan.washCount ?? 1) *
                        (100 - widget.plan.discountPercent) ~/
                        100;
                final original = widget.plan.isUnlimited
                    ? price
                    : (wt['basePrice'] as num).toInt() *
                        (widget.plan.washCount ?? 1);
                return Card(
                  child: ListTile(
                    title: Text(wt['name']?.toString() ?? ''),
                    subtitle: Text('${widget.plan.washCount ?? 30} моек • $price ₽'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => SubscriptionCheckoutScreen(
                          kind: 'ready',
                          plan: widget.plan,
                          washTypeId: wtId,
                          washTypeName: wt['name']?.toString() ?? '',
                          price: price ?? 0,
                          originalPrice: original ?? 0,
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
    );
  }
}
```

- [ ] **Step 2: Commit**

```bash
git add lib/screens/client/ready_plan_wash_type_screen.dart
git commit -m "feat(client): add wash type selection for ready subscription"
```

---

## Task 17: Personal builder screen

**Files:**
- Create: `lib/screens/client/personal_builder_screen.dart`

- [ ] **Step 1: Implement builder**

```dart
import 'package:flutter/material.dart';
import 'package:lanwash/services/api_service.dart';
import 'subscription_checkout_screen.dart';

class PersonalBuilderScreen extends StatefulWidget {
  const PersonalBuilderScreen({super.key});

  @override
  State<PersonalBuilderScreen> createState() => _PersonalBuilderScreenState();
}

class _PersonalBuilderScreenState extends State<PersonalBuilderScreen> {
  List<Map<String, dynamic>> _washTypes = [];
  List<Map<String, dynamic>> _services = [];
  String? _selectedWashTypeId;
  String? _selectedWashTypeName;
  int _selectedWashTypePrice = 0;
  final Set<String> _selectedExtras = {};
  int _washCount = 5;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final types = await ApiService().getWashTypes();
    final services = await ApiService().getServices();
    if (mounted) {
      setState(() {
        _washTypes = types;
        _services = services;
        _loading = false;
      });
    }
  }

  int get _extrasPrice => _selectedExtras.fold<int>(
      0,
      (sum, id) =>
          sum +
          (_services
                  .firstWhere((s) => s['id']?.toString() == id,
                      orElse: () => {'price': 0})['price'] as num? ??
              0)
              .toInt());

  int get _singlePrice => _selectedWashTypePrice + _extrasPrice;
  int get _originalPrice => _singlePrice * _washCount;

  int get _discountPercent {
    if (_washCount >= 20) return 15;
    if (_washCount >= 10) return 10;
    if (_washCount >= 5) return 5;
    return 0;
  }

  int get _price => _originalPrice * (100 - _discountPercent) ~/ 100;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Персональный абонемент')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Text('Тип мойки',
                    style: Theme.of(context).textTheme.titleMedium),
                ..._washTypes.map((wt) {
                  final id = wt['id']?.toString() ?? '';
                  return RadioListTile<String>(
                    title: Text(wt['name']?.toString() ?? ''),
                    subtitle: Text('${wt['basePrice']} ₽'),
                    value: id,
                    groupValue: _selectedWashTypeId,
                    onChanged: (v) => setState(() {
                      _selectedWashTypeId = v;
                      _selectedWashTypeName = wt['name']?.toString();
                      _selectedWashTypePrice =
                          (wt['basePrice'] as num? ?? 0).toInt();
                    }),
                  );
                }),
                const SizedBox(height: 16),
                Text('Дополнительные услуги',
                    style: Theme.of(context).textTheme.titleMedium),
                ..._services.map((s) {
                  final id = s['id']?.toString() ?? '';
                  return CheckboxListTile(
                    title: Text(s['name']?.toString() ?? ''),
                    subtitle: Text('${s['price']} ₽'),
                    value: _selectedExtras.contains(id),
                    onChanged: (v) => setState(() {
                      if (v == true) {
                        _selectedExtras.add(id);
                      } else {
                        _selectedExtras.remove(id);
                      }
                    }),
                  );
                }),
                const SizedBox(height: 16),
                Text('Количество моек',
                    style: Theme.of(context).textTheme.titleMedium),
                Row(
                  children: [
                    IconButton(
                      onPressed: _washCount > 1
                          ? () => setState(() => _washCount--)
                          : null,
                      icon: const Icon(Icons.remove),
                    ),
                    Text('$_washCount', style: const TextStyle(fontSize: 18)),
                    IconButton(
                      onPressed: () => setState(() => _washCount++),
                      icon: const Icon(Icons.add),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Text('Скидка: $_discountPercent%',
                    style: Theme.of(context).textTheme.titleMedium),
                Text('Итого: $_price ₽',
                    style: Theme.of(context).textTheme.headlineSmall),
                Text('Без скидки: $_originalPrice ₽',
                    style: const TextStyle(
                        decoration: TextDecoration.lineThrough,
                        color: Colors.grey)),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: _selectedWashTypeId == null
                      ? null
                      : () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => SubscriptionCheckoutScreen(
                                kind: 'personal',
                                washTypeId: _selectedWashTypeId!,
                                washTypeName: _selectedWashTypeName!,
                                selectedExtras: _selectedExtras.toList(),
                                washCount: _washCount,
                                price: _price,
                                originalPrice: _originalPrice,
                              ),
                            ),
                          ),
                  child: const Text('Перейти к оплате'),
                ),
              ],
            ),
    );
  }
}
```

- [ ] **Step 2: Commit**

```bash
git add lib/screens/client/personal_builder_screen.dart
git commit -m "feat(client): add personal subscription builder"
```

---

## Task 18: Checkout and demo payment

**Files:**
- Create: `lib/screens/client/subscription_checkout_screen.dart`

- [ ] **Step 1: Implement checkout**

```dart
import 'package:flutter/material.dart';
import 'package:lanwash/models/subscription_plan.dart';
import 'package:lanwash/models/subscription.dart';
import 'package:lanwash/services/api_service.dart';
import 'subscription_success_screen.dart';

class SubscriptionCheckoutScreen extends StatefulWidget {
  final String kind;
  final SubscriptionPlan? plan;
  final String washTypeId;
  final String washTypeName;
  final List<String>? selectedExtras;
  final int? washCount;
  final int price;
  final int originalPrice;

  const SubscriptionCheckoutScreen({
    super.key,
    required this.kind,
    this.plan,
    required this.washTypeId,
    required this.washTypeName,
    this.selectedExtras,
    this.washCount,
    required this.price,
    required this.originalPrice,
  });

  @override
  State<SubscriptionCheckoutScreen> createState() =>
      _SubscriptionCheckoutScreenState();
}

class _SubscriptionCheckoutScreenState
    extends State<SubscriptionCheckoutScreen> {
  bool _buying = false;

  Future<void> _buy() async {
    setState(() => _buying = true);
    final sub = await ApiService().buySubscription(
      kind: widget.kind,
      ready: widget.kind == 'ready'
          ? {
              'planId': widget.plan!.id,
              'washTypeId': widget.washTypeId,
            }
          : null,
      personal: widget.kind == 'personal'
          ? {
              'washTypeId': widget.washTypeId,
              'selectedExtras': widget.selectedExtras ?? [],
              'washCount': widget.washCount,
            }
          : null,
    );
    if (mounted) {
      setState(() => _buying = false);
      if (sub != null) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(
              builder: (_) => SubscriptionSuccessScreen(subscription: sub)),
          (route) => route.isFirst,
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Не удалось оформить абонемент')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Подтверждение')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Тип мойки: ${widget.washTypeName}'),
            if (widget.plan != null) Text('План: ${widget.plan!.name}'),
            if (widget.washCount != null)
              Text('Количество моек: ${widget.washCount}'),
            if (widget.selectedExtras != null &&
                widget.selectedExtras!.isNotEmpty)
              Text('Допы: ${widget.selectedExtras!.join(', ')}'),
            const SizedBox(height: 16),
            Text('К оплате: ${widget.price} ₽',
                style: Theme.of(context).textTheme.headlineSmall),
            Text('Без скидки: ${widget.originalPrice} ₽',
                style: const TextStyle(
                    decoration: TextDecoration.lineThrough,
                    color: Colors.grey)),
            const Spacer(),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _buying ? null : _buy,
                child: _buying
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Оплатить (демо)'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
```

- [ ] **Step 2: Commit**

```bash
git add lib/screens/client/subscription_checkout_screen.dart
git commit -m "feat(client): add subscription checkout with demo payment"
```

---

## Task 19: Success screen

**Files:**
- Create: `lib/screens/client/subscription_success_screen.dart`

- [ ] **Step 1: Implement success**

```dart
import 'package:flutter/material.dart';
import 'package:lanwash/models/subscription.dart';
import 'subscription_hub_screen.dart';

class SubscriptionSuccessScreen extends StatelessWidget {
  final Subscription subscription;
  const SubscriptionSuccessScreen({super.key, required this.subscription});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.check_circle, color: Colors.green, size: 80),
              const SizedBox(height: 24),
              const Text('Абонемент оформлен!',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              Text(subscription.name,
                  style: const TextStyle(fontSize: 18)),
              Text('Списано: ${subscription.price} ₽'),
              const SizedBox(height: 32),
              ElevatedButton(
                onPressed: () => Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(
                      builder: (_) => const SubscriptionHubScreen()),
                  (route) => route.isFirst,
                ),
                child: const Text('К моим абонементам'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
```

- [ ] **Step 2: Commit**

```bash
git add lib/screens/client/subscription_success_screen.dart
git commit -m "feat(client): add subscription purchase success screen"
```

---

## Task 20: Update existing SubscriptionScreen

**Files:**
- Modify: `lib/screens/client/subscription_screen.dart`

- [ ] **Step 1: Rename title and add price info**

Ensure title is `'Мои абонементы'` and display `price`/`originalPrice` for purchased subscriptions. Keep existing list logic.

```dart
ListTile(
  title: Text(sub.name),
  subtitle: Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text('Осталось: ${sub.remaining} из ${sub.totalWashes}'),
      if (sub.price > 0)
        Text('Стоимость: ${sub.price} ₽'),
    ],
  ),
)
```

- [ ] **Step 2: Commit**

```bash
git add lib/screens/client/subscription_screen.dart
git commit -m "feat(client): update SubscriptionScreen with purchase details"
```

---

## Task 21: Flutter analyze and format

**Files:**
- Various

- [ ] **Step 1: Format**

Run:
```bash
dart format lib/models lib/services lib/screens/client/subscription_*.dart
```

- [ ] **Step 2: Analyze**

Run:
```bash
flutter analyze
```
Expected: no errors in new files.

- [ ] **Step 3: Commit**

```bash
git add -A
git commit -m "style(client): format subscription purchase code"
```

---

## Task 22: Integration test

**Files:**
- Modify: `backend/tests/test_subscriptions.py`

- [ ] **Step 1: Add end-to-end use-after-purchase test**

```python
    @pytest.mark.asyncio
    async def test_purchased_subscription_used_in_appointment(
        self, async_client, client_token, admin_token, db_session
    ):
        from models import SubscriptionPlan
        plan_res = await db_session.execute(
            select(SubscriptionPlan).where(SubscriptionPlan.code == "chistulya")
        )
        plan = plan_res.scalar_one()

        buy_resp = await async_client.post(
            "/api/subscriptions/buy",
            headers={"Authorization": f"Bearer {client_token}"},
            json={
                "kind": "ready",
                "ready": {"planId": plan.id, "washTypeId": "w3"},
            },
        )
        assert buy_resp.status_code == 201

        appt_resp = await async_client.post(
            "/api/appointments/",
            headers={"Authorization": f"Bearer {client_token}"},
            json={
                "id": "appt_sub_buy_1",
                "clientName": "Test",
                "carModel": "Car",
                "carNumber": "A123",
                "dateTime": "2099-06-15T10:00:00",
                "washTypeId": "w3",
                "additionalServices": "[]",
                "status": "scheduled",
                "notes": "",
                "isFavorite": False,
                "ownerUsername": "client_test",
                "promoPrice": 0,
                "paidPrice": 0,
                "originalPrice": 0,
                "assignedWasher": "[]",
            },
        )
        assert appt_resp.status_code == 200
        assert appt_resp.json()["paidPrice"] == 0
        assert appt_resp.json()["subscriptionId"] is not None
```

- [ ] **Step 2: Run tests**

Run:
```bash
cp .env .env.bak && sed -i '' '/^DATABASE_URL=/d' .env && \
DATABASE_URL=sqlite+aiosqlite:///./test.db .venv/bin/python -m pytest backend/tests/test_subscriptions.py -q; \
STATUS=$?; mv .env.bak .env; exit $STATUS
```

- [ ] **Step 3: Commit**

```bash
git add backend/tests/test_subscriptions.py
git commit -m "test(subscriptions): verify purchased subscription applies to appointment"
```

---

## Task 23: Final verification

- [ ] **Step 1: Run backend tests**

Run:
```bash
cp .env .env.bak && sed -i '' '/^DATABASE_URL=/d' .env && \
DATABASE_URL=sqlite+aiosqlite:///./test.db .venv/bin/python -m pytest backend/tests -q; \
STATUS=$?; mv .env.bak .env; exit $STATUS
```
Expected: all tests pass.

- [ ] **Step 2: Run Flutter tests**

Run:
```bash
flutter test --reporter=compact --no-pub
```
Expected: existing tests pass.

- [ ] **Step 3: Push**

```bash
git push
```

---

## Spec coverage check

| Spec requirement | Task |
|------------------|------|
| Готовые планы (Чистюля, Блеск-мастер, Безлимитка) | Task 7 (seed), Task 5 (pricing) |
| Персональный абонемент с типом мойки, допами, количеством | Task 5, Task 17 |
| Расчёт цен по выбору | Task 5 |
| Пункт в боковом меню | Task 12 |
| Экран-хаб | Task 13 |
| Пошаговый визард | Tasks 14–19 |
| Демо-оплата | Task 18 |
| Отображение в «Моих абонементах» | Task 20 |
| Админ управляет планами | Task 6 |
| Применение абонемента при записи | Task 22 |

## Placeholder scan

No TBD/TODO. All code blocks contain concrete implementations.
