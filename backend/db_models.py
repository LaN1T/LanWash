from sqlalchemy import Column, Integer, String, Float, ForeignKey, Boolean
from sqlalchemy.orm import declarative_base, relationship

Base = declarative_base()

class User(Base):
    __tablename__ = 'users'
    id = Column(Integer, primary_key=True, autoincrement=True)
    username = Column(String, nullable=False, unique=True)
    passwordHash = Column(String, nullable=False)
    role = Column(String, nullable=False, default='client')
    displayName = Column(String, nullable=False)
    phone = Column(String, nullable=False, default='')
    carModel = Column(String, nullable=False, default='')
    carNumber = Column(String, nullable=False, default='')
    createdAt = Column(String, nullable=False)
    isFavoriteAdmin = Column(Integer, nullable=False, default=0)

class WashType(Base):
    __tablename__ = 'wash_types'
    id = Column(String, primary_key=True)           # w1..w4
    code = Column(String, nullable=False, unique=True)  # express/basic/complex/premium
    name = Column(String, nullable=False)
    description = Column(String, nullable=False, default='')
    basePrice = Column(Integer, nullable=False, default=0)
    durationMinutes = Column(Integer, nullable=False, default=30)
    sortOrder = Column(Integer, nullable=False, default=0)

class WashTypeIncludedExtra(Base):
    __tablename__ = 'wash_type_included_extras'
    washTypeId = Column(String, ForeignKey('wash_types.id', ondelete='CASCADE'), primary_key=True)
    extraServiceId = Column(String, ForeignKey('services.id', ondelete='CASCADE'), primary_key=True)

class WashTypeConsumable(Base):
    __tablename__ = 'wash_type_consumables'
    washTypeId = Column(String, ForeignKey('wash_types.id', ondelete='CASCADE'), primary_key=True)
    consumableId = Column(String, ForeignKey('consumables.id', ondelete='CASCADE'), primary_key=True)
    quantity_per_service = Column(Float, nullable=False)

class Appointment(Base):
    __tablename__ = 'appointments'
    id = Column(String, primary_key=True)
    userId = Column(Integer, ForeignKey('users.id'), nullable=True)
    clientName = Column(String, nullable=False)
    carModel = Column(String, nullable=False)
    carNumber = Column(String, nullable=False)
    dateTime = Column(String, nullable=False)
    washTypeId = Column(String, ForeignKey('wash_types.id'), nullable=False)
    additionalServices = Column(String, nullable=False, default='[]')  # JSON-массив id
    status = Column(String, nullable=False, default='scheduled')
    notes = Column(String, nullable=False, default='')
    isFavorite = Column(Integer, nullable=False, default=0)
    ownerUsername = Column(String, nullable=False, default='')
    isHiddenFromAdmin = Column(Boolean, nullable=False, default=False)
    promoPrice = Column(Integer, nullable=False, default=0)
    paidPrice = Column(Integer, nullable=False, default=0)
    isModifiedByAdmin = Column(Integer, nullable=False, default=0)
    originalPrice = Column(Integer, nullable=False, default=0)
    assignedWasher = Column(String, nullable=False, default='[]')
    promoId = Column(String, ForeignKey('promos.id'), nullable=True)
    box_index = Column(Integer, nullable=False, default=0)

class Service(Base):
    __tablename__ = 'services'
    id = Column(String, primary_key=True)
    name = Column(String, nullable=False)
    description = Column(String, nullable=False, default='')
    price = Column(Integer, nullable=False, default=0)
    durationMinutes = Column(Integer, nullable=False, default=30)
    category = Column(String, nullable=False, default='')
    isFavorite = Column(Integer, nullable=False, default=0)
    isFromApi = Column(Integer, nullable=False, default=0)
    updatedAt = Column(String, nullable=False)

class Promo(Base):
    __tablename__ = 'promos'
    id = Column(String, primary_key=True)
    washTypeId = Column(String, ForeignKey('wash_types.id'), nullable=False)
    name = Column(String, nullable=False)
    description = Column(String, nullable=False, default='')
    price = Column(Integer, nullable=False, default=0)       # 0 = использовать basePrice типа мойки со скидкой
    discountPercent = Column(Integer, nullable=False, default=0)
    duration = Column(Integer, nullable=False, default=30)
    weekendOnly = Column(Boolean, nullable=False, default=False)
    fetchedAt = Column(String, nullable=False)

class PromoIncludedExtra(Base):
    __tablename__ = 'promo_included_extras'
    promoId = Column(String, ForeignKey('promos.id', ondelete='CASCADE'), primary_key=True)
    extraServiceId = Column(String, ForeignKey('services.id', ondelete='CASCADE'), primary_key=True)

class LogEntry(Base):
    __tablename__ = 'logs'
    id = Column(Integer, primary_key=True, autoincrement=True)
    username = Column(String, nullable=False)
    action = Column(String, nullable=False)
    details = Column(String, nullable=False, default='')
    timestamp = Column(String, nullable=False)

class ServiceFavorite(Base):
    __tablename__ = 'service_favorites'
    username = Column(String, primary_key=True)
    serviceId = Column(String, primary_key=True)

class ExtraFavorite(Base):
    __tablename__ = 'extra_favorites'
    username = Column(String, primary_key=True)
    serviceId = Column(String, primary_key=True)

class WasherNote(Base):
    __tablename__ = 'washer_notes'
    id = Column(Integer, primary_key=True, autoincrement=True)
    username = Column(String, nullable=False)
    title = Column(String, nullable=False)
    message = Column(String, nullable=False, default='')
    category = Column(String, nullable=False, default='general')
    isRead = Column(Integer, nullable=False, default=0)
    createdAt = Column(String, nullable=False)

class DeletedNotification(Base):
    __tablename__ = 'deleted_notifications'
    id = Column(Integer, primary_key=True, autoincrement=True)
    username = Column(String, nullable=False)
    createdAt = Column(String, nullable=False)

class FcmToken(Base):
    __tablename__ = 'fcm_tokens'
    username = Column(String, primary_key=True)
    token = Column(String, nullable=False)
    platform = Column(String, nullable=False) # android, ios, web
    updatedAt = Column(String, nullable=False)

class Consumable(Base):
    __tablename__ = 'consumables'
    id = Column(String, primary_key=True)
    name = Column(String, nullable=False, unique=True)
    unit = Column(String, nullable=False, default='')

class ServiceConsumable(Base):
    __tablename__ = 'service_consumables'
    serviceId = Column(String, ForeignKey('services.id'), primary_key=True)
    consumableId = Column(String, ForeignKey('consumables.id'), primary_key=True)
    quantity_per_service = Column(Float, nullable=False)

class ConsumableUsageLog(Base):
    __tablename__ = 'consumable_usage_log'
    id = Column(Integer, primary_key=True, autoincrement=True)
    appointmentId = Column(String, ForeignKey('appointments.id'), nullable=False)
    consumableId = Column(String, ForeignKey('consumables.id'), nullable=False)
    quantityUsed = Column(Float, nullable=False)
    timestamp = Column(String, nullable=False)
