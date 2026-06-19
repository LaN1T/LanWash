import asyncio
import json
from datetime import date, datetime, time
from decimal import Decimal
from typing import Dict, List, Set, Tuple

import structlog
from fastapi import WebSocket, WebSocketDisconnect

logger = structlog.get_logger()


class _WebSocketJsonEncoder(json.JSONEncoder):
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


class _WebSocketManager:
    """In-memory registry for support chat WebSocket connections."""

    def __init__(self) -> None:
        self._connections: Dict[int, List[Tuple[WebSocket, int]]] = {}

    def connect(self, chat_id: int, websocket: WebSocket, user_id: int) -> None:
        self._connections.setdefault(chat_id, []).append((websocket, user_id))

    def disconnect(self, chat_id: int, websocket: WebSocket) -> None:
        conns = self._connections.get(chat_id, [])
        for item in list(conns):
            if item[0] is websocket:
                conns.remove(item)
                break
        if not conns:
            self._connections.pop(chat_id, None)

    async def broadcast(self, chat_id: int, message: dict) -> None:
        payload = json.dumps(message, cls=_WebSocketJsonEncoder)
        conns = list(self._connections.get(chat_id, []))

        async def _send(ws: WebSocket, user_id: int) -> None:
            try:
                await asyncio.wait_for(ws.send_text(payload), timeout=5.0)
            except (WebSocketDisconnect, RuntimeError) as e:
                logger.warning(
                    "websocket_stale_removed",
                    chat_id=chat_id,
                    user_id=user_id,
                    error=str(e),
                )
                self.disconnect(chat_id, ws)
            except asyncio.TimeoutError:
                logger.warning(
                    "websocket_send_timeout",
                    chat_id=chat_id,
                    user_id=user_id,
                )
                self.disconnect(chat_id, ws)
            except Exception as e:
                logger.warning(
                    "support_broadcast_failed",
                    chat_id=chat_id,
                    user_id=user_id,
                    error=str(e),
                )

        if conns:
            await asyncio.gather(
                *(_send(ws, uid) for ws, uid in conns), return_exceptions=True
            )

    def connected_user_ids(self, chat_id: int) -> Set[int]:
        return {uid for _, uid in self._connections.get(chat_id, [])}


_manager = _WebSocketManager()


# Public API
def connect(chat_id: int, websocket: WebSocket, user_id: int) -> None:
    _manager.connect(chat_id, websocket, user_id)


def disconnect(chat_id: int, websocket: WebSocket) -> None:
    _manager.disconnect(chat_id, websocket)


async def broadcast(chat_id: int, message: dict) -> None:
    await _manager.broadcast(chat_id, message)


def connected_user_ids(chat_id: int) -> Set[int]:
    return _manager.connected_user_ids(chat_id)
