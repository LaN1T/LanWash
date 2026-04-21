from pydantic import BaseModel
from typing import Optional, List


# ─── Auth ────────────────────────────────────────────────────────────────────
class LoginRequest(BaseModel):
    username: str
    password: str


class RegisterRequest(BaseModel):
    username: str
    password: str
    displayName: str
    phone: str = ""
    carModel: str = ""
    carNumber: str = ""


class UserResponse(BaseModel):
    id: int
    username: str
    role: str
    displayName: str
    phone: str
    carModel: str
    carNumber: str
    createdAt: str
    isFavoriteAdmin: bool


class UpdateProfileRequest(BaseModel):
    displayName: Optional[str] = None
    phone: Optional[str] = None
    carModel: Optional[str] = None
    carNumber: Optional[str] = None
    newPassword: Optional[str] = None


class FcmTokenRequest(BaseModel):
    username: str
    token: str
    platform: str


# ─── Wash Types ──────────────────────────────────────────────────────────────
class WashTypeRequest(BaseModel):
    id: str
    code: str
    name: str
    description: str = ""
    basePrice: int = 0
    durationMinutes: int = 30
    sortOrder: int = 0
    includedExtraIds: List[str] = []


class WashTypeResponse(BaseModel):
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
    id: str
    clientName: str
    carModel: str
    carNumber: str
    dateTime: str
    washTypeId: str
    additionalServices: str = "[]"
    status: str = "scheduled"
    notes: str = ""
    isFavorite: bool = False
    ownerUsername: str = ""
    promoPrice: int = 0
    paidPrice: int = 0
    isModifiedByAdmin: bool = False
    originalPrice: int = 0
    assignedWasher: str = "[]"
    promoId: Optional[str] = None


class AppointmentResponse(BaseModel):
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
    originalPrice: int = 0
    assignedWasher: str = "[]"
    promoId: Optional[str] = None


class AssignWasherRequest(BaseModel):
    washerUsername: str


# ─── Services ────────────────────────────────────────────────────────────────
class ServiceRequest(BaseModel):
    id: str
    name: str
    description: str = ""
    price: int = 0
    durationMinutes: int = 30
    category: str = ""
    isFavorite: bool = False
    isFromApi: bool = False


class ServiceResponse(BaseModel):
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
    username: str
    action: str
    details: str = ""


class LogResponse(BaseModel):
    id: int
    username: str
    action: str
    details: str
    timestamp: str


# ─── Washer Notes ────────────────────────────────────────────────────────────
class NoteRequest(BaseModel):
    title: str
    message: str = ""
    category: str = "general"


class NoteResponse(BaseModel):
    id: int
    username: str
    title: str
    message: str
    category: str
    isRead: bool
    createdAt: str


# ─── Consumables ─────────────────────────────────────────────────────────────
class ConsumableRequest(BaseModel):
    name: str
    unit: str = ""

class ConsumableResponse(BaseModel):
    id: str
    name: str
    unit: str

class ServiceConsumableRequest(BaseModel):
    serviceId: str
    consumableId: str
    quantity_per_service: float

class ServiceConsumableResponse(BaseModel):
    serviceId: str
    consumableId: str
    quantity_per_service: float


# ─── Favorites ───────────────────────────────────────────────────────────────
class ToggleFavoriteRequest(BaseModel):
    username: str
    serviceId: str


class ToggleExtraFavoriteRequest(BaseModel):
    username: str
    serviceId: str
