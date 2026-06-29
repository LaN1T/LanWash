import asyncio
import os
import re
from io import BytesIO

import structlog
from fastapi import (
    APIRouter,
    Depends,
    File,
    HTTPException,
    Request,
    Response,
    UploadFile,
    status,
)
from PIL import Image
from sqlalchemy.ext.asyncio import AsyncSession

from core.brute_force import is_locked_out, record_failed_attempt, reset_attempts
from core.config import Settings, get_settings
from core.limiter import limiter
from db.session import get_db
from models import User
from schemas import (
    FcmTokenRequest,
    LoginRequest,
    LoginResponse,
    RegisterRequest,
    TelegramAuthRequest,
    TelegramAuthResponse,
    TelegramLinkRequest,
    TelegramRegisterRequest,
    TelegramUnlinkRequest,
    UpdateProfileRequest,
    UserResponse,
    UserStatsResponse,
    WasherPublicResponse,
)
from services.auth_service import (
    AuthService,
    FcmTokenAccessDeniedError,
    InvalidCredentialsError,
    InvalidReferralCodeError,
    ProfileAccessDeniedError,
    SelfReferralError,
    StatsAccessDeniedError,
    TelegramAlreadyLinkedError,
    TelegramNotLinkedError,
    UsernameAlreadyExistsError,
    UserNotFoundError,
    get_current_user,
    oauth2_scheme,
    validate_password_strength,
)

logger = structlog.get_logger()

USERNAME_PATTERN = re.compile(r"^[a-z0-9_]{3,30}$")

UPLOAD_DIR = os.path.join(
    os.path.dirname(os.path.dirname(__file__)), "uploads", "avatars"
)
os.makedirs(UPLOAD_DIR, exist_ok=True)

router = APIRouter(
    prefix="/api/auth",
    tags=["auth"],
)


def _set_refresh_cookie(response: Response, token: str, settings: Settings) -> None:
    secure = settings.is_production
    response.set_cookie(
        key="refresh_token",
        value=token,
        httponly=True,
        max_age=settings.jwt_refresh_token_expire_days * 86400,
        secure=secure,
        samesite="Lax",
        path="/",
    )


@router.post(
    "/login",
    response_model=LoginResponse,
    summary="Вход в систему",
)
@limiter.limit("10/minute")
async def login(
    req: LoginRequest,
    request: Request,
    response: Response,
    db: AsyncSession = Depends(get_db),
):
    client_ip = request.client.host if request.client else "unknown"
    identifier = f"{client_ip}:{req.username.lower().strip()}"

    if await is_locked_out(identifier):
        raise HTTPException(
            status.HTTP_429_TOO_MANY_REQUESTS,
            "Слишком много неудачных попыток. Попробуйте позже.",
        )

    svc = AuthService(db)
    try:
        result = await svc.login(req.username.lower().strip(), req.password)
        await reset_attempts(identifier)
        _set_refresh_cookie(response, result["refresh_token"], get_settings())
        return result
    except InvalidCredentialsError as e:
        await record_failed_attempt(identifier)
        raise HTTPException(status.HTTP_401_UNAUTHORIZED, str(e))


@router.post(
    "/register",
    response_model=LoginResponse,
    summary="Регистрация нового пользователя",
)
@limiter.limit("5/minute")
async def register(
    req: RegisterRequest,
    request: Request,
    response: Response,
    db: AsyncSession = Depends(get_db),
):
    generic_error = HTTPException(
        status.HTTP_400_BAD_REQUEST,
        "Регистрация не удалась. Проверьте введённые данные.",
    )

    # Honeypot: bots often fill hidden fields
    if req.website:
        raise generic_error

    client_ip = request.client.host if request.client else "unknown"
    identifier = f"register:{client_ip}"

    if await is_locked_out(identifier):
        raise HTTPException(
            status.HTTP_429_TOO_MANY_REQUESTS,
            "Слишком много попыток регистрации. Попробуйте позже.",
        )

    if not req.username.strip():
        await record_failed_attempt(identifier)
        raise generic_error

    if not USERNAME_PATTERN.match(req.username.lower().strip()):
        await record_failed_attempt(identifier)
        raise generic_error

    password_error = validate_password_strength(req.password)
    if password_error:
        await record_failed_attempt(identifier)
        raise generic_error

    if not req.displayName.strip():
        await record_failed_attempt(identifier)
        raise generic_error

    svc = AuthService(db)
    try:
        result = await svc.register(req)
        await reset_attempts(identifier)
        _set_refresh_cookie(response, result["refresh_token"], get_settings())
        return result
    except UsernameAlreadyExistsError:
        await record_failed_attempt(identifier)
        raise generic_error
    except InvalidReferralCodeError as e:
        await record_failed_attempt(identifier)
        raise HTTPException(status.HTTP_400_BAD_REQUEST, str(e))
    except SelfReferralError as e:
        await record_failed_attempt(identifier)
        raise HTTPException(status.HTTP_400_BAD_REQUEST, str(e))
    except RuntimeError:
        await record_failed_attempt(identifier)
        raise HTTPException(500, "Internal server error")


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


@router.post(
    "/link-telegram",
    response_model=TelegramAuthResponse,
    summary="Привязка Telegram к существующему аккаунту",
    responses={409: {"description": "Telegram ID уже привязан к другому аккаунту"}},
)
@limiter.limit("5/minute")
async def link_telegram(
    req: TelegramLinkRequest,
    request: Request,
    response: Response,
    db: AsyncSession = Depends(get_db),
):
    client_ip = request.client.host if request.client else "unknown"
    identifier = f"{client_ip}:{req.username.lower().strip()}"

    if await is_locked_out(identifier):
        raise HTTPException(
            status.HTTP_429_TOO_MANY_REQUESTS,
            "Слишком много неудачных попыток. Попробуйте позже.",
        )

    svc = AuthService(db)
    try:
        result = await svc.link_telegram(req.initData, req.username, req.password)
        await reset_attempts(identifier)
        _set_refresh_cookie(response, result["refresh_token"], get_settings())
        return result
    except InvalidCredentialsError as e:
        await record_failed_attempt(identifier)
        raise HTTPException(status.HTTP_401_UNAUTHORIZED, str(e))
    except TelegramAlreadyLinkedError as e:
        await record_failed_attempt(identifier)
        raise HTTPException(status.HTTP_409_CONFLICT, str(e))
    except RuntimeError:
        await record_failed_attempt(identifier)
        raise HTTPException(500, "Internal server error")


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
    generic_error = HTTPException(
        status.HTTP_400_BAD_REQUEST,
        "Регистрация не удалась. Проверьте введённые данные.",
    )

    client_ip = request.client.host if request.client else "unknown"
    identifier = f"register:{client_ip}"

    if await is_locked_out(identifier):
        raise HTTPException(
            status.HTTP_429_TOO_MANY_REQUESTS,
            "Слишком много попыток регистрации. Попробуйте позже.",
        )

    if not req.username.strip():
        await record_failed_attempt(identifier)
        raise generic_error

    if not USERNAME_PATTERN.match(req.username.lower().strip()):
        await record_failed_attempt(identifier)
        raise generic_error

    password_error = validate_password_strength(req.password)
    if password_error:
        await record_failed_attempt(identifier)
        raise generic_error

    if not req.displayName.strip():
        await record_failed_attempt(identifier)
        raise generic_error

    svc = AuthService(db)
    try:
        result = await svc.register_telegram_user(req)
        await reset_attempts(identifier)
        _set_refresh_cookie(response, result["refresh_token"], get_settings())
        return result
    except ValueError as e:
        await record_failed_attempt(identifier)
        raise HTTPException(status.HTTP_400_BAD_REQUEST, str(e))
    except UsernameAlreadyExistsError as e:
        await record_failed_attempt(identifier)
        raise HTTPException(status.HTTP_409_CONFLICT, str(e))
    except TelegramAlreadyLinkedError as e:
        await record_failed_attempt(identifier)
        raise HTTPException(status.HTTP_409_CONFLICT, str(e))
    except InvalidReferralCodeError as e:
        await record_failed_attempt(identifier)
        raise HTTPException(status.HTTP_400_BAD_REQUEST, str(e))
    except SelfReferralError as e:
        await record_failed_attempt(identifier)
        raise HTTPException(status.HTTP_400_BAD_REQUEST, str(e))
    except InvalidCredentialsError as e:
        await record_failed_attempt(identifier)
        raise HTTPException(status.HTTP_401_UNAUTHORIZED, str(e))
    except RuntimeError:
        await record_failed_attempt(identifier)
        raise HTTPException(500, "Internal server error")


@router.post(
    "/refresh",
    response_model=LoginResponse,
    summary="Обновление access-токена по refresh-токену",
)
@limiter.limit("10/minute")
async def refresh(
    request: Request,
    response: Response,
    db: AsyncSession = Depends(get_db),
):
    refresh_token = request.cookies.get("refresh_token")
    if not refresh_token:
        # Mobile/Flutter clients store the refresh token locally and send it in
        # the Authorization header instead of a cookie.
        auth_header = request.headers.get("Authorization", "")
        if auth_header.startswith("Bearer "):
            refresh_token = auth_header.split(" ", 1)[1]
    if not refresh_token:
        raise HTTPException(
            status.HTTP_401_UNAUTHORIZED, "Отсутствует refresh-токен"
        )

    svc = AuthService(db)
    try:
        result = await svc.refresh_access_token(refresh_token)
    except HTTPException:
        raise
    except RuntimeError:
        raise HTTPException(500, "Internal server error")

    _set_refresh_cookie(response, result["refresh_token"], get_settings())
    return result


@router.get(
    "/washers",
    response_model=list[WasherPublicResponse],
    summary="Список мойщиков",
)
@limiter.limit("60/minute")
async def get_washers(
    request: Request,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    svc = AuthService(db)
    return await svc.get_washers()


@router.put(
    "/profile/{user_id}",
    response_model=UserResponse,
    summary="Обновление профиля",
)
@limiter.limit("10/minute")
async def update_profile(
    request: Request,
    user_id: int,
    req: UpdateProfileRequest,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
    token: str = Depends(oauth2_scheme),
):
    svc = AuthService(db)
    try:
        return await svc.update_profile(user_id, current_user, req, token)
    except UserNotFoundError as e:
        raise HTTPException(404, str(e))
    except ProfileAccessDeniedError as e:
        raise HTTPException(status.HTTP_403_FORBIDDEN, str(e))
    except ValueError as e:
        raise HTTPException(status.HTTP_400_BAD_REQUEST, detail=str(e))


@router.post(
    "/fcm-token",
    summary="Сохранение FCM-токена",
)
@limiter.limit("10/minute")
async def save_fcm_token(
    request: Request,
    req: FcmTokenRequest,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    logger.debug("save_fcm_token", user=current_user.username, req_user=req.username)
    svc = AuthService(db)
    try:
        return await svc.save_fcm_token(req, current_user)
    except FcmTokenAccessDeniedError as e:
        raise HTTPException(status.HTTP_403_FORBIDDEN, str(e))


@router.post("/avatar/{user_id}", response_model=UserResponse)
@limiter.limit("10/minute")
async def upload_avatar(
    request: Request,
    user_id: int,
    file: UploadFile = File(...),
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    if current_user.id != user_id and current_user.role != "admin":
        raise HTTPException(status.HTTP_403_FORBIDDEN, "Нет доступа к этому профилю")

    allowed = {"image/jpeg", "image/png", "image/webp"}
    if file.content_type not in allowed:
        raise HTTPException(400, "Допустимы только JPEG, PNG, WebP")

    allowed_exts = {"jpg", "jpeg", "png", "webp"}
    ext = file.filename.split(".")[-1].lower() if "." in file.filename else "jpg"
    if ext not in allowed_exts:
        raise HTTPException(
            400, "Недопустимое расширение файла. Допустимы: JPEG, PNG, WebP"
        )

    max_size = 5 * 1024 * 1024
    content = await file.read()
    if len(content) > max_size:
        raise HTTPException(400, "Файл слишком большой. Максимум 5 МБ")

    if content.startswith(b"\xff\xd8\xff"):
        detected = {"jpg", "jpeg"}
    elif content.startswith(b"\x89PNG\r\n\x1a\n"):
        detected = {"png"}
    elif (
        len(content) >= 12 and content.startswith(b"RIFF") and content[8:12] == b"WEBP"
    ):
        detected = {"webp"}
    else:
        raise HTTPException(400, "Файл не является валидным изображением")
    if ext not in detected:
        raise HTTPException(400, "Содержимое файла не соответствует расширению")

    # Validate image dimensions and integrity with Pillow
    try:
        img = await asyncio.to_thread(Image.open, BytesIO(content))
        width, height = await asyncio.to_thread(lambda: img.size)
        max_dimension = 4096
        if width > max_dimension or height > max_dimension:
            raise HTTPException(
                400, f"Image dimensions too large. Max {max_dimension}x{max_dimension}"
            )
        # Verify integrity (Pillow's verify requires a fresh image object)
        verify_img = await asyncio.to_thread(Image.open, BytesIO(content))
        await asyncio.to_thread(verify_img.verify)
    except HTTPException:
        raise
    except Exception:
        raise HTTPException(400, "Invalid image file")

    # Optimize: resize to max 512x512 and convert to WebP
    try:
        img = await asyncio.to_thread(Image.open, BytesIO(content))
        await asyncio.to_thread(img.thumbnail, (512, 512))
        buf = BytesIO()
        # Convert to RGB/RGBA for WebP compatibility
        if img.mode not in ("RGB", "RGBA"):
            img = await asyncio.to_thread(
                img.convert, "RGBA" if img.mode in ("P", "LA") else "RGB"
            )
        await asyncio.to_thread(img.save, buf, format="WEBP", quality=85)
        content = buf.getvalue()
        ext = "webp"
    except HTTPException:
        raise
    except Exception:
        raise HTTPException(400, "Failed to optimize image")

    import uuid

    filename = f"{uuid.uuid4().hex}.{ext}"
    filepath = os.path.join(UPLOAD_DIR, os.path.basename(filename))

    import aiofiles

    async with aiofiles.open(filepath, "wb") as buffer:
        await buffer.write(content)

    avatar_url = f"/uploads/avatars/{filename}"

    svc = AuthService(db)
    return await svc.update_avatar(user_id, current_user, avatar_url)


@router.get("/stats/{username}", response_model=UserStatsResponse)
@limiter.limit("60/minute")
async def get_user_stats(
    request: Request,
    username: str,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    svc = AuthService(db)
    try:
        return await svc.get_user_stats(username, current_user)
    except UserNotFoundError as e:
        raise HTTPException(404, str(e))
    except StatsAccessDeniedError as e:
        raise HTTPException(status.HTTP_403_FORBIDDEN, str(e))


@router.post("/logout")
@limiter.limit("10/minute")
async def logout(
    request: Request,
    response: Response,
    current_user: User = Depends(get_current_user),
    token: str = Depends(oauth2_scheme),
):
    """Invalidate the current JWT token by blacklisting its jti.

    Both a valid token (via oauth2_scheme) and a valid current user
    (via get_current_user) are required; missing/invalid credentials
    will raise 401 before reaching this handler.
    """
    refresh_token = request.cookies.get("refresh_token")
    svc = AuthService(db=None)
    await svc.logout(token, refresh_token)
    response.delete_cookie("refresh_token", path="/")
    return {"status": "ok"}
