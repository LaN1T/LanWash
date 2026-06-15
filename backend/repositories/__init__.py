from repositories.base import BaseRepository

from repositories.user import UserRepository
from repositories.car import CarRepository
from repositories.wash_type import WashTypeRepository
from repositories.wash_type_included_extra import WashTypeIncludedExtraRepository
from repositories.wash_type_consumable import WashTypeConsumableRepository
from repositories.subscription import SubscriptionRepository
from repositories.appointment import AppointmentRepository
from repositories.service import ServiceRepository
from repositories.promo import PromoRepository
from repositories.promo_included_extra import PromoIncludedExtraRepository
from repositories.log_entry import LogEntryRepository
from repositories.service_favorite import ServiceFavoriteRepository
from repositories.extra_favorite import ExtraFavoriteRepository
from repositories.washer_note import WasherNoteRepository
from repositories.deleted_notification import DeletedNotificationRepository
from repositories.fcm_token import FcmTokenRepository
from repositories.consumable import ConsumableRepository
from repositories.service_consumable import ServiceConsumableRepository
from repositories.consumable_usage_log import ConsumableUsageLogRepository
from repositories.consumable_refill_log import ConsumableRefillLogRepository
from repositories.shift import ShiftRepository
from repositories.shift_template import ShiftTemplateRepository
from repositories.washer_availability import WasherAvailabilityRepository
from repositories.notification_queue import NotificationQueueRepository
from repositories.review import ReviewRepository
from repositories.referral import ReferralRepository
from repositories.tip import TipRepository
from repositories.support_chat import SupportChatRepository
from repositories.support_message import SupportMessageRepository
from repositories.admin_audit_log import AdminAuditLogRepository

__all__ = [
    "BaseRepository",
    "UserRepository",
    "CarRepository",
    "WashTypeRepository",
    "WashTypeIncludedExtraRepository",
    "WashTypeConsumableRepository",
    "SubscriptionRepository",
    "AppointmentRepository",
    "ServiceRepository",
    "PromoRepository",
    "PromoIncludedExtraRepository",
    "LogEntryRepository",
    "ServiceFavoriteRepository",
    "ExtraFavoriteRepository",
    "WasherNoteRepository",
    "DeletedNotificationRepository",
    "FcmTokenRepository",
    "ConsumableRepository",
    "ServiceConsumableRepository",
    "ConsumableUsageLogRepository",
    "ConsumableRefillLogRepository",
    "ShiftRepository",
    "ShiftTemplateRepository",
    "WasherAvailabilityRepository",
    "NotificationQueueRepository",
    "ReviewRepository",
    "ReferralRepository",
    "TipRepository",
    "SupportChatRepository",
    "SupportMessageRepository",
    "AdminAuditLogRepository",
]
