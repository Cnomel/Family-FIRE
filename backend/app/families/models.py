"""Family and FamilyMember models."""

from datetime import datetime

from sqlmodel import Field

from app.common.models import TimestampMixin


class Family(TimestampMixin, table=True):
    """Family group model. Users create families to manage shared assets."""
    __tablename__ = "families"

    id: str | None = Field(default=None, primary_key=True, max_length=36)
    name: str = Field(max_length=100, description="家庭名称")
    description: str | None = Field(default=None, max_length=500, description="家庭描述")
    avatar_url: str | None = Field(default=None, max_length=500, description="家庭头像")
    created_by: str = Field(max_length=36, index=True, description="创建者用户ID")
    invite_code: str | None = Field(default=None, max_length=10, unique=True, index=True, description="邀请码")
    invite_code_expires_at: datetime | None = Field(default=None, description="邀请码过期时间")


class FamilyMember(TimestampMixin, table=True):
    """Family membership model. Links users to families with roles."""
    __tablename__ = "family_members"

    id: str | None = Field(default=None, primary_key=True, max_length=36)
    family_id: str = Field(max_length=36, index=True, description="家庭ID")
    user_id: str = Field(max_length=36, index=True, description="用户ID")
    role: str = Field(max_length=20, default="member", description="角色: admin / member")
    invited_by: str | None = Field(default=None, max_length=36, description="邀请者用户ID")
    joined_at: datetime = Field(default=None, description="加入时间")
