import re
from pydantic import BaseModel, Field, ConfigDict, field_validator
import json
from typing import Optional, List, Literal


# ─── Auth ────────────────────────────────────────────────────────────────────
class Token(BaseModel):
    access_token: str
    token_type: str


class LoginResponse(BaseModel):
    user: "UserResponse"
    access_token: str
    token_type: str


class LoginRequest(BaseModel):
    username: str = Field(..., min_length=3, max_length=50, description="Логин пользователя")
    password: str = Field(..., min_length=8, max_length=128, description="Пароль")


class RegisterRequest(BaseModel):
    username: str = Field(..., min_length=3, max_length=50, description="Уникальный логин (латиница и цифры)")
    password: str = Field(..., min_length=8, max_length=128, description="Пароль, минимум 4 символа")
    displayName: str = Field(..., min_length=1, max_length=100, description="Отображаемое имя")
    email: str = Field(default="", max_length=100, description="Email адрес")
    phone: str = Field(default="", max_length=20, description="Номер телефона")
    carModel: str = Field(default="", max_length=50, description="Марка и модель автомобиля")
    carNumber: str = Field(default="", max_length=50, description="Госномер автомобиля")
    referralCode: Optional[str] = Field(default=None, max_length=20, description="Реферальный код пригласившего")

    @field_validator('email')
    @classmethod
    def validate_email(cls, v: str) -> str:
        if not v:
            return v
        if not re.match(r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$', v):
            raise ValueError('Некорректный email адрес')
        return v.lower()


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
    createdAt: str
    isFavoriteAdmin: bool
    passwordVersion: int = 1
    referralCode: Optional[str] = None


class UpdateProfileRequest(BaseModel):
    displayName: Optional[str] = Field(default=None, max_length=100)
    phone: Optional[str] = Field(default=None, max_length=20)
    carModel: Optional[str] = Field(default=None, max_length=50)
    carNumber: Optional[str] = Field(default=None, max_length=20)
    avatarUrl: Optional[str] = Field(default=None, max_length=5000)
    currentPassword: Optional[str] = Field(default=None, min_length=8, max_length=128)
    newPassword: Optional[str] = Field(default=None, min_length=8, max_length=128)


class UserStatsResponse(BaseModel):
    totalAppointments: int
    totalSpent: int
    favoriteWashType: str
    level: str
    levelProgress: int  # процент до следующего уровня
    points: int


class ReferralResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: int
    referrerId: int
    referredId: int
    referredName: str
    rewardClaimed: bool
    createdAt: str


class ReferralStatsResponse(BaseModel):
    referralCode: str
    totalReferrals: int
    claimedRewards: int
    pendingRewards: int


class FcmTokenRequest(BaseModel):
    username: str = Field(..., min_length=3, max_length=50)
    token: str = Field(..., min_length=1, max_length=1000)
    platform: str = Field(..., max_length=20)


# ─── Wash Types ──────────────────────────────────────────────────────────────
class WashTypeRequest(BaseModel):
    id: str = Field(..., max_length=36)
    code: str = Field(..., max_length=20)
    name: str = Field(..., max_length=100)
    description: str = Field(default="", max_length=500)
    basePrice: int = Field(default=0, ge=0)
    durationMinutes: int = Field(default=30, ge=0)
    sortOrder: int = Field(default=0, ge=0)
    includedExtraIds: List[str] = []


class WashTypeResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: str
    code: str
    name: str
    description: str
    basePrice: int
    durationMinutes: int
    sortOrder: int
    includedExtraIds: List[str] = []


# ─── Subscriptions ───────────────────────────────────────────────────────────
class SubscriptionCreateRequest(BaseModel):
    userId: int = Field(..., ge=1)
    name: str = Field(..., max_length=200)
    type: Literal["package", "monthly"] = "package"
    washTypeId: str = Field(..., max_length=36)
    totalWashes: int = Field(..., ge=1)
    validUntil: Optional[str] = Field(default=None, max_length=30)


class SubscriptionResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: int
    userId: int
    name: str
    type: str
    washTypeId: str
    totalWashes: int
    usedWashes: int
    validUntil: Optional[str] = None
    createdAt: str


class SubscriptionStatsResponse(BaseModel):
    activeCount: int
    totalSaved: int


# ─── Appointments ────────────────────────────────────────────────────────────
class AppointmentRequest(BaseModel):
    id: str = Field(..., max_length=36, description="Уникальный ID записи")
    clientName: str = Field(..., max_length=100, description="Имя клиента")
    carModel: str = Field(..., max_length=50, description="Марка и модель авто")
    carNumber: str = Field(..., max_length=20, description="Госномер")
    carId: Optional[int] = Field(default=None, description="ID автомобиля из гаража")
    dateTime: str = Field(..., max_length=30, description="Дата и время в ISO формате")
    washTypeId: str = Field(..., max_length=36, description="ID типа мойки")
    additionalServices: str = Field(default="[]", max_length=1000, description="JSON-массив ID доп. услуг")

    @field_validator("additionalServices")
    @classmethod
    def validate_json(cls, v):
        if v is None or v == "":
            return "[]"
        try:
            json.loads(v)
        except Exception:
            raise ValueError("additionalServices must be valid JSON")
        return v

    status: Literal["scheduled", "in_progress", "completed", "cancelled"] = "scheduled"
    notes: str = Field(default="", max_length=1000, description="Заметки")
    isFavorite: bool = False
    ownerUsername: str = Field(default="", max_length=50, description="Логин владельца записи")
    promoPrice: int = Field(default=0, ge=0, description="Акционная цена")
    paidPrice: int = Field(default=0, ge=0, description="Фактически оплаченная сумма")
    isModifiedByAdmin: bool = False
    isModifiedByWasher: bool = False
    isSeenByClient: bool = True
    originalPrice: int = Field(default=0, ge=0)
    assignedWasher: str = Field(default="[]", max_length=500)
    promoId: Optional[str] = Field(default=None, max_length=36)
    subscriptionId: Optional[int] = Field(default=None)
    box_index: int = Field(default=0, ge=0)
    late_minutes: int = Field(default=0, ge=0)
    cancel_reason: str = Field(default="", max_length=500)


class AppointmentResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: str
    userId: Optional[int] = None
    clientName: str
    carModel: str
    carNumber: str
    dateTime: str
    washTypeId: str
    additionalServices: str
    status: str
    notes: str
    isFavorite: bool
    ownerUsername: str
    promoPrice: int
    paidPrice: int
    isModifiedByAdmin: bool = False
    isModifiedByWasher: bool = False
    isSeenByClient: bool = True
    originalPrice: int = 0
    assignedWasher: str = "[]"
    promoId: Optional[str] = None
    subscriptionId: Optional[int] = None
    box_index: int = 0
    late_minutes: int = 0
    cancel_reason: str = ""


class AssignWasherRequest(BaseModel):
    washerUsername: str = Field(..., min_length=3, max_length=50)


class LateReportRequest(BaseModel):
    minutes: int = Field(..., ge=15, le=60, description="Минуты опоздания")

    @field_validator("minutes")
    @classmethod
    def validate_minutes(cls, v):
        if v not in (15, 30, 60):
            raise ValueError("minutes must be one of: 15, 30, 60")
        return v


class CancelReasonRequest(BaseModel):
    reason: str = Field(..., min_length=1, max_length=500, description="Причина отмены")


class QrScanRequest(BaseModel):
    qrData: str = Field(..., min_length=1, max_length=36, description="ID записи из QR-кода")


# ─── Services ────────────────────────────────────────────────────────────────
class ServiceRequest(BaseModel):
    id: str = Field(..., max_length=36)
    name: str = Field(..., max_length=100)
    description: str = Field(default="", max_length=500)
    price: int = Field(default=0, ge=0)
    durationMinutes: int = Field(default=30, ge=0)
    category: str = Field(default="", max_length=50)
    isFavorite: bool = False
    isFromApi: bool = False


class ServiceResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: str
    name: str
    description: str
    price: int
    durationMinutes: int
    category: str
    isFavorite: bool
    isFromApi: bool


# ─── Promos ──────────────────────────────────────────────────────────────────
class PromoResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: str
    washTypeId: str
    name: str
    description: str
    price: int
    discountPercent: int
    duration: int
    weekendOnly: bool
    includedExtraIds: List[str] = []


# ─── Logs ────────────────────────────────────────────────────────────────────
class LogRequest(BaseModel):
    username: str = Field(..., min_length=3, max_length=50)
    action: str = Field(..., max_length=100)
    details: str = Field(default="", max_length=1000)


class LogQueryParams(BaseModel):
    limit: int = Field(default=200, ge=1, le=1000)


class LogResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: int
    username: str
    action: str
    details: str
    timestamp: str


# ─── Washer Notes ────────────────────────────────────────────────────────────
class NoteRequest(BaseModel):
    title: str = Field(..., max_length=200)
    message: str = Field(default="", max_length=2000)
    category: str = Field(default="general", max_length=50)


class NoteResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: int
    username: str
    title: str
    message: str
    category: str
    isRead: bool
    createdAt: str


# ─── Consumables ─────────────────────────────────────────────────────────────
class ConsumableRequest(BaseModel):
    name: str = Field(..., max_length=100)
    unit: str = Field(default="", max_length=20)

class ConsumableResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: str
    name: str
    unit: str
    currentStock: float = 0.0
    minStock: float = 0.0


class RefillRequest(BaseModel):
    amount: float = Field(..., ge=0)


class ServiceConsumableRequest(BaseModel):
    serviceId: str = Field(..., max_length=36)
    consumableId: str = Field(..., max_length=36)
    quantity_per_service: float = Field(..., ge=0)

class ServiceConsumableResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    serviceId: str
    consumableId: str
    quantity_per_service: float


# ─── Shifts ──────────────────────────────────────────────────────────────────
class ShiftRequest(BaseModel):
    userId: int = Field(..., ge=1)
    date: str = Field(..., max_length=10, description="YYYY-MM-DD")
    startTime: str = Field(..., max_length=5, description="HH:MM")
    endTime: str = Field(..., max_length=5, description="HH:MM")


class ShiftResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: int
    userId: int
    date: str
    startTime: str
    endTime: str
    status: str
    createdBy: str
    createdAt: str
    updatedAt: str


# ─── Reviews ─────────────────────────────────────────────────────────────────
class ReviewCreateRequest(BaseModel):
    userId: int = Field(..., ge=1)
    rating: int = Field(default=5, ge=1, le=5)
    comment: str = Field(default="", max_length=2000)
    appointmentId: Optional[str] = None


class ReviewResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: int
    userId: int
    userName: str
    rating: int
    comment: str
    isPublished: bool
    createdAt: str
    appointmentId: Optional[str] = None


class ReviewModerateRequest(BaseModel):
    isPublished: bool


# ─── Favorites ───────────────────────────────────────────────────────────────
class ToggleFavoriteRequest(BaseModel):
    username: str = Field(..., min_length=3, max_length=50)
    serviceId: str = Field(..., max_length=36)


class ToggleExtraFavoriteRequest(BaseModel):
    username: str = Field(..., min_length=3, max_length=50)
    serviceId: str = Field(..., max_length=36)


# ─── Telegram Auth ───────────────────────────────────────────────────────────
class TelegramAuthRequest(BaseModel):
    initData: str = Field(..., min_length=10, description="Telegram WebApp initData string")


class TelegramLinkRequest(BaseModel):
    username: str = Field(..., min_length=3, max_length=50)
    password: str = Field(..., min_length=8, max_length=128)
    telegramId: str = Field(..., min_length=1, max_length=64)


class TelegramAuthResponse(BaseModel):
    user: UserResponse
    access_token: str
    token_type: str


# ─── Cars ────────────────────────────────────────────────────────────────────
class CarRequest(BaseModel):
    brand: str = Field(..., max_length=50, description="Марка автомобиля")
    model: str = Field(..., max_length=50, description="Модель автомобиля")
    number: Optional[str] = Field(default=None, max_length=20, description="Госномер")
    isPrimary: Optional[bool] = Field(default=None, description="Основной автомобиль")


class CarResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: int
    userId: int
    brand: str
    model: str
    number: str
    isPrimary: bool


# ─── Tips ────────────────────────────────────────────────────────────────────
class TipCreateRequest(BaseModel):
    appointmentId: str = Field(..., max_length=36, description="ID записи")
    amount: int = Field(..., ge=50, le=50000, description="Сумма чаевых в рублях")
    method: Literal["sbp", "cash", "app"] = Field(default="sbp", description="Способ оплаты")


class TipResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: int
    appointmentId: str
    washerUsername: str
    amount: int
    method: str
    status: str
    createdAt: str
    sbpUrl: Optional[str] = None


class TipStatsResponse(BaseModel):
    totalTips: int
    totalAmount: int
    pendingAmount: int


class TipWithAppointmentResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: int
    appointmentId: str
    washerUsername: str
    amount: int
    method: str
    status: str
    createdAt: str
    appointment: Optional[AppointmentResponse] = None


# ─── Admin Dashboard ─────────────────────────────────────────────────────────
class DailyBreakdown(BaseModel):
    date: str
    revenue: int
    appointments: int
    completed: int


class TopWasher(BaseModel):
    name: str
    revenue: int
    appointments: int


class TopClient(BaseModel):
    name: str
    visits: int
    totalSpent: int


class DashboardResponse(BaseModel):
    fromDate: str
    toDate: str
    totalRevenue: int
    totalAppointments: int
    completedAppointments: int
    cancelledAppointments: int
    averageCheck: float
    newClients: int
    returningClients: int
    averageRating: float
    dailyBreakdown: List[DailyBreakdown]
    topWashers: List[TopWasher]
    topClients: List[TopClient]


# ─── Bulk Operations ─────────────────────────────────────────────────────────
class BulkAssignWasherRequest(BaseModel):
    appointmentIds: List[str] = Field(..., min_length=1, max_length=100)
    washerUsername: str = Field(..., min_length=1, max_length=50)


class BulkCancelRequest(BaseModel):
    appointmentIds: List[str] = Field(..., min_length=1, max_length=100)
    reason: str = Field(default="", max_length=500)


class BulkUpdateStatusRequest(BaseModel):
    appointmentIds: List[str] = Field(..., min_length=1, max_length=100)
    status: str = Field(..., pattern=r'^(scheduled|in_progress|completed|cancelled)$')


class BulkResult(BaseModel):
    processed: int
    failed: int
    errors: List[str] = []


# ─── User Search ─────────────────────────────────────────────────────────────
class UserListItem(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: int
    username: str
    role: str
    displayName: str
    phone: str
    carModel: str
    carNumber: str
    avatarUrl: str = ""
    createdAt: str
    referralCode: Optional[str] = None


class UserListResponse(BaseModel):
    items: List[UserListItem]
    total: int


# ─── Workload Forecast ───────────────────────────────────────────────────────
class ForecastSlot(BaseModel):
    date: str
    hour: int = Field(..., ge=0, le=23)
    predicted_load: float = Field(..., ge=0)
    capacity: int = Field(..., ge=1)
    utilization_pct: float


class ForecastResponse(BaseModel):
    items: List[ForecastSlot]
    generated_at: str


class ConsumableForecastItem(BaseModel):
    consumable_id: str
    name: str
    unit: str
    current_stock: float
    min_stock: float
    avg_daily_usage: float
    planned_usage_7d: float
    days_until_low: float | None
    days_until_empty: float | None
    recommended_order_amount: float
    status: Literal["critical", "warning", "ok"]


class InventoryForecastResponse(BaseModel):
    items: list[ConsumableForecastItem]
    generated_at: str


# ─── Support Chat ────────────────────────────────────────────────────────────

class SupportMessageCreateRequest(BaseModel):
    content: str = Field(..., min_length=1, max_length=2000, description="Текст сообщения")
    isAiDraft: bool = Field(default=False, description="Сообщение отправлено на основе черновика ИИ")


class SupportMessageResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: int
    chatId: int
    senderRole: str
    senderId: Optional[int] = None
    senderName: Optional[str] = None
    content: str
    isAiDraft: bool
    createdAt: str


class SupportChatCreateRequest(BaseModel):
    firstMessage: str = Field(default="", max_length=2000, description="Первое сообщение в чате поддержки")


class SupportChatResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: int
    userId: int
    userName: str
    userPhone: Optional[str] = None
    status: str
    assignedAdminId: Optional[int] = None
    assignedAdminName: Optional[str] = None
    unreadByUser: int
    unreadByAdmin: int
    lastMessageAt: Optional[str] = None
    lastMessagePreview: Optional[str] = None
    createdAt: str


class AiDraftResponse(BaseModel):
    draft: Optional[str] = None
