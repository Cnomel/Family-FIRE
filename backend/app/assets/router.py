"""Asset management API router."""

from fastapi import APIRouter, Depends, status
from sqlalchemy.ext.asyncio import AsyncSession

from app.assets import service as asset_service
from app.assets.schemas import (
    AddTagRequest,
    AssetDetailResponse,
    AssetFilterParams,
    AssetListResponse,
    AssetResponse,
    AssetStatsResponse,
    BulkActionRequest,
    CreateAssetRequest,
    UpdateAssetRequest,
)
from app.auth.dependencies import CurrentUser
from app.common.schemas import MessageResponse, SuccessResponse
from app.database import get_db

router = APIRouter()


@router.post(
    "",
    response_model=SuccessResponse[AssetResponse],
    status_code=status.HTTP_201_CREATED,
    summary="创建资产",
    description="在指定家庭中创建新资产（自动检测重复）",
)
async def create_asset(
    family_id: str,
    data: CreateAssetRequest,
    current_user: CurrentUser,
    db: AsyncSession = Depends(get_db),
):
    asset = await asset_service.create_asset(db, family_id, current_user.id, data)
    return SuccessResponse(data=asset, message="资产创建成功")


@router.get(
    "",
    response_model=SuccessResponse[AssetListResponse],
    summary="资产列表",
    description="获取家庭资产列表（支持高级筛选和分页）",
)
async def list_assets(
    family_id: str,
    current_user: CurrentUser,
    db: AsyncSession = Depends(get_db),
    nature: str | None = None,
    utility: str | None = None,
    ownership: str | None = None,
    liquidity: str | None = None,
    status: str = "active",
    search: str | None = None,
    page: int = 1,
    page_size: int = 20,
):
    filters = AssetFilterParams(
        nature=nature,
        utility=utility,
        ownership=ownership,
        liquidity=liquidity,
        status=status,
        search=search,
        page=page,
        page_size=page_size,
    )
    result = await asset_service.list_assets(db, family_id, current_user.id, filters)
    return SuccessResponse(data=result)


@router.get(
    "/stats",
    response_model=SuccessResponse[AssetStatsResponse],
    summary="资产统计",
    description="获取家庭资产按维度分组的统计数据",
)
async def get_asset_stats(
    family_id: str,
    current_user: CurrentUser,
    db: AsyncSession = Depends(get_db),
):
    stats = await asset_service.get_asset_stats(db, family_id, current_user.id)
    return SuccessResponse(data=stats)


@router.get(
    "/tags",
    response_model=SuccessResponse[list],
    summary="所有标签",
    description="获取家庭资产使用的所有标签及计数",
)
async def get_all_tags(
    family_id: str,
    current_user: CurrentUser,
    db: AsyncSession = Depends(get_db),
):
    tags = await asset_service.get_all_tags(db, family_id, current_user.id)
    return SuccessResponse(data=tags)


@router.get(
    "/{asset_id}",
    response_model=SuccessResponse[AssetDetailResponse],
    summary="资产详情",
    description="获取资产的完整信息（含元数据、关系、文档）",
)
async def get_asset(
    family_id: str,
    asset_id: str,
    current_user: CurrentUser,
    db: AsyncSession = Depends(get_db),
):
    detail = await asset_service.get_asset_detail(db, asset_id, family_id, current_user.id)
    return SuccessResponse(data=detail)


@router.put(
    "/{asset_id}",
    response_model=SuccessResponse[AssetResponse],
    summary="更新资产",
    description="更新资产信息",
)
async def update_asset(
    family_id: str,
    asset_id: str,
    data: UpdateAssetRequest,
    current_user: CurrentUser,
    db: AsyncSession = Depends(get_db),
):
    asset = await asset_service.update_asset(db, asset_id, family_id, current_user.id, data)
    return SuccessResponse(data=asset, message="更新成功")


@router.delete(
    "/{asset_id}",
    response_model=MessageResponse,
    summary="归档资产",
    description="软删除（归档）资产",
)
async def delete_asset(
    family_id: str,
    asset_id: str,
    current_user: CurrentUser,
    db: AsyncSession = Depends(get_db),
):
    await asset_service.delete_asset(db, asset_id, family_id, current_user.id)
    return MessageResponse(message="资产已归档")


@router.post(
    "/bulk",
    response_model=SuccessResponse[dict],
    summary="批量操作",
    description="批量归档/删除/打标签",
)
async def bulk_action(
    family_id: str,
    data: BulkActionRequest,
    current_user: CurrentUser,
    db: AsyncSession = Depends(get_db),
):
    result = await asset_service.bulk_action(db, family_id, current_user.id, data)
    return SuccessResponse(data=result, message=f"批量操作完成: {result['success_count']}/{result['total']}")


@router.post(
    "/{asset_id}/tags",
    response_model=MessageResponse,
    summary="添加标签",
    description="为资产添加标签",
)
async def add_tag(
    family_id: str,
    asset_id: str,
    data: AddTagRequest,
    current_user: CurrentUser,
    db: AsyncSession = Depends(get_db),
):
    await asset_service.add_tag(db, asset_id, family_id, current_user.id, data.tag)
    return MessageResponse(message="标签已添加")


@router.delete(
    "/{asset_id}/tags/{tag}",
    response_model=MessageResponse,
    summary="删除标签",
    description="从资产删除标签",
)
async def remove_tag(
    family_id: str,
    asset_id: str,
    tag: str,
    current_user: CurrentUser,
    db: AsyncSession = Depends(get_db),
):
    await asset_service.remove_tag(db, asset_id, family_id, current_user.id, tag)
    return MessageResponse(message="标签已删除")
