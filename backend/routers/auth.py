import os
import re
from fastapi import APIRouter, HTTPException, Depends, status, Request, UploadFile, File
from sqlalchemy.ext.asyncio import AsyncSession
from database import get_db
from models import (
    LoginRequest, RegisterRequest, UserResponse, UpdateProfileRequest,
    FcmTokenRequest, LoginResponse, UserStatsResponse,
    TelegramAuthRequest, TelegramLinkRequest, TelegramAuthResponse
)
from db_models import User
from services.auth_service import (
    get_current_user,
    validate_password_strength,
    oauth2_scheme,
    AuthService,
    InvalidCredentialsError,
    UserNotFoundError,
    UsernameAlreadyExistsError,
    InvalidReferralCodeError,
    SelfReferralError,
    ProfileAccessDeniedError,
    StatsAccessDeniedError,
    FcmTokenAccessDeniedError,
)
from core.limiter import limiter
import structlog

logger = structlog.get_logger()

USERNAME_PATTERN = re.compile(r'^[a-z0-9_]{3,30}$')

UPLOAD_DIR = os.path.join(os.path.dirname(os.path.dirname(__file__)), "uploads", "avatars")
os.makedirs(UPLOAD_DIR, exist_ok=True)

router = APIRouter(
    prefix="/api/auth",
    tags=["auth"],
)


@router.post(
    "/login",
    response_model=LoginResponse,
    summary="Вход в систему",
)
@limiter.limit("10/minute")
async def login(req: LoginRequest, request: Request, db: AsyncSession = Depends(get_db)):
    svc = AuthService(db)
    try:
        return await svc.login(req.username.lower().strip(), req.password)
    except InvalidCredentialsError as e:
        raise HTTPException(status.HTTP_401_UNAUTHORIZED, str(e))


@router.post(
    "/register",
    response_model=LoginResponse,
    summary="Регистрация нового пользователя",
)
@limiter.limit("5/minute")
async def register(req: RegisterRequest, request: Request, db: AsyncSession = Depends(get_db)):
    generic_error = HTTPException(status.HTTP_400_BAD_REQUEST, "Регистрация не удалась. Проверьте введённые данные.")

    if not req.username.strip():
        raise generic_error

    if not USERNAME_PATTERN.match(req.username.lower().strip()):
        raise generic_error

    password_error = validate_password_strength(req.password)
    if password_error:
        raise generic_error

    if not req.displayName.strip():
        raise generic_error

    svc = AuthService(db)
    try:
        return await svc.register(req)
    except UsernameAlreadyExistsError:
        raise generic_error
    except InvalidReferralCodeError as e:
        raise HTTPException(status.HTTP_400_BAD_REQUEST, str(e))
    except SelfReferralError as e:
        raise HTTPException(status.HTTP_400_BAD_REQUEST, str(e))
    except RuntimeError as e:
        raise HTTPException(500, str(e))


@router.post(
    "/telegram",
    response_model=TelegramAuthResponse,
    summary="Авторизация через Telegram Mini App",
)
@limiter.limit("10/minute")
async def telegram_auth(
    req: TelegramAuthRequest,
    request: Request,
    db: AsyncSession = Depends(get_db),
):
    svc = AuthService(db)
    try:
        return await svc.telegram_auth(req.initData)
    except InvalidCredentialsError as e:
        raise HTTPException(status.HTTP_401_UNAUTHORIZED, str(e))
    except RuntimeError as e:
        raise HTTPException(500, str(e))


@router.post(
    "/link-telegram",
    response_model=TelegramAuthResponse,
    summary="Привязка Telegram к существующему аккаунту",
)
@limiter.limit("5/minute")
async def link_telegram(
    req: TelegramLinkRequest,
    request: Request,
    db: AsyncSession = Depends(get_db),
):
    svc = AuthService(db)
    try:
        return await svc.link_telegram(req.username, req.password, req.telegramId)
    except InvalidCredentialsError as e:
        raise HTTPException(status.HTTP_401_UNAUTHORIZED, str(e))


@router.get(
    "/washers",
    response_model=list[UserResponse],
    summary="Список мойщиков",
)
@limiter.limit("60/minute")
async def get_washers(request: Request, db: AsyncSession = Depends(get_db), current_user: User = Depends(get_current_user)):
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
        raise HTTPException(400, "Недопустимое расширение файла. Допустимы: JPEG, PNG, WebP")

    max_size = 5 * 1024 * 1024
    content = await file.read()
    if len(content) > max_size:
        raise HTTPException(400, "Файл слишком большой. Максимум 5 МБ")

    if content.startswith(b'\xff\xd8\xff'):
        detected = {"jpg", "jpeg"}
    elif content.startswith(b'\x89PNG\r\n\x1a\n'):
        detected = {"png"}
    elif len(content) >= 12 and content.startswith(b'RIFF') and content[8:12] == b'WEBP':
        detected = {"webp"}
    else:
        raise HTTPException(400, "Файл не является валидным изображением")
    if ext not in detected:
        raise HTTPException(400, "Содержимое файла не соответствует расширению")

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
    current_user: User = Depends(get_current_user),
):
    """Invalidate the current JWT token by blacklisting its jti."""
    auth_header = request.headers.get("Authorization", "")
    if auth_header.startswith("Bearer "):
        token = auth_header[7:]
        svc = AuthService(db=None)
        await svc.logout(token)
    return {"status": "ok"}
