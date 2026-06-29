import json
from datetime import date, datetime, time
from decimal import Decimal

from core.limiter import get_proxy_aware_remote_address
from models import AdminAuditLog


class _AuditJsonEncoder(json.JSONEncoder):
    def default(self, obj):
        if isinstance(obj, datetime):
            return obj.isoformat()
        if isinstance(obj, date):
            return obj.isoformat()
        if isinstance(obj, time):
            return obj.isoformat()
        if isinstance(obj, Decimal):
            return float(obj)
        return super().default(obj)


async def log_admin_action(
    db,
    current_user,
    action: str,
    entity_type: str,
    entity_id,
    old_values=None,
    new_values=None,
    request=None,
):
    log = AdminAuditLog(
        admin_id=current_user.id,
        admin_username=current_user.username,
        action=action,
        entity_type=entity_type,
        entity_id=str(entity_id),
        old_values=json.dumps(old_values or {}, cls=_AuditJsonEncoder),
        new_values=json.dumps(new_values or {}, cls=_AuditJsonEncoder),
        ip_address=get_proxy_aware_remote_address(request) if request else None,
        user_agent=request.headers.get("user-agent") if request else None,
        created_at=datetime.now(),
    )
    db.add(log)
