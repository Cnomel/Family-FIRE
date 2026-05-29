"""Notification API router."""

from fastapi import APIRouter, Depends
from sqlalchemy.ext.asyncio import AsyncSession

from app.auth.dependencies import CurrentUser
from app.common.schemas import MessageResponse, SuccessResponse
from app.database import get_db
from app.notifications import service as notif_service

router = APIRouter()


@router.get(
    "",
    response_model=SuccessResponse[dict],
    summary="通知列表",
    description="获取当前用户的通知列表",
)
async def list_notifications(
    current_user: CurrentUser,
    db: AsyncSession = Depends(get_db),
    is_read: bool | None = None,
    page: int = 1,
    page_size: int = 20,
):
    result = await notif_service.list_notifications(
        db, current_user.id, is_read=is_read, page=page, page_size=page_size,
    )
    return SuccessResponse(data=result)


@router.get(
    "/unread-count",
    response_model=SuccessResponse[int],
    summary="未读计数",
    description="获取未读通知数量",
)
async def get_unread_count(
    current_user: CurrentUser,
    db: AsyncSession = Depends(get_db),
):
    count = await notif_service.get_unread_count(db, current_user.id)
    return SuccessResponse(data=count)


@router.put(
    "/{notification_id}/read",
    response_model=MessageResponse,
    summary="标记已读",
    description="标记单条通知为已读",
)
async def mark_read(
    notification_id: str,
    current_user: CurrentUser,
    db: AsyncSession = Depends(get_db),
):
    await notif_service.mark_read(db, notification_id, current_user.id)
    return MessageResponse(message="已标记为已读")


@router.put(
    "/read-all",
    response_model=MessageResponse,
    summary="全部已读",
    description="标记所有通知为已读",
)
async def mark_all_read(
    current_user: CurrentUser,
    db: AsyncSession = Depends(get_db),
):
    count = await notif_service.mark_all_read(db, current_user.id)
    return MessageResponse(message=f"已标记{count}条通知为已读")


@router.get(
    "/settings",
    response_model=SuccessResponse[list],
    summary="通知偏好",
    description="获取通知偏好设置",
)
async def get_preferences(
    current_user: CurrentUser,
    db: AsyncSession = Depends(get_db),
):
    prefs = await notif_service.get_preferences(db, current_user.id)
    return SuccessResponse(data=prefs)


@router.put(
    "/settings",
    response_model=MessageResponse,
    summary="更新偏好",
    description="更新通知偏好",
)
async def update_preference(
    data: dict,
    current_user: CurrentUser,
    db: AsyncSession = Depends(get_db),
):
    await notif_service.update_preference(
        db, current_user.id,
        notification_type=data.get("type", ""),
        enabled=data.get("enabled", True),
    )
    return MessageResponse(message="偏好已更新")
