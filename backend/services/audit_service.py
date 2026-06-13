import json
from datetime import datetime

from db_models import AdminAuditLog


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
        old_values=json.dumps(old_values or {}),
        new_values=json.dumps(new_values or {}),
        ip_address=request.client.host if request and request.client else None,
        user_agent=request.headers.get("user-agent") if request else None,
        created_at=datetime.now().isoformat(),
    )
    db.add(log)
