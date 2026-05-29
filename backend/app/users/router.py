"""User management API router (Admin only)."""

from fastapi import APIRouter, Depends
from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.auth.dependencies import AdminUser
from app.auth.schemas import UserListResponse, UserResponse
from app.common.exceptions import NotFoundError
from app.common.logging import get_logger
from app.common.schemas import MessageResponse, SuccessResponse
from app.database import get_db
from app.users.models import User
from app.users.schemas import UpdateUserRoleRequest, UpdateUserStatusRequest, UserDetailResponse

logger = get_logger("users_router")
router = APIRouter()


@router.get(
    "",
    response_model=SuccessResponse[UserListResponse],
    summary="用户列表",
    description="获取所有用户列表（Admin）",
)
async def list_users(
    admin: AdminUser,
    db: AsyncSession = Depends(get_db),
    page: int = 1,
    page_size: int = 20,
):
    # Count total
    count_stmt = select(func.count()).select_from(User)
    total_result = await db.execute(count_stmt)
    total = total_result.scalar()

    # Get users with pagination
    offset = (page - 1) * page_size
    stmt = select(User).order_by(User.created_at.desc()).offset(offset).limit(page_size)
    result = await db.execute(stmt)
    users = result.scalars().all()

    user_responses = [
        UserResponse(
            id=u.id,
            username=u.username,
            email=u.email,
            full_name=u.full_name,
            avatar_url=u.avatar_url,
            role=u.role,
            is_active=u.is_active,
            is_verified=u.is_verified,
            created_at=u.created_at,
            last_login_at=u.last_login_at,
        )
        for u in users
    ]

    return SuccessResponse(
        data=UserListResponse(users=user_responses, total=total),
    )


@router.get(
    "/{user_id}",
    response_model=SuccessResponse[UserDetailResponse],
    summary="用户详情",
    description="获取指定用户的详细信息（Admin）",
)
async def get_user(
    user_id: str,
    admin: AdminUser,
    db: AsyncSession = Depends(get_db),
):
    stmt = select(User).where(User.id == user_id)
    result = await db.execute(stmt)
    user = result.scalar_one_or_none()

    if not user:
        raise NotFoundError("用户", user_id)

    return SuccessResponse(
        data=UserDetailResponse(
            id=user.id,
            username=user.username,
            email=user.email,
            full_name=user.full_name,
            avatar_url=user.avatar_url,
            role=user.role,
            is_active=user.is_active,
            is_verified=user.is_verified,
            login_attempts=user.login_attempts,
            locked_until=user.locked_until,
            created_at=user.created_at,
            updated_at=user.updated_at,
            last_login_at=user.last_login_at,
        )
    )


@router.put(
    "/{user_id}/role",
    response_model=MessageResponse,
    summary="修改用户角色",
    description="修改指定用户的角色（Admin）",
)
async def update_user_role(
    user_id: str,
    data: UpdateUserRoleRequest,
    admin: AdminUser,
    db: AsyncSession = Depends(get_db),
):
    stmt = select(User).where(User.id == user_id)
    result = await db.execute(stmt)
    user = result.scalar_one_or_none()

    if not user:
        raise NotFoundError("用户", user_id)

    user.role = data.role
    await db.flush()

    logger.info("user_role_updated", admin_id=admin.id, user_id=user_id, new_role=data.role)
    return MessageResponse(message=f"用户角色已更新为 {data.role.value}")


@router.put(
    "/{user_id}/status",
    response_model=MessageResponse,
    summary="启用/禁用用户",
    description="启用或禁用指定用户（Admin）",
)
async def update_user_status(
    user_id: str,
    data: UpdateUserStatusRequest,
    admin: AdminUser,
    db: AsyncSession = Depends(get_db),
):
    stmt = select(User).where(User.id == user_id)
    result = await db.execute(stmt)
    user = result.scalar_one_or_none()

    if not user:
        raise NotFoundError("用户", user_id)

    user.is_active = data.is_active
    await db.flush()

    status_text = "启用" if data.is_active else "禁用"
    logger.info("user_status_updated", admin_id=admin.id, user_id=user_id, is_active=data.is_active)
    return MessageResponse(message=f"用户已{status_text}")
