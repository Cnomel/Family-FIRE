"""WebSocket handler for real-time notifications.

Uses Redis Pub/Sub for message distribution across multiple workers.
"""

import asyncio
import json
from typing import Any

from fastapi import WebSocket, WebSocketDisconnect
from starlette.websockets import WebSocketState

from app.common.logging import get_logger
from app.common.security import decode_token
from app.config import get_settings

logger = get_logger("websocket")
settings = get_settings()


class ConnectionManager:
    """Manages WebSocket connections per user."""

    def __init__(self):
        # user_id -> list of WebSocket connections
        self._connections: dict[str, list[WebSocket]] = {}

    async def connect(self, user_id: str, websocket: WebSocket) -> None:
        await websocket.accept()
        if user_id not in self._connections:
            self._connections[user_id] = []
        self._connections[user_id].append(websocket)
        logger.info("ws_connected", user_id=user_id, total=len(self._connections[user_id]))

    def disconnect(self, user_id: str, websocket: WebSocket) -> None:
        if user_id in self._connections:
            self._connections[user_id] = [
                ws for ws in self._connections[user_id] if ws != websocket
            ]
            if not self._connections[user_id]:
                del self._connections[user_id]
        logger.info("ws_disconnected", user_id=user_id)

    async def send_to_user(self, user_id: str, message: dict[str, Any]) -> None:
        """Send message to all connections of a specific user."""
        connections = self._connections.get(user_id, [])
        disconnected = []
        for ws in connections:
            try:
                if ws.client_state == WebSocketState.CONNECTED:
                    await ws.send_json(message)
                else:
                    disconnected.append(ws)
            except Exception:
                disconnected.append(ws)

        # Clean up disconnected
        for ws in disconnected:
            self.disconnect(user_id, ws)

    async def broadcast(self, message: dict[str, Any]) -> None:
        """Send message to all connected users."""
        for user_id in list(self._connections.keys()):
            await self.send_to_user(user_id, message)

    @property
    def active_connections(self) -> int:
        return sum(len(conns) for conns in self._connections.values())

    @property
    def active_users(self) -> int:
        return len(self._connections)


# Global connection manager
manager = ConnectionManager()


async def handle_websocket(websocket: WebSocket, token: str | None = None) -> None:
    """Handle a WebSocket connection.

    Protocol:
    1. Client connects with ?token=<access_token>
    2. Server validates token
    3. Server sends {"type": "connected", "user_id": "..."}
    4. Server pushes notifications as {"type": "notification", "data": {...}}
    5. Client can send {"type": "ping"} and server responds {"type": "pong"}
    """
    # Validate token
    if not token:
        await websocket.close(code=4001, reason="Missing token")
        return

    payload = decode_token(token)
    if not payload or payload.get("type") != "access":
        await websocket.close(code=4001, reason="Invalid token")
        return

    user_id = payload.get("sub")
    if not user_id:
        await websocket.close(code=4001, reason="Invalid token payload")
        return

    # Accept connection
    await manager.connect(user_id, websocket)

    try:
        # Send connected confirmation
        await websocket.send_json({
            "type": "connected",
            "user_id": user_id,
        })

        # Listen for messages
        while True:
            data = await websocket.receive_text()

            try:
                message = json.loads(data)
                msg_type = message.get("type")

                if msg_type == "ping":
                    await websocket.send_json({"type": "pong"})
                elif msg_type == "mark_read":
                    # Client can mark notifications as read via WebSocket
                    notification_id = message.get("notification_id")
                    if notification_id:
                        await _handle_mark_read(notification_id, user_id)
                else:
                    logger.warning("unknown_ws_message", type=msg_type, user_id=user_id)

            except json.JSONDecodeError:
                logger.warning("invalid_ws_message", user_id=user_id)

    except WebSocketDisconnect:
        manager.disconnect(user_id, websocket)
    except Exception as e:
        logger.error("ws_error", user_id=user_id, error=str(e))
        manager.disconnect(user_id, websocket)


async def _handle_mark_read(notification_id: str, user_id: str) -> None:
    """Handle mark-as-read from WebSocket."""
    try:
        from app.database import async_session_factory
        from app.notifications.service import mark_read

        async with async_session_factory() as session:
            await mark_read(session, notification_id, user_id)
            await session.commit()
    except Exception as e:
        logger.error("ws_mark_read_error", error=str(e))


async def publish_notification(user_id: str, notification: dict[str, Any]) -> None:
    """Publish a notification to a user via WebSocket.

    This is called from notification service when a new notification is created.
    """
    await manager.send_to_user(user_id, {
        "type": "notification",
        "data": notification,
    })


async def start_redis_listener() -> None:
    """Listen for notifications from Redis Pub/Sub and forward to WebSocket clients.

    This enables notifications to work across multiple backend instances.
    """
    import redis.asyncio as aioredis

    redis = aioredis.from_url(settings.REDIS_URL)
    pubsub = redis.pubsub()

    await pubsub.subscribe("notifications")

    logger.info("redis_listener_started")

    try:
        async for message in pubsub.listen():
            if message["type"] == "message":
                try:
                    data = json.loads(message["data"])
                    user_id = data.get("user_id")
                    notification = data.get("notification")
                    if user_id and notification:
                        await publish_notification(user_id, notification)
                except Exception as e:
                    logger.error("redis_listener_error", error=str(e))
    except asyncio.CancelledError:
        logger.info("redis_listener_stopped")
    finally:
        await pubsub.unsubscribe("notifications")
        await redis.close()
