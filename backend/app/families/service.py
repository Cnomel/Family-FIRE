"""Family management service."""

import random
import string
import uuid
from datetime import datetime, timedelta, timezone

from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.common.exceptions import (
    DuplicateError,
    FamilyLimitError,
    NotFoundError,
    PermissionDeniedError,
    ValidationError,
)
from app.common.logging import get_logger
from app.families.models import Family, FamilyMember
from app.families.schemas import (
    CreateFamilyRequest,
    FamilyDetailResponse,
    FamilyMemberResponse,
    FamilyResponse,
    UpdateFamilyRequest,
)
from app.users.models import SystemSettings, User

logger = get_logger("family_service")


def _generate_invite_code() -> str:
    """Generate a 6-character invite code (uppercase letters + digits)."""
    chars = string.ascii_uppercase + string.digits
    return "".join(random.choices(chars, k=6))


async def _get_setting(db: AsyncSession, key: str, default: str = "3") -> str:
    """Get a system setting value."""
    stmt = select(SystemSettings).where(SystemSettings.key == key)
    result = await db.execute(stmt)
    setting = result.scalar_one_or_none()
    return setting.value if setting else default


async def _check_family_limit(db: AsyncSession, user_id: str) -> None:
    """Check if user has reached the family creation limit."""
    max_families_str = await _get_setting(db, "max_families_per_user", "3")
    max_families = int(max_families_str)

    # Count families where user is creator
    stmt = select(func.count()).select_from(Family).where(Family.created_by == user_id)
    result = await db.execute(stmt)
    count = result.scalar()

    if count >= max_families:
        raise FamilyLimitError(max_families)


async def _verify_family_admin(db: AsyncSession, family_id: str, user_id: str) -> FamilyMember:
    """Verify user is admin of the family. Returns membership record."""
    stmt = select(FamilyMember).where(
        FamilyMember.family_id == family_id,
        FamilyMember.user_id == user_id,
    )
    result = await db.execute(stmt)
    member = result.scalar_one_or_none()

    if not member:
        raise PermissionDeniedError("访问此家庭")

    if member.role != "admin":
        raise PermissionDeniedError("执行此操作（需要管理员权限）")

    return member


async def _get_member_count(db: AsyncSession, family_id: str) -> int:
    """Get number of members in a family."""
    stmt = select(func.count()).select_from(FamilyMember).where(FamilyMember.family_id == family_id)
    result = await db.execute(stmt)
    return result.scalar()


async def create_family(
    db: AsyncSession, user_id: str, data: CreateFamilyRequest
) -> FamilyResponse:
    """Create a new family.

    Raises:
        FamilyLimitError: If user has reached the family creation limit.
    """
    await _check_family_limit(db, user_id)

    family_id = str(uuid.uuid4())
    family = Family(
        id=family_id,
        name=data.name,
        description=data.description,
        created_by=user_id,
    )
    db.add(family)

    # Add creator as admin member
    member = FamilyMember(
        id=str(uuid.uuid4()),
        family_id=family_id,
        user_id=user_id,
        role="admin",
        joined_at=datetime.now(timezone.utc),
    )
    db.add(member)

    logger.info("family_created", family_id=family_id, user_id=user_id, name=data.name)

    return FamilyResponse(
        id=family.id,
        name=family.name,
        description=family.description,
        avatar_url=family.avatar_url,
        created_by=family.created_by,
        member_count=1,
        created_at=family.created_at,
    )


async def get_user_families(db: AsyncSession, user_id: str) -> list[FamilyResponse]:
    """Get all families the user belongs to."""
    stmt = (
        select(Family)
        .join(FamilyMember, FamilyMember.family_id == Family.id)
        .where(FamilyMember.user_id == user_id)
        .order_by(Family.created_at.desc())
    )
    result = await db.execute(stmt)
    families = result.scalars().all()

    responses = []
    for family in families:
        member_count = await _get_member_count(db, family.id)
        responses.append(FamilyResponse(
            id=family.id,
            name=family.name,
            description=family.description,
            avatar_url=family.avatar_url,
            created_by=family.created_by,
            invite_code=family.invite_code,
            member_count=member_count,
            created_at=family.created_at,
        ))

    return responses


async def get_family_detail(
    db: AsyncSession, family_id: str, user_id: str
) -> FamilyDetailResponse:
    """Get detailed family information including members.

    Raises:
        NotFoundError: If family not found.
        PermissionDeniedError: If user is not a member.
    """
    # Get family
    stmt = select(Family).where(Family.id == family_id)
    result = await db.execute(stmt)
    family = result.scalar_one_or_none()

    if not family:
        raise NotFoundError("家庭", family_id)

    # Verify user is a member
    member_stmt = select(FamilyMember).where(
        FamilyMember.family_id == family_id,
        FamilyMember.user_id == user_id,
    )
    member_result = await db.execute(member_stmt)
    if not member_result.scalar_one_or_none():
        raise PermissionDeniedError("访问此家庭")

    # Get members with user info
    members_stmt = (
        select(FamilyMember, User)
        .join(User, User.id == FamilyMember.user_id)
        .where(FamilyMember.family_id == family_id)
    )
    members_result = await db.execute(members_stmt)
    members_data = members_result.all()

    members = [
        FamilyMemberResponse(
            id=m.id,
            user_id=m.user_id,
            username=u.username,
            full_name=u.full_name,
            avatar_url=u.avatar_url,
            role=m.role,
            joined_at=m.joined_at,
        )
        for m, u in members_data
    ]

    return FamilyDetailResponse(
        id=family.id,
        name=family.name,
        description=family.description,
        avatar_url=family.avatar_url,
        created_by=family.created_by,
        invite_code=family.invite_code,
        invite_code_expires_at=family.invite_code_expires_at,
        members=members,
        created_at=family.created_at,
    )


async def update_family(
    db: AsyncSession, family_id: str, user_id: str, data: UpdateFamilyRequest
) -> FamilyResponse:
    """Update family information.

    Raises:
        NotFoundError: If family not found.
        PermissionDeniedError: If user is not admin.
    """
    await _verify_family_admin(db, family_id, user_id)

    stmt = select(Family).where(Family.id == family_id)
    result = await db.execute(stmt)
    family = result.scalar_one_or_none()

    if not family:
        raise NotFoundError("家庭", family_id)

    if data.name is not None:
        family.name = data.name
    if data.description is not None:
        family.description = data.description
    if data.avatar_url is not None:
        family.avatar_url = data.avatar_url

    await db.flush()
    logger.info("family_updated", family_id=family_id, user_id=user_id)

    member_count = await _get_member_count(db, family_id)
    return FamilyResponse(
        id=family.id,
        name=family.name,
        description=family.description,
        avatar_url=family.avatar_url,
        created_by=family.created_by,
        invite_code=family.invite_code,
        member_count=member_count,
        created_at=family.created_at,
    )


async def delete_family(db: AsyncSession, family_id: str, user_id: str) -> None:
    """Delete a family (soft delete - just remove the family record).

    Raises:
        NotFoundError: If family not found.
        PermissionDeniedError: If user is not admin.
    """
    await _verify_family_admin(db, family_id, user_id)

    stmt = select(Family).where(Family.id == family_id)
    result = await db.execute(stmt)
    family = result.scalar_one_or_none()

    if not family:
        raise NotFoundError("家庭", family_id)

    # Delete all memberships first
    del_stmt = FamilyMember.__table__.delete().where(FamilyMember.family_id == family_id)
    await db.execute(del_stmt)

    # Delete family
    await db.delete(family)
    await db.flush()
    logger.info("family_deleted", family_id=family_id, user_id=user_id)


async def generate_invite_code(
    db: AsyncSession, family_id: str, user_id: str
) -> dict:
    """Generate a new invite code for the family.

    Raises:
        NotFoundError: If family not found.
        PermissionDeniedError: If user is not admin.
    """
    await _verify_family_admin(db, family_id, user_id)

    stmt = select(Family).where(Family.id == family_id)
    result = await db.execute(stmt)
    family = result.scalar_one_or_none()

    if not family:
        raise NotFoundError("家庭", family_id)

    # Generate new invite code
    expiry_days_str = await _get_setting(db, "invite_code_expiry_days", "7")
    expiry_days = int(expiry_days_str)

    family.invite_code = _generate_invite_code()
    family.invite_code_expires_at = datetime.now(timezone.utc) + timedelta(days=expiry_days)
    await db.flush()

    logger.info("invite_code_generated", family_id=family_id, code=family.invite_code)

    return {
        "invite_code": family.invite_code,
        "expires_at": family.invite_code_expires_at,
    }


async def join_family(
    db: AsyncSession, user_id: str, invite_code: str
) -> FamilyResponse:
    """Join a family using invite code.

    Raises:
        ValidationError: If invite code is invalid or expired.
        DuplicateError: If user is already a member.
    """
    # Find family with this invite code
    stmt = select(Family).where(Family.invite_code == invite_code)
    result = await db.execute(stmt)
    family = result.scalar_one_or_none()

    if not family:
        raise ValidationError("邀请码无效")

    # Check expiry
    if family.invite_code_expires_at:
        expires_at = family.invite_code_expires_at
        if expires_at.tzinfo is None:
            expires_at = expires_at.replace(tzinfo=timezone.utc)
        if expires_at < datetime.now(timezone.utc):
            raise ValidationError("邀请码已过期")

    # Check if already a member
    member_stmt = select(FamilyMember).where(
        FamilyMember.family_id == family.id,
        FamilyMember.user_id == user_id,
    )
    member_result = await db.execute(member_stmt)
    if member_result.scalar_one_or_none():
        raise DuplicateError("家庭成员", "用户", user_id)

    # Add member
    member = FamilyMember(
        id=str(uuid.uuid4()),
        family_id=family.id,
        user_id=user_id,
        role="member",
        joined_at=datetime.now(timezone.utc),
    )
    db.add(member)
    await db.flush()

    logger.info("user_joined_family", family_id=family.id, user_id=user_id)

    member_count = await _get_member_count(db, family.id)
    return FamilyResponse(
        id=family.id,
        name=family.name,
        description=family.description,
        avatar_url=family.avatar_url,
        created_by=family.created_by,
        member_count=member_count,
        created_at=family.created_at,
    )


async def remove_member(
    db: AsyncSession, family_id: str, admin_id: str, target_user_id: str
) -> None:
    """Remove a member from the family.

    Raises:
        PermissionDeniedError: If requester is not admin.
        NotFoundError: If member not found.
        ValidationError: If trying to remove yourself (use delete_family instead).
    """
    await _verify_family_admin(db, family_id, admin_id)

    if admin_id == target_user_id:
        raise ValidationError("不能移除自己，请使用删除家庭功能")

    stmt = select(FamilyMember).where(
        FamilyMember.family_id == family_id,
        FamilyMember.user_id == target_user_id,
    )
    result = await db.execute(stmt)
    member = result.scalar_one_or_none()

    if not member:
        raise NotFoundError("家庭成员", target_user_id)

    await db.delete(member)
    await db.flush()
    logger.info("member_removed", family_id=family_id, target_user_id=target_user_id, admin_id=admin_id)


async def update_member_role(
    db: AsyncSession, family_id: str, admin_id: str, target_user_id: str, new_role: str
) -> None:
    """Update a member's role.

    Raises:
        PermissionDeniedError: If requester is not admin.
        NotFoundError: If member not found.
    """
    await _verify_family_admin(db, family_id, admin_id)

    stmt = select(FamilyMember).where(
        FamilyMember.family_id == family_id,
        FamilyMember.user_id == target_user_id,
    )
    result = await db.execute(stmt)
    member = result.scalar_one_or_none()

    if not member:
        raise NotFoundError("家庭成员", target_user_id)

    member.role = new_role
    await db.flush()
    logger.info("member_role_updated", family_id=family_id, target_user_id=target_user_id, new_role=new_role)
