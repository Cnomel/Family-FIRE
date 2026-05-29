"""Authentication schemas for request/response validation."""

from datetime import datetime

from pydantic import BaseModel, EmailStr, Field

from app.common.security import Role

# ============================================================
# Request Schemas
# ============================================================

class RegisterRequest(BaseModel):
    """User registration request."""
    username: str = Field(
        min_length=3, max_length=20,
        pattern=r"^[a-zA-Z0-9_\u4e00-\u9fff]+$",
        description="用户名（3-20位，支持字母、数字、下划线、中文）",
    )
    email: EmailStr = Field(description="邮箱")
    password: str = Field(min_length=8, max_length=128, description="密码")
    full_name: str = Field(min_length=1, max_length=100, description="姓名")


class LoginRequest(BaseModel):
    """Login request. Supports username OR email."""
    identifier: str = Field(description="用户名或邮箱")
    password: str = Field(description="密码")


class RefreshTokenRequest(BaseModel):
    """Token refresh request."""
    refresh_token: str = Field(description="刷新Token")


class ForgotPasswordRequest(BaseModel):
    """Forgot password request."""
    email: EmailStr = Field(description="邮箱")


class ResetPasswordRequest(BaseModel):
    """Reset password request."""
    token: str = Field(description="重置Token")
    new_password: str = Field(min_length=8, max_length=128, description="新密码")


class ChangePasswordRequest(BaseModel):
    """Change password request."""
    old_password: str = Field(description="当前密码")
    new_password: str = Field(min_length=8, max_length=128, description="新密码")


class UpdateProfileRequest(BaseModel):
    """Update profile request."""
    full_name: str | None = Field(default=None, min_length=1, max_length=100, description="姓名")
    avatar_url: str | None = Field(default=None, max_length=500, description="头像URL")


# ============================================================
# Response Schemas
# ============================================================

class TokenResponse(BaseModel):
    """Token response after successful login/refresh."""
    access_token: str
    refresh_token: str
    token_type: str = "bearer"
    expires_in: int = Field(description="Access token过期时间(秒)")


class UserResponse(BaseModel):
    """User information response."""
    id: str
    username: str
    email: str
    full_name: str
    avatar_url: str | None = None
    role: Role
    is_active: bool
    is_verified: bool
    created_at: datetime
    last_login_at: datetime | None = None


class UserListResponse(BaseModel):
    """User list response for admin."""
    users: list[UserResponse]
    total: int
