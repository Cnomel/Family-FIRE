"""User model with username + email login support."""

from datetime import datetime

from sqlmodel import Field, SQLModel

from app.common.models import TimestampMixin, utcnow
from app.common.security import Role


class User(TimestampMixin, table=True):
    """User account model.

    Supports login via username OR email.
    """
    __tablename__ = "users"

    id: str | None = Field(default=None, primary_key=True, max_length=36)
    username: str = Field(max_length=20, unique=True, index=True, description="用户名")
    email: str = Field(max_length=255, unique=True, index=True, description="邮箱")
    hashed_password: str = Field(max_length=255, description="密码哈希")
    full_name: str = Field(max_length=100, description="姓名")
    avatar_url: str | None = Field(default=None, max_length=500, description="头像URL")
    role: Role = Field(default=Role.MEMBER, description="角色")
    is_active: bool = Field(default=True, description="是否启用")
    is_verified: bool = Field(default=False, description="是否验证邮箱")
    last_login_at: datetime | None = Field(default=None, description="最后登录时间")
    login_attempts: int = Field(default=0, description="登录失败次数")
    locked_until: datetime | None = Field(default=None, description="锁定截止时间")


class SystemSettings(SQLModel, table=True):
    """System-wide configuration settings."""
    __tablename__ = "system_settings"

    id: str | None = Field(default=None, primary_key=True, max_length=36)
    key: str = Field(max_length=100, unique=True, index=True, description="配置键")
    value: str = Field(max_length=500, description="配置值")
    description: str | None = Field(default=None, max_length=500, description="描述")
    updated_at: datetime = Field(default_factory=utcnow, description="更新时间")
