"""Family management API router."""

from fastapi import APIRouter, Depends, status
from sqlalchemy.ext.asyncio import AsyncSession

from app.auth.dependencies import CurrentUser
from app.common.schemas import MessageResponse, SuccessResponse
from app.database import get_db
from app.families import service as family_service
from app.families.schemas import (
    CreateFamilyRequest,
    FamilyDetailResponse,
    FamilyListResponse,
    FamilyResponse,
    InviteCodeResponse,
    JoinFamilyRequest,
    UpdateFamilyRequest,
    UpdateMemberRoleRequest,
)

router = APIRouter()


@router.get(
    "/current",
    response_model=SuccessResponse[FamilyResponse],
    summary="当前家庭",
    description="获取用户当前家庭（第一个家庭）",
)
async def get_current_family(
    current_user: CurrentUser,
    db: AsyncSession = Depends(get_db),
):
    families = await family_service.get_user_families(db, current_user.id)
    if not families:
        from app.common.exceptions import NotFoundError
        raise NotFoundError("家庭", "当前用户暂无家庭")
    return SuccessResponse(data=families[0])


@router.post(
    "",
    response_model=SuccessResponse[FamilyResponse],
    status_code=status.HTTP_201_CREATED,
    summary="创建家庭",
    description="创建新家庭（受数量限制）",
)
async def create_family(
    data: CreateFamilyRequest,
    current_user: CurrentUser,
    db: AsyncSession = Depends(get_db),
):
    family = await family_service.create_family(db, current_user.id, data)
    return SuccessResponse(data=family, message="家庭创建成功")


@router.get(
    "",
    response_model=SuccessResponse[FamilyListResponse],
    summary="我的家庭",
    description="获取当前用户所属的所有家庭",
)
async def list_my_families(
    current_user: CurrentUser,
    db: AsyncSession = Depends(get_db),
):
    families = await family_service.get_user_families(db, current_user.id)
    return SuccessResponse(
        data=FamilyListResponse(families=families, total=len(families)),
    )


@router.get(
    "/{family_id}",
    response_model=SuccessResponse[FamilyDetailResponse],
    summary="家庭详情",
    description="获取家庭详细信息（含成员列表）",
)
async def get_family(
    family_id: str,
    current_user: CurrentUser,
    db: AsyncSession = Depends(get_db),
):
    detail = await family_service.get_family_detail(db, family_id, current_user.id)
    return SuccessResponse(data=detail)


@router.put(
    "/{family_id}",
    response_model=SuccessResponse[FamilyResponse],
    summary="更新家庭",
    description="更新家庭信息（仅管理员）",
)
async def update_family(
    family_id: str,
    data: UpdateFamilyRequest,
    current_user: CurrentUser,
    db: AsyncSession = Depends(get_db),
):
    family = await family_service.update_family(db, family_id, current_user.id, data)
    return SuccessResponse(data=family, message="更新成功")


@router.delete(
    "/{family_id}",
    response_model=MessageResponse,
    summary="删除家庭",
    description="删除家庭及所有关联数据（仅管理员）",
)
async def delete_family(
    family_id: str,
    current_user: CurrentUser,
    db: AsyncSession = Depends(get_db),
):
    await family_service.delete_family(db, family_id, current_user.id)
    return MessageResponse(message="家庭已删除")


@router.post(
    "/{family_id}/invite",
    response_model=SuccessResponse[InviteCodeResponse],
    summary="生成邀请码",
    description="生成家庭邀请码（仅管理员，7天有效）",
)
async def generate_invite(
    family_id: str,
    current_user: CurrentUser,
    db: AsyncSession = Depends(get_db),
):
    result = await family_service.generate_invite_code(db, family_id, current_user.id)
    return SuccessResponse(
        data=InviteCodeResponse(
            invite_code=result["invite_code"],
            expires_at=result["expires_at"],
        ),
        message="邀请码已生成",
    )


@router.post(
    "/join",
    response_model=SuccessResponse[FamilyResponse],
    summary="加入家庭",
    description="通过邀请码加入家庭",
)
async def join_family(
    data: JoinFamilyRequest,
    current_user: CurrentUser,
    db: AsyncSession = Depends(get_db),
):
    family = await family_service.join_family(db, current_user.id, data.invite_code)
    return SuccessResponse(data=family, message="成功加入家庭")


@router.delete(
    "/{family_id}/members/{user_id}",
    response_model=MessageResponse,
    summary="移除成员",
    description="从家庭中移除成员（仅管理员）",
)
async def remove_member(
    family_id: str,
    user_id: str,
    current_user: CurrentUser,
    db: AsyncSession = Depends(get_db),
):
    await family_service.remove_member(db, family_id, current_user.id, user_id)
    return MessageResponse(message="成员已移除")


@router.put(
    "/{family_id}/members/{user_id}/role",
    response_model=MessageResponse,
    summary="修改成员角色",
    description="修改家庭成员角色（仅管理员）",
)
async def update_member_role(
    family_id: str,
    user_id: str,
    data: UpdateMemberRoleRequest,
    current_user: CurrentUser,
    db: AsyncSession = Depends(get_db),
):
    await family_service.update_member_role(db, family_id, current_user.id, user_id, data.role)
    return MessageResponse(message="成员角色已更新")
