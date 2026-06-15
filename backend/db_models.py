from sqlalchemy import (
    Boolean,
    JSON,
    Column,
    Float,
    ForeignKey,
    Index,
    Integer,
    String,
    UniqueConstraint,
)
from sqlalchemy.orm import declarative_base, declared_attr, validates

Base = declarative_base()

class User(Base):
    __tablename__ = 'users'
    __table_args__ = (
        Index('ix_users_role', 'role'),
    )
    id = Column(Integer, primary_key=True, autoincrement=True)
    username = Column(String, nullable=False, unique=True)
    passwordHash = Column(String, nullable=False)
    role = Column(String, nullable=False, default='client')
    displayName = Column(String, nullable=False)
    email = Column(String, nullable=True, default='')
    phone = Column(String, nullable=False, default='')
    carModel = Column(String, nullable=False, default='')
    carNumber = Column(String, nullable=False, default='')
    avatarUrl = Column(String, nullable=True, default='')
    createdAt = Column(String, nullable=False)
    isFavoriteAdmin = Column(Integer, nullable=False, default=0)
    passwordVersion = Column(Integer, nullable=False, default=1)
    telegramId = Column(String, nullable=True, unique=True)
    referralCode = Column(String, nullable=True, unique=True, index=True)

class Car(Base):
    __tablename__ = 'cars'
    id = Column(Integer, primary_key=True, autoincrement=True)
    userId = Column(Integer, ForeignKey('users.id', ondelete='CASCADE'), nullable=False)
    brand = Column(String, nullable=False, default='')
    model = Column(String, nullable=False, default='')
    number = Column(String, nullable=False, default='')
    isPrimary = Column(Boolean, nullable=False, default=False)

    @declared_attr.directive
    def __table_args__(cls):
        return (
            Index('ix_cars_user', 'userId'),
            Index('uq_user_primary_car', 'userId', unique=True, sqlite_where=(cls.isPrimary == True), postgresql_where=(cls.isPrimary == True)),
        )

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

class Subscription(Base):
    __tablename__ = 'subscriptions'
    __table_args__ = (
        Index('ix_subscriptions_user', 'userId'),
    )
    id = Column(Integer, primary_key=True, autoincrement=True)
    userId = Column(Integer, ForeignKey('users.id', ondelete='CASCADE'), nullable=False)
    name = Column(String, nullable=False)  # e.g., "Пакет 5 комплексных"
    type = Column(String, nullable=False)  # 'package' or 'monthly'
    washTypeId = Column(String, ForeignKey('wash_types.id'), nullable=False)
    totalWashes = Column(Integer, nullable=False)
    usedWashes = Column(Integer, nullable=False, default=0)
    validUntil = Column(String, nullable=True)  # ISO date for monthly; NULL for package
    createdAt = Column(String, nullable=False)


class Appointment(Base):
    __tablename__ = 'appointments'
    __table_args__ = (
        Index('ix_appointments_datetime', 'dateTime'),
        Index('ix_appointments_owner', 'ownerUsername'),
        Index('ix_appointments_status', 'status'),
        Index('ix_appointments_owner_status', 'ownerUsername', 'status'),
        Index('ix_appointments_user', 'userId'),
        Index('ix_appointments_wash_type', 'washTypeId'),
        Index('ix_appointments_promo', 'promoId'),
        Index('ix_appointments_subscription', 'subscriptionId'),
        Index('ix_appointments_box', 'box_index'),
        Index('ix_appointments_assigned_washer', 'assignedWasher'),
        Index('ix_appointments_hidden_admin', 'isHiddenFromAdmin'),
    )
    id = Column(String, primary_key=True)
    userId = Column(Integer, ForeignKey('users.id'), nullable=True)
    clientName = Column(String, nullable=False)
    carModel = Column(String, nullable=False)
    carNumber = Column(String, nullable=False)
    dateTime = Column(String, nullable=False)
    date = Column(String, nullable=False, index=True)
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
    isModifiedByWasher = Column(Integer, nullable=False, default=0)
    isSeenByClient = Column(Integer, nullable=False, default=1)
    originalPrice = Column(Integer, nullable=False, default=0)
    assignedWasher = Column(String, nullable=False, default='[]')
    promoId = Column(String, ForeignKey('promos.id'), nullable=True)
    subscriptionId = Column(Integer, ForeignKey('subscriptions.id'), nullable=True)
    box_index = Column(Integer, nullable=False, default=0)
    late_minutes = Column(Integer, nullable=False, default=0)
    cancel_reason = Column(String, nullable=False, default='')

    @validates('dateTime')
    def _set_date(self, key, value):
        self.date = value[:10] if value else ''
        return value

class Service(Base):
    __tablename__ = 'services'
    __table_args__ = (
        Index('ix_services_category', 'category'),
    )
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
    __table_args__ = (
        Index('ix_promos_wash_type', 'washTypeId'),
    )
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
    __table_args__ = (
        Index('ix_logs_username', 'username'),
        Index('ix_logs_timestamp', 'timestamp'),
    )
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
    __table_args__ = (
        Index('ix_washer_notes_username', 'username'),
    )
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
    currentStock = Column(Float, nullable=False, default=0.0)
    minStock = Column(Float, nullable=False, default=0.0)

class ServiceConsumable(Base):
    __tablename__ = 'service_consumables'
    serviceId = Column(String, ForeignKey('services.id'), primary_key=True)
    consumableId = Column(String, ForeignKey('consumables.id'), primary_key=True)
    quantity_per_service = Column(Float, nullable=False)

class ConsumableUsageLog(Base):
    __tablename__ = 'consumable_usage_log'
    __table_args__ = (
        Index('ix_usage_log_appointment', 'appointmentId'),
        Index('ix_usage_log_consumable', 'consumableId'),
        Index('ix_usage_log_timestamp', 'timestamp'),
    )
    id = Column(Integer, primary_key=True, autoincrement=True)
    appointmentId = Column(String, ForeignKey('appointments.id'), nullable=False)
    consumableId = Column(String, ForeignKey('consumables.id'), nullable=False)
    quantityUsed = Column(Float, nullable=False)
    timestamp = Column(String, nullable=False)

class ConsumableRefillLog(Base):
    __tablename__ = 'consumable_refill_log'
    __table_args__ = (
        Index('ix_refill_log_consumable', 'consumableId'),
        Index('ix_refill_log_timestamp', 'timestamp'),
    )
    id = Column(Integer, primary_key=True, autoincrement=True)
    consumableId = Column(String, ForeignKey('consumables.id'), nullable=False)
    amount = Column(Float, nullable=False)
    oldStock = Column(Float, nullable=False)
    newStock = Column(Float, nullable=False)
    refilledBy = Column(String, nullable=False, default='')
    timestamp = Column(String, nullable=False)

class Shift(Base):
    __tablename__ = 'shifts'
    __table_args__ = (
        Index('ix_shifts_user_date', 'userId', 'date'),
        Index('ix_shifts_date_status', 'date', 'status'),
    )
    id = Column(Integer, primary_key=True, autoincrement=True)
    userId = Column(Integer, ForeignKey('users.id'), nullable=False)
    date = Column(String, nullable=False)
    startTime = Column(String, nullable=False)
    endTime = Column(String, nullable=False)
    status = Column(String, nullable=False, default='confirmed')
    createdBy = Column(String, nullable=False)
    createdAt = Column(String, nullable=False)
    updatedAt = Column(String, nullable=False)

class ShiftTemplate(Base):
    __tablename__ = 'shift_templates'
    __table_args__ = (
        Index('ix_shift_templates_owner', 'ownerUsername'),
    )
    id = Column(Integer, primary_key=True, autoincrement=True)
    ownerUsername = Column(String, nullable=False)
    name = Column(String, nullable=False)
    isDefault = Column(Boolean, nullable=False, default=False)
    slots = Column(JSON, nullable=False, default=list)


class WasherAvailability(Base):
    __tablename__ = 'washer_availability'
    __table_args__ = (
        Index('ix_washer_availability_user_date', 'userId', 'date'),
        Index('ix_washer_availability_date', 'date'),
    )
    id = Column(Integer, primary_key=True, autoincrement=True)
    userId = Column(Integer, ForeignKey('users.id', ondelete='CASCADE'), nullable=False)
    date = Column(String, nullable=False)
    status = Column(String, nullable=False)
    updatedAt = Column(String, nullable=False)


class NotificationQueue(Base):
    __tablename__ = 'notification_queue'
    __table_args__ = (
        Index('ix_notification_queue_sent', 'sentAt'),
    )
    id = Column(Integer, primary_key=True, autoincrement=True)
    telegramId = Column(String, nullable=False)
    message = Column(String, nullable=False)
    createdAt = Column(String, nullable=False)
    sentAt = Column(String, nullable=True)

class Review(Base):
    __tablename__ = 'reviews'
    __table_args__ = (
        UniqueConstraint('userId', 'appointmentId', name='uq_review_user_appointment'),
        Index('ix_reviews_user', 'userId'),
        Index('ix_reviews_appointment', 'appointmentId'),
        Index('ix_reviews_published', 'isPublished'),
    )
    id = Column(Integer, primary_key=True, autoincrement=True)
    userId = Column(Integer, ForeignKey('users.id'), nullable=False)
    userName = Column(String, nullable=False)
    rating = Column(Integer, nullable=False, default=5)
    comment = Column(String, nullable=False, default='')
    isPublished = Column(Integer, nullable=False, default=0)
    createdAt = Column(String, nullable=False)
    appointmentId = Column(String, ForeignKey('appointments.id'), nullable=True)

class Referral(Base):
    __tablename__ = 'referrals'
    __table_args__ = (
        UniqueConstraint('referrerId', 'referredId', name='uq_referral_referrer_referred'),
        Index('ix_referrals_referrer', 'referrerId'),
        Index('ix_referrals_referred', 'referredId'),
    )
    id = Column(Integer, primary_key=True, autoincrement=True)
    referrerId = Column(Integer, ForeignKey('users.id'), nullable=False)
    referredId = Column(Integer, ForeignKey('users.id'), nullable=False)
    rewardClaimed = Column(Boolean, nullable=False, default=False)
    createdAt = Column(String, nullable=False)

class Tip(Base):
    __tablename__ = 'tips'
    __table_args__ = (
        UniqueConstraint('appointmentId', 'washerUsername', name='uq_tip_appointment_washer'),
        Index('ix_tips_appointment', 'appointmentId'),
        Index('ix_tips_washer', 'washerUsername'),
    )
    id = Column(Integer, primary_key=True, autoincrement=True)
    appointmentId = Column(String, ForeignKey('appointments.id'), nullable=False)
    washerUsername = Column(String, nullable=False)
    amount = Column(Integer, nullable=False)
    method = Column(String, nullable=False, default='sbp')
    status = Column(String, nullable=False, default='pending')
    createdAt = Column(String, nullable=False)


class SupportChat(Base):
    __tablename__ = 'support_chats'
    __table_args__ = (
        Index('ix_support_chats_user', 'userId'),
        Index('ix_support_chats_admin', 'assignedAdminId'),
        Index('ix_support_chats_status', 'status'),
        Index('ix_support_chats_last_message', 'lastMessageAt'),
    )
    id = Column(Integer, primary_key=True, autoincrement=True)
    userId = Column(Integer, ForeignKey('users.id', ondelete='CASCADE'), nullable=False)
    status = Column(String, nullable=False, default='open')
    assignedAdminId = Column(Integer, ForeignKey('users.id'), nullable=True)
    unreadByUser = Column(Integer, nullable=False, default=0)
    unreadByAdmin = Column(Integer, nullable=False, default=0)
    lastMessageAt = Column(String, nullable=True)
    createdAt = Column(String, nullable=False)
    updatedAt = Column(String, nullable=False)


class SupportMessage(Base):
    __tablename__ = 'support_messages'
    __table_args__ = (
        Index('ix_support_messages_chat', 'chatId'),
        Index('ix_support_messages_sender', 'senderId'),
        Index('ix_support_messages_created', 'createdAt'),
    )
    id = Column(Integer, primary_key=True, autoincrement=True)
    chatId = Column(Integer, ForeignKey('support_chats.id', ondelete='CASCADE'), nullable=False)
    senderRole = Column(String, nullable=False)
    senderId = Column(Integer, ForeignKey('users.id'), nullable=True)
    content = Column(String, nullable=False)
    isAiDraft = Column(Integer, nullable=False, default=0)
    createdAt = Column(String, nullable=False)


class AdminAuditLog(Base):
    __tablename__ = 'admin_audit_logs'
    __table_args__ = (
        Index('ix_admin_audit_logs_admin', 'admin_id'),
        Index('ix_admin_audit_logs_entity', 'entity_type', 'entity_id'),
        Index('ix_admin_audit_logs_created', 'created_at'),
    )
    id = Column(Integer, primary_key=True, autoincrement=True)
    admin_id = Column(Integer, ForeignKey('users.id'), nullable=False)
    admin_username = Column(String, nullable=False)
    action = Column(String, nullable=False)
    entity_type = Column(String, nullable=False)
    entity_id = Column(String, nullable=False)
    old_values = Column(String, nullable=True, default='{}')
    new_values = Column(String, nullable=True, default='{}')
    ip_address = Column(String, nullable=True)
    user_agent = Column(String, nullable=True)
    created_at = Column(String, nullable=False)
