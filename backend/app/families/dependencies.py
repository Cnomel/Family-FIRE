"""Family-related dependencies."""

from typing import Annotated, Optional

from fastapi import Depends, Path, Query
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.auth.dependencies import CurrentUser
from app.common.exceptions import NotFoundError, PermissionDeniedError
from app.database import get_db
from app.families.models import Family, FamilyMember


async def resolve_family_id(
    family_id: str = Path(..., description="家庭ID或'current'"),
    current_user: CurrentUser = None,
    db: AsyncSession = Depends(get_db),
) -> str:
    """Resolve family_id parameter. Supports 'current' as a shortcut for user's first family."""
    if family_id == "current":
        stmt = (
            select(Family.id)
            .join(FamilyMember, FamilyMember.family_id == Family.id)
            .where(FamilyMember.user_id == current_user.id)
            .limit(1)
        )
        result = await db.execute(stmt)
        row = result.first()
        if not row:
            raise NotFoundError("家庭", "当前用户暂无家庭")
        return row[0]
    return family_id


async def resolve_family_id_query(
    family_id: Optional[str] = Query(None, description="家庭ID（可选，默认使用用户第一个家庭）"),
    current_user: CurrentUser = None,
    db: AsyncSession = Depends(get_db),
) -> str:
    """Resolve family_id from query parameter. Falls back to user's first family."""
    if not family_id:
        stmt = (
            select(Family.id)
            .join(FamilyMember, FamilyMember.family_id == Family.id)
            .where(FamilyMember.user_id == current_user.id)
            .limit(1)
        )
        result = await db.execute(stmt)
        row = result.first()
        if not row:
            raise NotFoundError("家庭", "当前用户暂无家庭")
        return row[0]
    return family_id


async def verify_family_member(
    family_id: str = Depends(resolve_family_id),
    current_user: CurrentUser = None,
    db: AsyncSession = Depends(get_db),
) -> str:
    """Verify user is a member of the resolved family. Returns family_id."""
    stmt = select(FamilyMember).where(
        FamilyMember.family_id == family_id,
        FamilyMember.user_id == current_user.id,
    )
    result = await db.execute(stmt)
    if not result.scalar_one_or_none():
        raise PermissionDeniedError("访问此家庭")
    return family_id


async def verify_family_member_query(
    family_id: str = Depends(resolve_family_id_query),
    current_user: CurrentUser = None,
    db: AsyncSession = Depends(get_db),
) -> str:
    """Verify user is a member (from query param). Returns family_id."""
    stmt = select(FamilyMember).where(
        FamilyMember.family_id == family_id,
        FamilyMember.user_id == current_user.id,
    )
    result = await db.execute(stmt)
    if not result.scalar_one_or_none():
        raise PermissionDeniedError("访问此家庭")
    return family_id


# Type aliases
ResolvedFamilyId = Annotated[str, Depends(resolve_family_id)]
VerifiedFamilyId = Annotated[str, Depends(verify_family_member)]
