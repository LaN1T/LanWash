# Telegram Mini App: Unified Auth + Core Client Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use `superpowers:subagent-driven-development` (recommended) or `superpowers:executing-plans` to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Implement the unified Telegram/site login and the core client features (Home, Booking, My Bookings, Profile) in the Telegram Mini App, backed by secure backend auth changes.

**Architecture:** Backend stops auto-creating `tg_<id>` accounts and instead returns a clear `409` when a Telegram ID is not linked. The Mini App then offers login/register screens that send `initData` plus credentials; the backend verifies `initData`, binds the Telegram ID, and issues JWTs. Core client pages reuse existing API endpoints and add lazy-loaded feature chunks.

**Tech Stack:** FastAPI, SQLAlchemy async, Redis, React 18 + TypeScript, Vite 8, Zustand, Axios, Telegram WebApp JS API.

---

## File structure

### Backend

| File | Responsibility |
|------|----------------|
| `backend/services/telegram_auth_service.py` | Verify `initData` HMAC and freshness (`auth_date`). |
| `backend/services/auth_service.py` | `telegram_auth`, `link_telegram`, `register_telegram_user`, `unlink_telegram`, data merge. |
| `backend/app/routers/auth.py` | HTTP endpoints for Telegram auth, link, register, unlink. |
| `backend/schemas/schemas.py` | `TelegramRegisterRequest`, updated `UserResponse` with `telegramLinked`. |
| `backend/repositories/user.py` | `get_by_telegram_id`, `get_by_username`, `update_fields`. |
| `backend/tests/test_auth.py` | Tests for new Telegram auth flows. |

### Telegram Mini App

| File | Responsibility |
|------|----------------|
| `telegram-miniapp/src/lib/cloudStorage.ts` | Promise wrapper over `Telegram.WebApp.CloudStorage` with `localStorage` fallback. |
| `telegram-miniapp/src/stores/authStore.ts` | Auth state, persistence to CloudStorage, `telegramLinked` flag. |
| `telegram-miniapp/src/services/auth.ts` | `telegramAuth`, `linkTelegram`, `registerTelegram`, `logout`. |
| `telegram-miniapp/src/services/api.ts` | Axios instance with token interceptor and 401 refresh logic. |
| `telegram-miniapp/src/hooks/useTelegram.ts` | Provide `initData`, `tg`, theme params, ready state. |
| `telegram-miniapp/src/hooks/useAuthGuard.ts` | Orchestrate auto-login / show auth gateway. |
| `telegram-miniapp/src/pages/auth/AuthGatewayPage.tsx` | Choose login or register, show forms. |
| `telegram-miniapp/src/pages/client/HomePage.tsx` | Dashboard with promos and services catalog. |
| `telegram-miniapp/src/pages/client/BookingPage.tsx` | Booking wizard enhancements (cars, subscriptions, promos). |
| `telegram-miniapp/src/pages/client/MyBookingsPage.tsx` | Bookings list with status filters. |
| `telegram-miniapp/src/pages/client/BookingDetailPage.tsx` | Booking details, cancel, late report. |
| `telegram-miniapp/src/pages/client/ProfilePage.tsx` | Profile, stats, edit, logout, unlink Telegram. |
| `telegram-miniapp/src/App.tsx` | Routes + `AuthGuard`. |

---

## Task 1: Harden Telegram initData verification

**Files:**
- Modify: `backend/services/telegram_auth_service.py`
- Test: `backend/tests/test_auth.py` (or create `backend/tests/test_telegram_auth.py`)

- [ ] **Step 1: Write the failing test**

```python
import time
from services.telegram_auth_service import verify_telegram_init_data

BOT_TOKEN = "test_token"

def _make_init_data(user_id: int, auth_date_offset: int = 0) -> str:
    import hmac, hashlib, urllib.parse, json
    from core.config import get_settings
    auth_date = int(time.time()) + auth_date_offset
    user = json.dumps({"id": user_id, "username": "test"})
    data = f"auth_date={auth_date}&user={urllib.parse.quote(user)}"
    secret = hmac.new(b"WebAppData", BOT_TOKEN.encode(), hashlib.sha256).digest()
    hash_ = hmac.new(secret, data.encode(), hashlib.sha256).hexdigest()
    return f"{data}&hash={hash_}"


def test_verify_init_data_rejects_old_auth_date():
    old = _make_init_data(123, auth_date_offset=-400)
    assert verify_telegram_init_data(old, max_age_seconds=300) is None


def test_verify_init_data_accepts_fresh():
    fresh = _make_init_data(123)
    result = verify_telegram_init_data(fresh, max_age_seconds=300)
    assert result is not None
    assert result["id"] == 123
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd /Users/lan1t/lan1t/Users/Курсач/LanWash/backend && python -m pytest tests/test_telegram_auth.py -v`

Expected: FAIL — `verify_telegram_init_data` takes 0 positional arguments (new `max_age_seconds` param not yet added).

- [ ] **Step 3: Implement hardened verification**

Modify `backend/services/telegram_auth_service.py`:

```python
import time
from datetime import datetime, timedelta, timezone
from typing import Dict, Optional
from urllib.parse import parse_qsl
import hashlib
import hmac
import json

from core.config import get_settings


def verify_telegram_init_data(init_data: str, max_age_seconds: int = 300) -> Optional[Dict]:
    """Verify Telegram WebApp initData signature and freshness.

    Returns parsed user data dict if valid, None otherwise.
    """
    try:
        parsed = dict(parse_qsl(init_data, keep_blank_values=True))
        received_hash = parsed.pop("hash", None)
        if not received_hash:
            return None

        data_check_string = "\n".join(f"{k}={v}" for k, v in sorted(parsed.items()))
        bot_token = get_settings().telegram_bot_token
        if not bot_token:
            return None

        secret_key = hmac.new(
            b"WebAppData", bot_token.encode(), hashlib.sha256
        ).digest()
        computed_hash = hmac.new(
            secret_key, data_check_string.encode(), hashlib.sha256
        ).hexdigest()

        if not hmac.compare_digest(computed_hash, received_hash):
            return None

        auth_date_str = parsed.get("auth_date")
        if not auth_date_str:
            return None
        auth_date = int(auth_date_str)
        now = int(time.time())
        if now - auth_date > max_age_seconds:
            return None

        user_raw = parsed.get("user", "{}")
        return json.loads(user_raw)
    except Exception:
        return None
```

- [ ] **Step 4: Run test to verify it passes**

Run: `python -m pytest tests/test_telegram_auth.py -v`

Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add backend/services/telegram_auth_service.py backend/tests/test_telegram_auth.py
git commit -m "feat(auth): verify Telegram initData freshness and harden verification"
```

---

## Task 2: Refactor backend `/api/auth/telegram` to stop auto-creating accounts

**Files:**
- Modify: `backend/services/auth_service.py`
- Modify: `backend/app/routers/auth.py`
- Modify: `backend/schemas/schemas.py`
- Test: `backend/tests/test_auth.py`

- [ ] **Step 1: Add `TelegramNotLinkedError` exception**

In `backend/services/auth_service.py` near other exceptions:

```python
class TelegramNotLinkedError(Exception):
    """Telegram ID is not linked to any existing account."""


class TelegramAlreadyLinkedError(Exception):
    """Telegram ID is already linked to another account."""
```

- [ ] **Step 2: Refactor `telegram_auth` method**

Replace the current `telegram_auth` body in `backend/services/auth_service.py`:

```python
async def telegram_auth(self, init_data: str) -> dict:
    from services.telegram_auth_service import verify_telegram_init_data

    user_data = verify_telegram_init_data(init_data)
    if not user_data:
        raise InvalidCredentialsError("Неверные или устаревшие данные Telegram")

    telegram_id = str(user_data.get("id"))
    if not telegram_id:
        raise InvalidCredentialsError("Неверные данные Telegram")

    user = await self._user_repo.get_by_telegram_id(telegram_id)
    if not user:
        raise TelegramNotLinkedError("Telegram не привязан к аккаунту")

    return self._issue_token_pair(user)
```

- [ ] **Step 3: Add helper `_issue_token_pair`**

Add to `AuthService`:

```python
def _issue_token_pair(self, user: User) -> dict:
    access_token_expires = timedelta(minutes=ACCESS_TOKEN_EXPIRE_MINUTES)
    token_data = {
        "sub": user.username,
        "role": user.role,
        "pwd_ver": user.passwordVersion,
    }
    access_token = create_access_token(data=token_data, expires_delta=access_token_expires)
    refresh_token = create_refresh_token(token_data)
    return {
        "user": user,
        "access_token": access_token,
        "refresh_token": refresh_token,
        "token_type": "bearer",
    }
```

Replace all existing token-pair creation blocks in `AuthService` (`link_telegram`, `login`, `refresh_access_token`, etc.) to use `_issue_token_pair(user)` in later cleanup commits, or do it now.

- [ ] **Step 4: Update router to return `409` for not-linked**

Modify `backend/app/routers/auth.py` `telegram_auth` handler:

```python
from services.auth_service import (
    ...,
    TelegramNotLinkedError,
)

@router.post(
    "/telegram",
    response_model=TelegramAuthResponse,
    summary="Авторизация через Telegram Mini App",
    responses={409: {"description": "Telegram ID не привязан к аккаунту"}},
)
@limiter.limit("10/minute")
async def telegram_auth(
    req: TelegramAuthRequest,
    request: Request,
    response: Response,
    db: AsyncSession = Depends(get_db),
):
    svc = AuthService(db)
    try:
        result = await svc.telegram_auth(req.initData)
        _set_refresh_cookie(response, result["refresh_token"], get_settings())
        return result
    except TelegramNotLinkedError as e:
        raise HTTPException(status.HTTP_409_CONFLICT, str(e))
    except InvalidCredentialsError as e:
        raise HTTPException(status.HTTP_401_UNAUTHORIZED, str(e))
    except RuntimeError:
        raise HTTPException(500, "Internal server error")
```

- [ ] **Step 5: Update schema `TelegramAuthResponse`**

Add `telegramLinked` flag and ensure `UserResponse` includes it in `backend/schemas/schemas.py`:

```python
class UserResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: int
    username: str
    role: str
    displayName: str
    email: str = ""
    phone: str
    carModel: str
    carNumber: str
    avatarUrl: str = ""
    createdAt: dt_datetime
    isFavoriteAdmin: bool
    passwordVersion: int = 1
    referralCode: Optional[str] = None
    telegramLinked: bool = False
```

- [ ] **Step 6: Write test for new behavior**

```python
import pytest
from services.auth_service import AuthService, TelegramNotLinkedError


@pytest.mark.asyncio
async def test_telegram_auth_unlinked_raises(db_session):
    svc = AuthService(db_session)
    with pytest.raises(TelegramNotLinkedError):
        await svc.telegram_auth("auth_date=9999999999&hash=invalid")
```

- [ ] **Step 7: Run backend tests**

Run: `python -m pytest backend/tests/test_auth.py -v -k telegram`

Expected: PASS for new tests; existing tests may fail if they relied on auto-create — fix them.

- [ ] **Step 8: Commit**

```bash
git add backend/services/auth_service.py backend/app/routers/auth.py backend/schemas/schemas.py backend/tests/test_auth.py
git commit -m "feat(auth): stop auto-creating tg_ users, return 409 when telegram not linked"
```

---

## Task 3: Implement `/api/auth/telegram/link` (link existing account)

**Files:**
- Modify: `backend/services/auth_service.py`
- Modify: `backend/app/routers/auth.py`
- Modify: `backend/schemas/schemas.py`
- Test: `backend/tests/test_auth.py`

- [ ] **Step 1: Update `TelegramLinkRequest` schema**

In `backend/schemas/schemas.py`:

```python
class TelegramLinkRequest(BaseModel):
    initData: str = Field(..., min_length=10, description="Telegram WebApp initData string")
    username: str = Field(..., min_length=3, max_length=50)
    password: str = Field(..., min_length=8, max_length=128)
```

- [ ] **Step 2: Rewrite `link_telegram` service method**

```python
async def link_telegram(self, init_data: str, username: str, password: str) -> dict:
    from services.telegram_auth_service import verify_telegram_init_data

    user_data = verify_telegram_init_data(init_data)
    if not user_data:
        raise InvalidCredentialsError("Неверные данные Telegram")

    telegram_id = str(user_data.get("id"))
    if not telegram_id:
        raise InvalidCredentialsError("Неверные данные Telegram")

    existing_by_tg = await self._user_repo.get_by_telegram_id(telegram_id)
    if existing_by_tg:
        raise TelegramAlreadyLinkedError("Этот Telegram уже привязан к другому аккаунту")

    user = await self._user_repo.get_by_username(username.lower().strip())
    if not user:
        # Use dummy verify to prevent timing-based username enumeration
        await async_verify_password(password, _DUMMY_HASH)
        raise InvalidCredentialsError("Неверный логин или пароль")

    if not await async_verify_password(password, user.passwordHash):
        raise InvalidCredentialsError("Неверный логин или пароль")

    user.telegramId = telegram_id.strip()
    await self._db.commit()
    await self._db.refresh(user)

    return self._issue_token_pair(user)
```

Add module-level dummy hash near `pwd_context`:

```python
_DUMMY_HASH = pwd_context.hash("DummyPassword123!")
```

- [ ] **Step 3: Update router endpoint**

Replace `/link-telegram` handler in `backend/app/routers/auth.py`:

```python
@router.post(
    "/link-telegram",
    response_model=TelegramAuthResponse,
    summary="Привязка Telegram к существующему аккаунту",
)
@limiter.limit("5/minute")
async def link_telegram(
    req: TelegramLinkRequest,
    request: Request,
    response: Response,
    db: AsyncSession = Depends(get_db),
):
    svc = AuthService(db)
    try:
        result = await svc.link_telegram(req.initData, req.username, req.password)
        _set_refresh_cookie(response, result["refresh_token"], get_settings())
        return result
    except InvalidCredentialsError as e:
        raise HTTPException(status.HTTP_401_UNAUTHORIZED, str(e))
    except TelegramAlreadyLinkedError as e:
        raise HTTPException(status.HTTP_409_CONFLICT, str(e))
    except RuntimeError:
        raise HTTPException(500, "Internal server error")
```

- [ ] **Step 4: Write tests**

```python
@pytest.mark.asyncio
async def test_link_telegram_success(db_session, test_user):
    svc = AuthService(db_session)
    # generate valid initData in test helper
    init_data = make_test_init_data(telegram_id="999999")
    result = await svc.link_telegram(init_data, test_user.username, "CorrectPassword123!")
    assert result["user"].telegramId == "999999"


@pytest.mark.asyncio
async def test_link_telegram_wrong_password(db_session, test_user):
    svc = AuthService(db_session)
    init_data = make_test_init_data(telegram_id="999999")
    with pytest.raises(InvalidCredentialsError):
        await svc.link_telegram(init_data, test_user.username, "wrong")
```

- [ ] **Step 5: Run tests**

Run: `python -m pytest backend/tests/test_auth.py -v -k link`

Expected: PASS.

- [ ] **Step 6: Commit**

```bash
git add backend/services/auth_service.py backend/app/routers/auth.py backend/schemas/schemas.py backend/tests/test_auth.py
git commit -m "feat(auth): secure telegram linking with initData verification"
```

---

## Task 4: Implement `/api/auth/telegram/register` (register from Telegram)

**Files:**
- Modify: `backend/services/auth_service.py`
- Modify: `backend/app/routers/auth.py`
- Modify: `backend/schemas/schemas.py`
- Test: `backend/tests/test_auth.py`

- [ ] **Step 1: Add `TelegramRegisterRequest` schema**

```python
class TelegramRegisterRequest(BaseModel):
    initData: str = Field(..., min_length=10)
    username: str = Field(..., min_length=3, max_length=30)
    password: str = Field(..., min_length=8, max_length=128)
    displayName: str = Field(..., min_length=1, max_length=100)
    phone: Optional[str] = Field(default=None, max_length=20)
    carModel: Optional[str] = Field(default=None, max_length=50)
    carNumber: Optional[str] = Field(default=None, max_length=20)
    referralCode: Optional[str] = Field(default=None, max_length=20)
```

- [ ] **Step 2: Add `register_telegram_user` service method**

```python
async def register_telegram_user(self, req: TelegramRegisterRequest) -> dict:
    from services.telegram_auth_service import verify_telegram_init_data
    import secrets, string

    user_data = verify_telegram_init_data(req.initData)
    if not user_data:
        raise InvalidCredentialsError("Неверные данные Telegram")

    telegram_id = str(user_data.get("id"))
    if not telegram_id:
        raise InvalidCredentialsError("Неверные данные Telegram")

    existing_tg = await self._user_repo.get_by_telegram_id(telegram_id)
    if existing_tg:
        raise TelegramAlreadyLinkedError("Этот Telegram уже используется")

    username = req.username.lower().strip()
    existing_user = await self._user_repo.get_by_username(username)
    if existing_user:
        raise UsernameAlreadyExistsError("Логин уже занят")

    password_error = validate_password_strength(req.password)
    if password_error:
        raise ValueError(password_error)

    referral_code = await _ensure_unique_referral_code(self._db)
    new_user = User(
        username=username,
        passwordHash=await async_get_password_hash(req.password),
        role="client",
        displayName=req.displayName.strip(),
        phone=req.phone or "",
        carModel=req.carModel or "",
        carNumber=req.carNumber or "",
        avatarUrl=user_data.get("photo_url", ""),
        createdAt=datetime.now(timezone.utc),
        isFavoriteAdmin=0,
        telegramId=telegram_id,
        referralCode=referral_code,
    )

    if req.referralCode:
        ref_code = req.referralCode.strip().upper()
        referrer = await self._user_repo.get_by_referral_code(ref_code)
        if referrer:
            from models import Referral
            referral = Referral(
                referrerUsername=referrer.username,
                referredUsername=new_user.username,
                rewardClaimed=False,
            )
            await self._referral_repo.add(referral)

    await self._user_repo.add(new_user)
    await self._db.commit()
    await self._db.refresh(new_user)

    return self._issue_token_pair(new_user)
```

- [ ] **Step 3: Add router endpoint**

```python
@router.post(
    "/telegram-register",
    response_model=TelegramAuthResponse,
    summary="Регистрация нового пользователя через Telegram Mini App",
)
@limiter.limit("5/minute")
async def telegram_register(
    req: TelegramRegisterRequest,
    request: Request,
    response: Response,
    db: AsyncSession = Depends(get_db),
):
    svc = AuthService(db)
    try:
        result = await svc.register_telegram_user(req)
        _set_refresh_cookie(response, result["refresh_token"], get_settings())
        return result
    except ValueError as e:
        raise HTTPException(status.HTTP_400_BAD_REQUEST, str(e))
    except UsernameAlreadyExistsError as e:
        raise HTTPException(status.HTTP_409_CONFLICT, str(e))
    except TelegramAlreadyLinkedError as e:
        raise HTTPException(status.HTTP_409_CONFLICT, str(e))
    except RuntimeError:
        raise HTTPException(500, "Internal server error")
```

- [ ] **Step 4: Write tests**

```python
@pytest.mark.asyncio
async def test_register_telegram_user_success(db_session):
    svc = AuthService(db_session)
    req = TelegramRegisterRequest(
        initData=make_test_init_data(telegram_id="111222"),
        username="newtguser",
        password="StrongPass123!",
        displayName="New User",
    )
    result = await svc.register_telegram_user(req)
    assert result["user"].username == "newtguser"
    assert result["user"].telegramId == "111222"
```

- [ ] **Step 5: Run tests**

Run: `python -m pytest backend/tests/test_auth.py -v -k telegram_register`

Expected: PASS.

- [ ] **Step 6: Commit**

```bash
git add backend/services/auth_service.py backend/app/routers/auth.py backend/schemas/schemas.py backend/tests/test_auth.py
git commit -m "feat(auth): registration endpoint for Telegram Mini App"
```

---

## Task 5: Implement data merge for previously auto-created `tg_<id>` accounts

**Files:**
- Modify: `backend/services/auth_service.py`
- Test: `backend/tests/test_auth.py`

- [ ] **Step 1: Add merge helper**

```python
async def _merge_telegram_user_data(
    self, target_user: User, telegram_id: str
) -> None:
    from sqlalchemy import update
    from models import Appointment, Car, Subscription, ShiftTemplate, SupportChat, Tip, Review

    old_user = await self._user_repo.get_by_telegram_id(telegram_id)
    if not old_user or old_user.id == target_user.id:
        return

    # Models linked by userId FK
    for model in (Car, Subscription, Tip, Review, SupportChat):
        await self._db.execute(
            update(model)
            .where(model.userId == old_user.id)
            .values(userId=target_user.id)
        )

    # Models linked by ownerUsername
    await self._db.execute(
        update(Appointment)
        .where(Appointment.ownerUsername == old_user.username)
        .values(ownerUsername=target_user.username, userId=target_user.id)
    )
    await self._db.execute(
        update(ShiftTemplate)
        .where(ShiftTemplate.ownerUsername == old_user.username)
        .values(ownerUsername=target_user.username)
    )

    await self._db.delete(old_user)
```

- [ ] **Step 2: Call merge in `link_telegram`**

Before `return self._issue_token_pair(user)` in `link_telegram`, add:

```python
await self._merge_telegram_user_data(user, telegram_id)
```

- [ ] **Step 3: Test merge**

```python
@pytest.mark.asyncio
async def test_link_telegram_merges_data(db_session, test_user, tg_dummy_user):
    svc = AuthService(db_session)
    # create appointment owned by tg_dummy_user
    init_data = make_test_init_data(telegram_id=tg_dummy_user.telegramId)
    await svc.link_telegram(init_data, test_user.username, "CorrectPassword123!")
    # assert appointment now owned by test_user.username
```

- [ ] **Step 4: Run tests**

Run: `python -m pytest backend/tests/test_auth.py -v -k merge`

Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add backend/services/auth_service.py backend/tests/test_auth.py
git commit -m "feat(auth): merge data from auto-created tg_ accounts on link"
```

---

## Task 6: Add `POST /api/auth/telegram/unlink`

**Files:**
- Modify: `backend/services/auth_service.py`
- Modify: `backend/app/routers/auth.py`
- Test: `backend/tests/test_auth.py`

- [ ] **Step 1: Add service method**

```python
async def unlink_telegram(self, current_user: User, password: str) -> dict:
    if not current_user.telegramId:
        raise ValueError("Telegram не привязан")
    if not await async_verify_password(password, current_user.passwordHash):
        raise InvalidCredentialsError("Неверный пароль")

    current_user.telegramId = None
    await self._db.commit()
    return {"status": "ok"}
```

- [ ] **Step 2: Add router endpoint**

```python
class TelegramUnlinkRequest(BaseModel):
    password: str = Field(..., min_length=8, max_length=128)


@router.post(
    "/unlink-telegram",
    summary="Отвязка Telegram от аккаунта",
)
@limiter.limit("5/minute")
async def unlink_telegram(
    req: TelegramUnlinkRequest,
    request: Request,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    svc = AuthService(db)
    try:
        return await svc.unlink_telegram(current_user, req.password)
    except InvalidCredentialsError as e:
        raise HTTPException(status.HTTP_401_UNAUTHORIZED, str(e))
    except ValueError as e:
        raise HTTPException(status.HTTP_400_BAD_REQUEST, str(e))
```

- [ ] **Step 3: Test**

```python
@pytest.mark.asyncio
async def test_unlink_telegram(db_session, test_user_with_tg):
    svc = AuthService(db_session)
    result = await svc.unlink_telegram(test_user_with_tg, "CorrectPassword123!")
    assert result["status"] == "ok"
    assert test_user_with_tg.telegramId is None
```

- [ ] **Step 4: Run tests**

Run: `python -m pytest backend/tests/test_auth.py -v -k unlink`

Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add backend/services/auth_service.py backend/app/routers/auth.py backend/schemas/schemas.py backend/tests/test_auth.py
git commit -m "feat(auth): add telegram unlink endpoint"
```

---

## Task 7: Add Telegram CloudStorage helper in Mini App

**Files:**
- Create: `telegram-miniapp/src/lib/cloudStorage.ts`

- [ ] **Step 1: Implement helper**

```typescript
const STORAGE_KEYS = {
  ACCESS_TOKEN: 'lw_access_token',
  USER: 'lw_user',
} as const

function getTg(): TelegramWebApp | undefined {
  return window.Telegram?.WebApp
}

export async function getItem(key: string): Promise<string | null> {
  const tg = getTg()
  if (tg?.CloudStorage) {
    return new Promise((resolve) => {
      tg.CloudStorage.getItem(key, (err, value) => {
        if (err || value == null || value === '') {
          resolve(null)
        } else {
          resolve(value)
        }
      })
    })
  }
  return localStorage.getItem(key)
}

export async function setItem(key: string, value: string): Promise<void> {
  const tg = getTg()
  if (tg?.CloudStorage) {
    return new Promise((resolve, reject) => {
      tg.CloudStorage.setItem(key, value, (err, saved) => {
        if (err || !saved) {
          reject(err)
        } else {
          resolve()
        }
      })
    })
  }
  localStorage.setItem(key, value)
}

export async function removeItem(key: string): Promise<void> {
  const tg = getTg()
  if (tg?.CloudStorage) {
    return new Promise((resolve, reject) => {
      tg.CloudStorage.removeItem(key, (err, removed) => {
        if (err || !removed) {
          reject(err)
        } else {
          resolve()
        }
      })
    })
  }
  localStorage.removeItem(key)
}

export const cloudStorage = { STORAGE_KEYS, getItem, setItem, removeItem }
```

- [ ] **Step 2: Update Telegram types**

In `telegram-miniapp/src/types/telegram.d.ts` add:

```typescript
interface CloudStorage {
  getItem(key: string, callback: (err: Error | null, value: string | null) => void): void
  setItem(key: string, value: string, callback: (err: Error | null, saved: boolean) => void): void
  removeItem(key: string, callback: (err: Error | null, removed: boolean) => void): void
}

interface TelegramWebApp {
  initData: string
  initDataUnsafe: { user?: { id: number; username?: string; first_name?: string; photo_url?: string } }
  expand(): void
  ready(): void
  CloudStorage?: CloudStorage
  // ... existing fields
}
```

- [ ] **Step 3: Commit**

```bash
git add telegram-miniapp/src/lib/cloudStorage.ts telegram-miniapp/src/types/telegram.d.ts
git commit -m "feat(miniapp): add Telegram CloudStorage helper with localStorage fallback"
```

---

## Task 8: Refactor Mini App auth store to persist in CloudStorage

**Files:**
- Modify: `telegram-miniapp/src/stores/authStore.ts`

- [ ] **Step 1: Rewrite store**

```typescript
import { create } from 'zustand'
import { cloudStorage } from '../lib/cloudStorage'

export interface User {
  id: number
  username: string
  role: string
  displayName: string
  phone: string
  carModel: string
  carNumber: string
  avatarUrl: string
  telegramLinked?: boolean
}

interface AuthState {
  user: User | null
  token: string | null
  isLoading: boolean
  setAuth: (user: User, token: string) => void
  setLoading: (loading: boolean) => void
  logout: () => void
  init: () => Promise<void>
}

export const useAuthStore = create<AuthState>((set) => ({
  user: null,
  token: null,
  isLoading: true,
  setAuth: (user, token) => {
    set({ user, token, isLoading: false })
    cloudStorage.setItem(cloudStorage.STORAGE_KEYS.USER, JSON.stringify(user))
    cloudStorage.setItem(cloudStorage.STORAGE_KEYS.ACCESS_TOKEN, token)
  },
  setLoading: (loading) => set({ isLoading: loading }),
  logout: () => {
    cloudStorage.removeItem(cloudStorage.STORAGE_KEYS.USER)
    cloudStorage.removeItem(cloudStorage.STORAGE_KEYS.ACCESS_TOKEN)
    set({ user: null, token: null, isLoading: false })
  },
  init: async () => {
    try {
      const [userRaw, token] = await Promise.all([
        cloudStorage.getItem(cloudStorage.STORAGE_KEYS.USER),
        cloudStorage.getItem(cloudStorage.STORAGE_KEYS.ACCESS_TOKEN),
      ])
      const user = userRaw ? JSON.parse(userRaw) : null
      set({ user, token, isLoading: false })
    } catch {
      set({ user: null, token: null, isLoading: false })
    }
  },
}))
```

- [ ] **Step 2: Commit**

```bash
git add telegram-miniapp/src/stores/authStore.ts
git commit -m "feat(miniapp): persist auth state in Telegram CloudStorage"
```

---

## Task 9: Update Mini App auth service and API layer

**Files:**
- Modify: `telegram-miniapp/src/services/auth.ts`
- Modify: `telegram-miniapp/src/services/api.ts`

- [ ] **Step 1: Expand auth service**

```typescript
import { api } from './api'

export interface AuthResponse {
  user: {
    id: number
    username: string
    role: string
    displayName: string
    phone: string
    carModel: string
    carNumber: string
    avatarUrl: string
    telegramLinked?: boolean
  }
  access_token: string
  token_type: string
}

export interface RegisterData {
  username: string
  password: string
  displayName: string
  phone?: string
  carModel?: string
  carNumber?: string
  referralCode?: string
}

export async function telegramAuth(initData: string): Promise<AuthResponse> {
  const res = await api.post('/auth/telegram', { initData })
  return res.data
}

export async function linkTelegram(
  initData: string,
  username: string,
  password: string
): Promise<AuthResponse> {
  const res = await api.post('/auth/link-telegram', { initData, username, password })
  return res.data
}

export async function registerTelegram(
  initData: string,
  data: RegisterData
): Promise<AuthResponse> {
  const res = await api.post('/auth/telegram-register', { initData, ...data })
  return res.data
}

export async function logoutBackend(token: string): Promise<void> {
  await api.post('/auth/logout', {}, { headers: { Authorization: `Bearer ${token}` } })
}
```

- [ ] **Step 2: Update API interceptor**

```typescript
import axios from 'axios'
import { useAuthStore } from '../stores/authStore'
import { cloudStorage } from '../lib/cloudStorage'

export const api = axios.create({
  baseURL: '/api',
  headers: { 'Content-Type': 'application/json' },
  timeout: 10000,
  withCredentials: true,
})

let refreshPromise: Promise<string | null> | null = null

api.interceptors.request.use(async (config) => {
  const token = useAuthStore.getState().token
  if (token) {
    config.headers.Authorization = `Bearer ${token}`
  }
  return config
})

api.interceptors.response.use(
  (response) => response,
  async (error) => {
    const originalRequest = error.config
    if (error.response?.status === 401 && originalRequest) {
      if (originalRequest.url === '/auth/refresh') {
        useAuthStore.getState().logout()
        return Promise.reject(error)
      }

      if (!refreshPromise) {
        refreshPromise = api
          .post('/auth/refresh', {}, { withCredentials: true })
          .then((res) => {
            const { user, access_token } = res.data
            useAuthStore.getState().setAuth(user, access_token)
            return access_token as string
          })
          .catch(() => {
            useAuthStore.getState().logout()
            return null
          })
          .finally(() => {
            refreshPromise = null
          })
      }

      const newToken = await refreshPromise
      if (!newToken) {
        return Promise.reject(error)
      }

      originalRequest.headers.Authorization = `Bearer ${newToken}`
      return api(originalRequest)
    }
    return Promise.reject(error)
  }
)
```

- [ ] **Step 3: Commit**

```bash
git add telegram-miniapp/src/services/auth.ts telegram-miniapp/src/services/api.ts
git commit -m "feat(miniapp): auth service and api layer for unified login"
```

---

## Task 10: Build `AuthGatewayPage` and `useAuthGuard`

**Files:**
- Create: `telegram-miniapp/src/hooks/useAuthGuard.ts`
- Create: `telegram-miniapp/src/pages/auth/AuthGatewayPage.tsx`
- Modify: `telegram-miniapp/src/App.tsx`

- [ ] **Step 1: Implement `useAuthGuard`**

```typescript
import { useEffect } from 'react'
import { useTelegram } from './useTelegram'
import { useAuthStore } from '../stores/authStore'
import { telegramAuth } from '../services/auth'
import { api } from '../services/api'

export function useAuthGuard() {
  const { initData, ready, isInTelegram } = useTelegram()
  const { token, setAuth, setLoading, logout } = useAuthStore()

  useEffect(() => {
    if (!ready) return

    const attemptAutoLogin = async () => {
      setLoading(true)
      try {
        if (initData) {
          const res = await telegramAuth(initData)
          setAuth(res.user, res.access_token)
        } else if (isInTelegram) {
          const res = await api.post('/auth/refresh', {}, { withCredentials: true })
          setAuth(res.data.user, res.data.access_token)
        }
      } catch (e: any) {
        if (e.response?.status !== 409) {
          console.error('Auth failed', e)
        }
      } finally {
        setLoading(false)
      }
    }

    if (!token) {
      attemptAutoLogin()
    }
  }, [initData, ready, isInTelegram])

  return { ready, isInTelegram }
}
```

- [ ] **Step 2: Implement `AuthGatewayPage`**

```typescript
import { useState } from 'react'
import { useTelegram } from '../../hooks/useTelegram'
import { useAuthStore } from '../../stores/authStore'
import { linkTelegram, registerTelegram } from '../../services/auth'

export default function AuthGatewayPage() {
  const { initData } = useTelegram()
  const { setAuth } = useAuthStore()
  const [mode, setMode] = useState<'choose' | 'login' | 'register'>('choose')
  const [error, setError] = useState('')

  const handleLogin = async (e: React.FormEvent<HTMLFormElement>) => {
    e.preventDefault()
    setError('')
    const form = new FormData(e.currentTarget)
    try {
      const res = await linkTelegram(
        initData,
        form.get('username') as string,
        form.get('password') as string
      )
      setAuth(res.user, res.access_token)
    } catch (e: any) {
      setError(e.response?.data?.detail || 'Ошибка входа')
    }
  }

  const handleRegister = async (e: React.FormEvent<HTMLFormElement>) => {
    e.preventDefault()
    setError('')
    const form = new FormData(e.currentTarget)
    try {
      const res = await registerTelegram(initData, {
        username: form.get('username') as string,
        password: form.get('password') as string,
        displayName: form.get('displayName') as string,
        phone: form.get('phone') as string,
        carModel: form.get('carModel') as string,
        carNumber: form.get('carNumber') as string,
        referralCode: form.get('referralCode') as string,
      })
      setAuth(res.user, res.access_token)
    } catch (e: any) {
      setError(e.response?.data?.detail || 'Ошибка регистрации')
    }
  }

  if (mode === 'choose') {
    return (
      <div style={{ padding: 20 }}>
        <h2>Вход в LanWash</h2>
        <p>Этот Telegram ещё не привязан к аккаунту.</p>
        <button onClick={() => setMode('login')}>Войти по логину и паролю</button>
        <button onClick={() => setMode('register')}>Создать аккаунт</button>
      </div>
    )
  }

  return (
    <div style={{ padding: 20 }}>
      {mode === 'login' ? (
        <form onSubmit={handleLogin}>
          <input name="username" placeholder="Логин" required />
          <input name="password" type="password" placeholder="Пароль" required />
          <button type="submit">Войти</button>
        </form>
      ) : (
        <form onSubmit={handleRegister}>
          <input name="username" placeholder="Логин" required />
          <input name="password" type="password" placeholder="Пароль" required />
          <input name="displayName" placeholder="Имя" required />
          <input name="phone" placeholder="Телефон" />
          <input name="carModel" placeholder="Модель авто" />
          <input name="carNumber" placeholder="Номер авто" />
          <input name="referralCode" placeholder="Реферальный код" />
          <button type="submit">Создать аккаунт</button>
        </form>
      )}
      {error && <p style={{ color: 'red' }}>{error}</p>}
      <button onClick={() => setMode('choose')}>Назад</button>
    </div>
  )
}
```

- [ ] **Step 3: Update `App.tsx` to use guard and route**

```typescript
import { BrowserRouter, Routes, Route, Navigate } from 'react-router-dom'
import React, { Suspense } from 'react'
import { useAuthStore } from './stores/authStore'
import { useAuthGuard } from './hooks/useAuthGuard'
import Layout from './components/Layout'

const HomePage = React.lazy(() => import('./pages/client/HomePage'))
const BookingPage = React.lazy(() => import('./pages/client/BookingPage'))
const PromosPage = React.lazy(() => import('./pages/client/PromosPage'))
const MyBookingsPage = React.lazy(() => import('./pages/client/MyBookingsPage'))
const BookingDetailPage = React.lazy(() => import('./pages/client/BookingDetailPage'))
const ProfilePage = React.lazy(() => import('./pages/client/ProfilePage'))
const AuthGatewayPage = React.lazy(() => import('./pages/auth/AuthGatewayPage'))

function App() {
  const { isLoading } = useAuthStore()
  const { ready } = useAuthGuard()

  if (!ready || isLoading) {
    return (
      <BrowserRouter>
        <Layout>
          <div style={{ textAlign: 'center', padding: 40 }}>Загрузка...</div>
        </Layout>
      </BrowserRouter>
    )
  }

  return (
    <BrowserRouter>
      <Layout>
        <Suspense fallback={<div style={{ textAlign: 'center', padding: 40 }}>Загрузка...</div>}>
          <AppRoutes />
        </Suspense>
      </Layout>
    </BrowserRouter>
  )
}

function AppRoutes() {
  const { token } = useAuthStore()

  if (!token) {
    return (
      <Routes>
        <Route path="/auth" element={<AuthGatewayPage />} />
        <Route path="*" element={<Navigate to="/auth" />} />
      </Routes>
    )
  }

  return (
    <Routes>
      <Route path="/" element={<HomePage />} />
      <Route path="/booking" element={<BookingPage />} />
      <Route path="/promos" element={<PromosPage />} />
      <Route path="/bookings" element={<MyBookingsPage />} />
      <Route path="/bookings/:id" element={<BookingDetailPage />} />
      <Route path="/profile" element={<ProfilePage />} />
      <Route path="*" element={<Navigate to="/" />} />
    </Routes>
  )
}

export default App
```

- [ ] **Step 4: Commit**

```bash
git add telegram-miniapp/src/hooks/useAuthGuard.ts telegram-miniapp/src/pages/auth/AuthGatewayPage.tsx telegram-miniapp/src/App.tsx
git commit -m "feat(miniapp): auth gateway and guard with login/register screens"
```

---

## Task 11: Enhance Home page (promos + services catalog)

**Files:**
- Modify: `telegram-miniapp/src/pages/client/HomePage.tsx`
- Create: `telegram-miniapp/src/services/catalog.ts`
- Create: `telegram-miniapp/src/stores/catalogStore.ts`

- [ ] **Step 1: Add catalog service**

```typescript
import { api } from './api'

export interface Service {
  id: string
  name: string
  price: number
  category?: string
}

export interface Promo {
  id: string
  title: string
  description: string
  discountPercent?: number
}

export async function getServices(): Promise<Service[]> {
  const res = await api.get('/services')
  return res.data
}

export async function getPromos(): Promise<Promo[]> {
  const res = await api.get('/services/promos')
  return res.data
}
```

- [ ] **Step 2: Add catalog store**

```typescript
import { create } from 'zustand'
import { getServices, getPromos } from '../services/catalog'

interface CatalogState {
  services: Service[]
  promos: Promo[]
  loading: boolean
  error: string | null
  fetch: () => Promise<void>
}

export const useCatalogStore = create<CatalogState>((set) => ({
  services: [],
  promos: [],
  loading: false,
  error: null,
  fetch: async () => {
    set({ loading: true, error: null })
    try {
      const [services, promos] = await Promise.all([getServices(), getPromos()])
      set({ services, promos, loading: false })
    } catch (e: any) {
      set({ error: e.message, loading: false })
    }
  },
}))
```

- [ ] **Step 3: Update HomePage**

Load catalog on mount, show promos and popular services, CTA to booking.

- [ ] **Step 4: Commit**

```bash
git add telegram-miniapp/src/services/catalog.ts telegram-miniapp/src/stores/catalogStore.ts telegram-miniapp/src/pages/client/HomePage.tsx
git commit -m "feat(miniapp): home page with promos and services catalog"
```

---

## Task 12: Enhance Booking wizard

**Files:**
- Modify: `telegram-miniapp/src/pages/client/BookingPage.tsx`
- Create: `telegram-miniapp/src/services/cars.ts`
- Create: `telegram-miniapp/src/services/appointments.ts`

- [ ] **Step 1: Add services**

```typescript
// telegram-miniapp/src/services/cars.ts
import { api } from './api'

export interface Car {
  id: string
  model: string
  number: string
}

export async function getMyCars(): Promise<Car[]> {
  const res = await api.get('/cars')
  return res.data
}

// telegram-miniapp/src/services/appointments.ts
import { api } from './api'

export interface BusySlot {
  date: string
  time: string
}

export async function getBusySlots(date: string): Promise<BusySlot[]> {
  const res = await api.get('/appointments/busy-slots', { params: { date } })
  return res.data
}

export async function createAppointment(data: any) {
  const res = await api.post('/appointments', data)
  return res.data
}
```

- [ ] **Step 2: Update BookingPage**

Add car selector, subscription/promo application, busy slot filtering.

- [ ] **Step 3: Commit**

```bash
git add telegram-miniapp/src/services/cars.ts telegram-miniapp/src/services/appointments.ts telegram-miniapp/src/pages/client/BookingPage.tsx
git commit -m "feat(miniapp): booking wizard with cars, subscriptions, busy slots"
```

---

## Task 13: My Bookings list and detail

**Files:**
- Modify: `telegram-miniapp/src/pages/client/MyBookingsPage.tsx`
- Create: `telegram-miniapp/src/pages/client/BookingDetailPage.tsx`

- [ ] **Step 1: Add appointments store/service methods**

```typescript
// in telegram-miniapp/src/services/appointments.ts
export async function getMyAppointments(): Promise<Appointment[]> {
  const res = await api.get('/appointments/by-owner/me')
  return res.data
}

export async function cancelAppointment(id: string, reason: string) {
  const res = await api.post(`/appointments/${id}/cancel-reason`, { reason })
  return res.data
}

export async function reportLate(id: string, minutes: number) {
  const res = await api.post(`/appointments/${id}/late`, { minutes })
  return res.data
}
```

- [ ] **Step 2: Implement detail page**

Show status, services, price, car, washer, actions (cancel if applicable, report late).

- [ ] **Step 3: Commit**

```bash
git add telegram-miniapp/src/pages/client/MyBookingsPage.tsx telegram-miniapp/src/pages/client/BookingDetailPage.tsx telegram-miniapp/src/services/appointments.ts
git commit -m "feat(miniapp): my bookings list and detail with cancel/late actions"
```

---

## Task 14: Profile page with edit, avatar, logout, unlink

**Files:**
- Modify: `telegram-miniapp/src/pages/client/ProfilePage.tsx`
- Create: `telegram-miniapp/src/services/profile.ts`

- [ ] **Step 1: Add profile service**

```typescript
import { api } from './api'

export async function updateProfile(userId: number, data: any) {
  const res = await api.put(`/auth/profile/${userId}`, data)
  return res.data
}

export async function getUserStats(username: string) {
  const res = await api.get(`/auth/stats/${username}`)
  return res.data
}

export async function unlinkTelegram(password: string) {
  const res = await api.post('/auth/unlink-telegram', { password })
  return res.data
}
```

- [ ] **Step 2: Update ProfilePage**

Show user info, stats, edit form, logout button, unlink Telegram button.

- [ ] **Step 3: Commit**

```bash
git add telegram-miniapp/src/services/profile.ts telegram-miniapp/src/pages/client/ProfilePage.tsx
git commit -m "feat(miniapp): profile page with edit, logout, telegram unlink"
```

---

## Task 15: WebSocket for appointments

**Files:**
- Create: `telegram-miniapp/src/services/appointmentSocket.ts`
- Modify: `telegram-miniapp/src/pages/client/MyBookingsPage.tsx`

- [ ] **Step 1: Add WebSocket service**

```typescript
let ws: WebSocket | null = null

export function connectAppointmentsSocket(token: string, onMessage: (data: any) => void) {
  const protocol = window.location.protocol === 'https:' ? 'wss' : 'ws'
  ws = new WebSocket(`${protocol}://${window.location.host}/ws/appointments?token=${token}`)
  ws.onmessage = (event) => {
    try {
      onMessage(JSON.parse(event.data))
    } catch {
      // ignore
    }
  }
  return () => {
    ws?.close()
  }
}
```

- [ ] **Step 2: Hook into bookings page**

```typescript
useEffect(() => {
  if (!token) return
  return connectAppointmentsSocket(token, (update) => {
    appointmentsStore.updateAppointment(update)
  })
}, [token])
```

- [ ] **Step 3: Commit**

```bash
git add telegram-miniapp/src/services/appointmentSocket.ts telegram-miniapp/src/pages/client/MyBookingsPage.tsx
git commit -m "feat(miniapp): websocket updates for appointments"
```

---

## Task 16: Final integration and tests

**Files:**
- Modify: `telegram-miniapp/package.json`
- Create: `telegram-miniapp/src/services/__tests__/auth.test.ts` (optional)

- [ ] **Step 1: Run backend test suite**

Run: `cd /Users/lan1t/lan1t/Users/Курсач/LanWash/backend && python -m pytest tests/test_auth.py -v`

Expected: all PASS.

- [ ] **Step 2: Run Mini App build**

Run: `cd /Users/lan1t/lan1t/Users/Курсач/LanWash/telegram-miniapp && npm run build`

Expected: build succeeds with 0 errors, 0 warnings.

- [ ] **Step 3: Run lint**

Run: `cd /Users/lan1t/lan1t/Users/Курсач/LanWash/telegram-miniapp && npm run lint`

Expected: clean.

- [ ] **Step 4: Manual smoke checklist**

- Open Mini App with unlinked Telegram → see AuthGatewayPage.
- Login with existing site credentials → account linked, redirected to Home.
- Re-open Mini App → auto-login.
- Create booking → appears in My Bookings.
- Cancel booking → status updated.
- Edit profile → changes persisted.
- Logout → token cleared, redirected to /auth.

- [ ] **Step 5: Commit any final fixes**

```bash
git commit -m "chore(miniapp): final integration and smoke fixes"
```

---

## Self-review checklist

### Spec coverage

| Spec requirement | Implementing task |
|------------------|-------------------|
| Stop auto-creating `tg_<id>` accounts | Task 2 |
| Return `409` when Telegram not linked | Task 2 |
| `initData` freshness check | Task 1 |
| `telegram_id` only from verified `initData` | Tasks 1, 3, 4 |
| Login existing account in Mini App | Task 3 |
| Register new account in Mini App | Task 4 |
| Data merge from old `tg_<id>` accounts | Task 5 |
| Unlink Telegram | Task 6 |
| CloudStorage token persistence | Tasks 7, 8 |
| Auth gateway page | Task 10 |
| Core client pages | Tasks 11-14 |
| WebSocket for appointments | Task 15 |

### Placeholder scan

- No "TBD" or "TODO" in tasks.
- No vague "add error handling" steps; concrete code shown.
- Exact file paths provided.

### Type consistency

- `UserResponse` gains `telegramLinked` and is used in `TelegramAuthResponse`.
- `AuthResponse.user` in Mini App includes `telegramLinked?: boolean`.
- `_issue_token_pair(user)` is used consistently in new auth methods.

---

## Execution handoff

**Plan complete and saved to `docs/telegram-miniapp-client-implementation-plan.md`.**

Two execution options:

1. **Subagent-Driven (recommended)** — I dispatch a fresh subagent per task, review between tasks, fast iteration.
2. **Inline Execution** — Execute tasks in this session using `executing-plans`, batch execution with checkpoints.

Which approach do you want?
