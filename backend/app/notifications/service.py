"""Notification service."""

import uuid
from datetime import UTC, datetime
from typing import Any

from sqlalchemy import and_, func, select, update
from sqlalchemy.ext.asyncio import AsyncSession

from app.common.exceptions import NotFoundError
from app.common.logging import get_logger
from app.families.models import FamilyMember
from app.notifications.models import Notification, NotificationPreference

logger = get_logger("notification_service")


async def create_notification(
    db: AsyncSession,
    user_id: str,
    title: str,
    message: str,
    notification_type: str,
    family_id: str | None = None,
    data: dict | None = None,
) -> None:
    """Create a notification for a user."""
    notif = Notification(
        id=str(uuid.uuid4()),
        user_id=user_id,
        family_id=family_id,
        type=notification_type,
        title=title,
        message=message,
        data=data,
        is_read=False,
    )
    db.add(notif)
    await db.flush()


async def notify_family_members(
    db: AsyncSession,
    family_id: str,
    exclude_user_id: str,
    title: str,
    message: str,
    notification_type: str,
    data: dict | None = None,
) -> None:
    """Notify all family members except the excluded user."""
    stmt = select(FamilyMember.user_id).where(
        FamilyMember.family_id == family_id,
        FamilyMember.user_id != exclude_user_id,
    )
    result = await db.execute(stmt)
    user_ids = result.scalars().all()

    for uid in user_ids:
        # Check preference
        pref_stmt = select(NotificationPreference).where(
            NotificationPreference.user_id == uid,
            NotificationPreference.notification_type == notification_type,
        )
        pref_result = await db.execute(pref_stmt)
        pref = pref_result.scalar_one_or_none()

        if pref and not pref.enabled:
            continue

        await create_notification(
            db, uid, title, message, notification_type,
            family_id=family_id, data=data,
        )


async def list_notifications(
    db: AsyncSession,
    user_id: str,
    is_read: bool | None = None,
    page: int = 1,
    page_size: int = 20,
) -> dict[str, Any]:
    """List notifications for a user."""
    conditions = [Notification.user_id == user_id]
    if is_read is not None:
        conditions.append(Notification.is_read == is_read)

    count_stmt = select(func.count()).select_from(Notification).where(and_(*conditions))
    count_result = await db.execute(count_stmt)
    total = count_result.scalar()

    offset = (page - 1) * page_size
    stmt = (
        select(Notification)
        .where(and_(*conditions))
        .order_by(Notification.created_at.desc())
        .offset(offset)
        .limit(page_size)
    )
    result = await db.execute(stmt)
    notifications = result.scalars().all()

    return {
        "notifications": [
            {
                "id": n.id,
                "type": n.type,
                "title": n.title,
                "message": n.message,
                "data": n.data,
                "is_read": n.is_read,
                "created_at": n.created_at.isoformat(),
            }
            for n in notifications
        ],
        "total": total,
        "page": page,
        "page_size": page_size,
    }


async def get_unread_count(db: AsyncSession, user_id: str) -> int:
    """Get count of unread notifications."""
    stmt = (
        select(func.count())
        .select_from(Notification)
        .where(Notification.user_id == user_id, Notification.is_read.is_(False))
    )
    result = await db.execute(stmt)
    return result.scalar()


async def mark_read(db: AsyncSession, notification_id: str, user_id: str) -> None:
    """Mark a notification as read."""
    stmt = select(Notification).where(
        Notification.id == notification_id,
        Notification.user_id == user_id,
    )
    result = await db.execute(stmt)
    notif = result.scalar_one_or_none()

    if not notif:
        raise NotFoundError("通知", notification_id)

    notif.is_read = True
    notif.read_at = datetime.utcnow()
    await db.flush()


async def mark_all_read(db: AsyncSession, user_id: str) -> int:
    """Mark all notifications as read. Returns count of updated."""
    stmt = (
        update(Notification)
        .where(Notification.user_id == user_id, Notification.is_read.is_(False))
        .values(is_read=True, read_at=datetime.utcnow())
    )
    result = await db.execute(stmt)
    await db.flush()
    return result.rowcount


async def get_preferences(db: AsyncSession, user_id: str) -> list[dict]:
    """Get user notification preferences."""
    stmt = select(NotificationPreference).where(NotificationPreference.user_id == user_id)
    result = await db.execute(stmt)
    prefs = result.scalars().all()

    return [
        {"type": p.notification_type, "enabled": p.enabled}
        for p in prefs
    ]


async def update_preference(
    db: AsyncSession, user_id: str, notification_type: str, enabled: bool
) -> None:
    """Update a notification preference."""
    stmt = select(NotificationPreference).where(
        NotificationPreference.user_id == user_id,
        NotificationPreference.notification_type == notification_type,
    )
    result = await db.execute(stmt)
    pref = result.scalar_one_or_none()

    if pref:
        pref.enabled = enabled
    else:
        pref = NotificationPreference(
            id=str(uuid.uuid4()),
            user_id=user_id,
            notification_type=notification_type,
            enabled=enabled,
        )
        db.add(pref)

    await db.flush()
