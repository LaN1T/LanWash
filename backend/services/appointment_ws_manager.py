import asyncio
import json
from typing import Dict, List, Optional, Set, Tuple

import structlog
from fastapi import WebSocket, WebSocketDisconnect
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from models.models import Appointment, User
from schemas import AppointmentResponse
from services.ws_json import WebSocketJsonEncoder

logger = structlog.get_logger()


class AppointmentWebSocketManager:
    """In-memory registry for /ws/appointments connections."""

    def __init__(self) -> None:
        self._connections: Dict[int, List[Tuple[WebSocket, str]]] = {}
        self._lock = asyncio.Lock()

    async def connect(
        self, user_id: int, role: str, websocket: WebSocket
    ) -> None:
        async with self._lock:
            conns = self._connections.setdefault(user_id, [])
            # Avoid duplicate registration of the same socket object under
            # concurrent connects for the same user.
            if not any(item[0] is websocket for item in conns):
                conns.append((websocket, role))

    async def disconnect(self, user_id: int, websocket: WebSocket) -> None:
        async with self._lock:
            conns = self._connections.get(user_id, [])
            for item in list(conns):
                if item[0] is websocket:
                    conns.remove(item)
                    break
            if not conns:
                self._connections.pop(user_id, None)

    async def notify_appointment(
        self, db: AsyncSession, appointment: Appointment, event: str
    ) -> None:
        payload = {
            "type": "appointment_updated",
            "event": event,
            "appointment": AppointmentResponse.model_validate(appointment).model_dump(),
        }
        message = json.dumps(payload, cls=WebSocketJsonEncoder)

        recipients = await self._resolve_recipients(db, appointment)
        if not recipients:
            return

        targets: List[Tuple[WebSocket, int]] = []
        async with self._lock:
            seen: Set[int] = set()
            for user_id, role in recipients:
                if role == "admin":
                    for uid, conns in self._connections.items():
                        for ws, r in conns:
                            if r == "admin" and id(ws) not in seen:
                                seen.add(id(ws))
                                targets.append((ws, uid))
                elif user_id is not None:
                    for ws, _ in self._connections.get(user_id, []):
                        if id(ws) not in seen:
                            seen.add(id(ws))
                            targets.append((ws, user_id))

        if targets:
            await asyncio.gather(
                *(
                    self._send_to_socket(ws, uid, message, event, appointment.id)
                    for ws, uid in targets
                ),
                return_exceptions=True,
            )

    async def _send_to_socket(
        self,
        ws: WebSocket,
        uid: int,
        message: str,
        event: str,
        appointment_id: int,
    ) -> None:
        try:
            await asyncio.wait_for(ws.send_text(message), timeout=5.0)
        except (WebSocketDisconnect, RuntimeError):
            await self.disconnect(uid, ws)
        except asyncio.TimeoutError:
            await self.disconnect(uid, ws)
        except Exception as e:
            logger.warning(
                "appointment_broadcast_failed",
                user_id=uid,
                event=event,
                appointment_id=appointment_id,
                error=repr(e),
            )

    async def _resolve_recipients(
        self, db: AsyncSession, appointment: Appointment
    ) -> List[Tuple[Optional[int], str]]:
        """Return (user_id, role) tuples. (None, 'admin') means all admin sockets."""
        recipients: List[Tuple[Optional[int], str]] = []

        if appointment.ownerUsername:
            owner_res = await db.execute(
                select(User).where(User.username == appointment.ownerUsername)
            )
            owner = owner_res.scalar_one_or_none()
            if owner:
                recipients.append((owner.id, owner.role))

        try:
            assigned = (
                json.loads(appointment.assignedWasher)
                if appointment.assignedWasher
                else []
            )
        except json.JSONDecodeError:
            assigned = []

        if assigned:
            washer_res = await db.execute(
                select(User.id, User.role).where(User.username.in_(assigned))
            )
            for uid, role in washer_res.all():
                recipients.append((uid, role))

        recipients.append((None, "admin"))
        return recipients


appointment_ws_manager = AppointmentWebSocketManager()
