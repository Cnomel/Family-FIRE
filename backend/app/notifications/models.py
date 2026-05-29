"""Notification models."""

from datetime import datetime

from sqlalchemy import Column
from sqlalchemy.dialects.postgresql import JSON
from sqlmodel import Field

from app.common.models import TimestampMixin


class Notification(TimestampMixin, table=True):
    """Notification records for family collaboration."""
    __tablename__ = "notifications"

    id: str | None = Field(default=None, primary_key=True, max_length=36)
    user_id: str = Field(max_length=36, index=True, description="接收者用户ID")
    family_id: str | None = Field(default=None, max_length=36, description="关联家庭ID")

    type: str = Field(max_length=30, description="类型: asset_added/asset_consumed/asset_duplicate/asset_expiring/consumable_low/family_invite/family_joined/price_alert/system")
    title: str = Field(max_length=200, description="标题")
    message: str = Field(max_length=1000, description="内容")
    data: dict | None = Field(default=None, sa_column=Column(JSON), description="附加数据")

    is_read: bool = Field(default=False, description="是否已读")
    read_at: datetime | None = Field(default=None, description="阅读时间")


class NotificationPreference(TimestampMixin, table=True):
    """User notification preferences."""
    __tablename__ = "notification_preferences"

    id: str | None = Field(default=None, primary_key=True, max_length=36)
    user_id: str = Field(max_length=36, index=True, description="用户ID")
    notification_type: str = Field(max_length=30, description="通知类型")
    enabled: bool = Field(default=True, description="是否启用")
