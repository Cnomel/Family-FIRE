"""Family management schemas."""

from datetime import datetime

from pydantic import BaseModel, Field

# ============================================================
# Request Schemas
# ============================================================

class CreateFamilyRequest(BaseModel):
    """Create a new family."""
    name: str = Field(min_length=1, max_length=100, description="家庭名称")
    description: str | None = Field(default=None, max_length=500, description="家庭描述")


class UpdateFamilyRequest(BaseModel):
    """Update family information."""
    name: str | None = Field(default=None, min_length=1, max_length=100, description="家庭名称")
    description: str | None = Field(default=None, max_length=500, description="家庭描述")
    avatar_url: str | None = Field(default=None, max_length=500, description="家庭头像")


class JoinFamilyRequest(BaseModel):
    """Join family via invite code."""
    invite_code: str = Field(min_length=6, max_length=10, description="邀请码")


class UpdateMemberRoleRequest(BaseModel):
    """Update family member role."""
    role: str = Field(pattern="^(admin|member)$", description="角色: admin/member")


# ============================================================
# Response Schemas
# ============================================================

class FamilyResponse(BaseModel):
    """Family information."""
    id: str
    name: str
    description: str | None = None
    avatar_url: str | None = None
    created_by: str
    invite_code: str | None = None
    member_count: int = 0
    asset_count: int = 0
    created_at: datetime


class FamilyMemberResponse(BaseModel):
    """Family member information."""
    id: str
    user_id: str
    username: str
    full_name: str
    avatar_url: str | None = None
    role: str
    joined_at: datetime | None = None


class FamilyDetailResponse(BaseModel):
    """Detailed family information with members."""
    id: str
    name: str
    description: str | None = None
    avatar_url: str | None = None
    created_by: str
    invite_code: str | None = None
    invite_code_expires_at: datetime | None = None
    members: list[FamilyMemberResponse] = []
    created_at: datetime


class FamilyListResponse(BaseModel):
    """List of families."""
    families: list[FamilyResponse]
    total: int


class InviteCodeResponse(BaseModel):
    """Invite code information."""
    invite_code: str
    expires_at: datetime
