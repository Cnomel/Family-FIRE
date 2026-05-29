"""User management schemas."""

from datetime import datetime

from pydantic import BaseModel, Field

from app.common.security import Role


class UpdateUserRoleRequest(BaseModel):
    """Admin: update user role."""
    role: Role = Field(description="新角色")


class UpdateUserStatusRequest(BaseModel):
    """Admin: enable/disable user."""
    is_active: bool = Field(description="是否启用")


class UserDetailResponse(BaseModel):
    """Detailed user information for admin."""
    id: str
    username: str
    email: str
    full_name: str
    avatar_url: str | None = None
    role: Role
    is_active: bool
    is_verified: bool
    login_attempts: int
    locked_until: datetime | None = None
    created_at: datetime
    updated_at: datetime
    last_login_at: datetime | None = None
