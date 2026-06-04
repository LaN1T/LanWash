from pydantic import BaseModel, Field, ConfigDict
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
    phone: str = Field(default="", max_length=20, description="Номер телефона")
    carModel: str = Field(default="", max_length=50, description="Марка и модель автомобиля")
    carNumber: str = Field(default="", max_length=50, description="Госномер автомобиля")


class UserResponse(BaseModel):
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
    isFavoriteAdmin: bool


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


# ─── Appointments ────────────────────────────────────────────────────────────
class AppointmentRequest(BaseModel):
    id: str = Field(..., max_length=36, description="Уникальный ID записи")
    clientName: str = Field(..., max_length=100, description="Имя клиента")
    carModel: str = Field(..., max_length=50, description="Марка и модель авто")
    carNumber: str = Field(..., max_length=20, description="Госномер")
    dateTime: str = Field(..., max_length=30, description="Дата и время в ISO формате")
    washTypeId: str = Field(..., max_length=36, description="ID типа мойки")
    additionalServices: str = Field(default="[]", max_length=1000, description="JSON-массив ID доп. услуг")
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
    box_index: int = Field(default=0, ge=0)


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
    box_index: int = 0


class AssignWasherRequest(BaseModel):
    washerUsername: str = Field(..., min_length=3, max_length=50)


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
    userName: str = Field(..., min_length=1, max_length=100)
    rating: int = Field(default=5, ge=1, le=5)
    comment: str = Field(default="", max_length=2000)


class ReviewResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: int
    userId: int
    userName: str
    rating: int
    comment: str
    isPublished: bool
    createdAt: str


class ReviewModerateRequest(BaseModel):
    isPublished: bool


# ─── Favorites ───────────────────────────────────────────────────────────────
class ToggleFavoriteRequest(BaseModel):
    username: str = Field(..., min_length=3, max_length=50)
    serviceId: str = Field(..., max_length=36)


class ToggleExtraFavoriteRequest(BaseModel):
    username: str = Field(..., min_length=3, max_length=50)
    serviceId: str = Field(..., max_length=36)
