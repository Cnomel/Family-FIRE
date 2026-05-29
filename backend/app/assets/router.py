"""Asset management API router."""

from app.families.dependencies import verify_family_member
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
    data: CreateAssetRequest,
    current_user: CurrentUser = None,
    db: AsyncSession = Depends(get_db),
    family_id: str = Depends(verify_family_member),
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
        current_user: CurrentUser = None,
    db: AsyncSession = Depends(get_db),
    nature: str | None = None,
    utility: str | None = None,
    ownership: str | None = None,
    liquidity: str | None = None,
    status: str = "active",
    search: str | None = None,
    page: int = 1,
    page_size: int = 20,
    family_id: str = Depends(verify_family_member),
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
        current_user: CurrentUser = None,
    db: AsyncSession = Depends(get_db),
    family_id: str = Depends(verify_family_member),
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
        current_user: CurrentUser = None,
    db: AsyncSession = Depends(get_db),
    family_id: str = Depends(verify_family_member),
):
    tags = await asset_service.get_all_tags(db, family_id, current_user.id)
    return SuccessResponse(data=tags)


@router.get(
    "/relationship-graph",
    response_model=SuccessResponse[dict],
    summary="关系图谱",
    description="获取家庭资产的完整关系图谱（节点+边）",
)
async def get_relationship_graph(
        current_user: CurrentUser = None,
    db: AsyncSession = Depends(get_db),
    family_id: str = Depends(verify_family_member),
):
    from app.assets import relationships as rel_service
    graph = await rel_service.get_relationship_graph(db, family_id, current_user.id)
    return SuccessResponse(data=graph)


@router.get(
    "/insurance-gaps",
    response_model=SuccessResponse[list],
    summary="保险缺口",
    description="分析高价值资产的保险覆盖缺口",
)
async def get_insurance_gaps(
        current_user: CurrentUser = None,
    db: AsyncSession = Depends(get_db),
    family_id: str = Depends(verify_family_member),
):
    from app.assets import relationships as rel_service
    gaps = await rel_service.analyze_insurance_gaps(db, family_id, current_user.id)
    return SuccessResponse(data=gaps)


@router.get(
    "/relationship-types",
    response_model=SuccessResponse[dict],
    summary="关系类型",
    description="获取所有可用的关系类型及说明",
)
async def get_relationship_types():
    from app.assets.lifecycle.engine import RELATIONSHIP_TYPES
    return SuccessResponse(data=RELATIONSHIP_TYPES)


@router.get(
    "/{asset_id}",
    response_model=SuccessResponse[AssetDetailResponse],
    summary="资产详情",
    description="获取资产的完整信息（含元数据、关系、文档）",
)
async def get_asset(
    asset_id: str,
    current_user: CurrentUser = None,
    db: AsyncSession = Depends(get_db),
    family_id: str = Depends(verify_family_member),
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
    asset_id: str,
    data: UpdateAssetRequest,
    current_user: CurrentUser = None,
    db: AsyncSession = Depends(get_db),
    family_id: str = Depends(verify_family_member),
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
    asset_id: str,
    current_user: CurrentUser = None,
    db: AsyncSession = Depends(get_db),
    family_id: str = Depends(verify_family_member),
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
        data: BulkActionRequest,
    current_user: CurrentUser = None,
    db: AsyncSession = Depends(get_db),
    family_id: str = Depends(verify_family_member),
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
    asset_id: str,
    data: AddTagRequest,
    current_user: CurrentUser = None,
    db: AsyncSession = Depends(get_db),
    family_id: str = Depends(verify_family_member),
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
    asset_id: str,
    tag: str,
    current_user: CurrentUser = None,
    db: AsyncSession = Depends(get_db),
    family_id: str = Depends(verify_family_member),
):
    await asset_service.remove_tag(db, asset_id, family_id, current_user.id, tag)
    return MessageResponse(message="标签已删除")


# ============================================================
# Lifecycle Endpoints
# ============================================================

@router.get(
    "/{asset_id}/lifecycle",
    response_model=SuccessResponse[dict],
    summary="生命周期状态",
    description="获取资产的生命周期配置和当前计算值",
)
async def get_lifecycle(
    asset_id: str,
    current_user: CurrentUser = None,
    db: AsyncSession = Depends(get_db),
    family_id: str = Depends(verify_family_member),
):
    from app.assets.lifecycle.engine import compute_current_value
    from app.assets.models import AssetLifecycle

    await asset_service._verify_family_member(db, family_id, current_user.id)

    from sqlalchemy import select

    from app.assets.models import AssetFinancial

    # Get lifecycle
    lc_stmt = select(AssetLifecycle).where(AssetLifecycle.asset_id == asset_id)
    lc_result = await db.execute(lc_stmt)
    lifecycle = lc_result.scalar_one_or_none()

    # Get financial
    fin_stmt = select(AssetFinancial).where(AssetFinancial.asset_id == asset_id)
    fin_result = await db.execute(fin_stmt)
    financial = fin_result.scalar_one_or_none()

    if not lifecycle or not financial:
        from app.common.exceptions import NotFoundError
        raise NotFoundError("资产", asset_id)

    # Compute current value
    config_map = {
        "depreciating": lifecycle.depreciation_config,
        "consumable": lifecycle.consumption_config,
        "expiring": lifecycle.expiration_config,
        "volatile": lifecycle.market_value_config,
        "appreciating": lifecycle.appreciation_config,
    }
    config = config_map.get(lifecycle.trajectory, {})

    computed_value = compute_current_value(
        trajectory=lifecycle.trajectory,
        purchase_price=financial.purchase_price,
        purchase_date=financial.purchase_date,
        config=config or {},
    )

    return SuccessResponse(data={
        "asset_id": asset_id,
        "trajectory": lifecycle.trajectory,
        "config": config,
        "purchase_price": financial.purchase_price,
        "current_value": financial.current_value,
        "computed_value": round(computed_value, 2),
    })


@router.put(
    "/{asset_id}/lifecycle",
    response_model=MessageResponse,
    summary="更新生命周期配置",
    description="更新资产的生命周期配置参数",
)
async def update_lifecycle(
    asset_id: str,
    data: dict,
    current_user: CurrentUser = None,
    db: AsyncSession = Depends(get_db),
    family_id: str = Depends(verify_family_member),
):
    from sqlalchemy import select

    from app.assets.models import AssetLifecycle

    await asset_service._verify_family_member(db, family_id, current_user.id)

    stmt = select(AssetLifecycle).where(AssetLifecycle.asset_id == asset_id)
    result = await db.execute(stmt)
    lifecycle = result.scalar_one_or_none()

    if not lifecycle:
        from app.common.exceptions import NotFoundError
        raise NotFoundError("资产", asset_id)

    # Update config based on trajectory
    if lifecycle.trajectory == "depreciating" and "depreciation_config" in data:
        lifecycle.depreciation_config = data["depreciation_config"]
    elif lifecycle.trajectory == "consumable" and "consumption_config" in data:
        lifecycle.consumption_config = data["consumption_config"]
    elif lifecycle.trajectory == "expiring" and "expiration_config" in data:
        lifecycle.expiration_config = data["expiration_config"]
    elif lifecycle.trajectory == "volatile" and "market_value_config" in data:
        lifecycle.market_value_config = data["market_value_config"]
    elif lifecycle.trajectory == "appreciating" and "appreciation_config" in data:
        lifecycle.appreciation_config = data["appreciation_config"]

    if "trajectory" in data:
        lifecycle.trajectory = data["trajectory"]

    await db.flush()
    return MessageResponse(message="生命周期配置已更新")


@router.get(
    "/{asset_id}/value-history",
    response_model=SuccessResponse[list],
    summary="价值变化历史",
    description="获取资产的价值变化时间序列",
)
async def get_value_history(
    asset_id: str,
    current_user: CurrentUser = None,
    db: AsyncSession = Depends(get_db),
    months: int = 12,
    family_id: str = Depends(verify_family_member),
):
    from sqlalchemy import select

    from app.assets.lifecycle.engine import compute_value_history
    from app.assets.models import AssetFinancial, AssetLifecycle

    await asset_service._verify_family_member(db, family_id, current_user.id)

    lc_stmt = select(AssetLifecycle).where(AssetLifecycle.asset_id == asset_id)
    lc_result = await db.execute(lc_stmt)
    lifecycle = lc_result.scalar_one_or_none()

    fin_stmt = select(AssetFinancial).where(AssetFinancial.asset_id == asset_id)
    fin_result = await db.execute(fin_stmt)
    financial = fin_result.scalar_one_or_none()

    if not lifecycle or not financial:
        from app.common.exceptions import NotFoundError
        raise NotFoundError("资产", asset_id)

    config_map = {
        "depreciating": lifecycle.depreciation_config,
        "appreciating": lifecycle.appreciation_config,
    }
    config = config_map.get(lifecycle.trajectory, {})

    history = compute_value_history(
        trajectory=lifecycle.trajectory,
        purchase_price=financial.purchase_price,
        purchase_date=financial.purchase_date,
        config=config or {},
        months=months,
    )

    return SuccessResponse(data=history)


# ============================================================
# Relationship Endpoints
# ============================================================

@router.get(
    "/{asset_id}/relationships",
    response_model=SuccessResponse[list],
    summary="关联资产",
    description="获取资产的所有关联关系",
)
async def get_relationships(
    asset_id: str,
    current_user: CurrentUser = None,
    db: AsyncSession = Depends(get_db),
    family_id: str = Depends(verify_family_member),
):
    from app.assets import relationships as rel_service
    rels = await rel_service.get_asset_relationships(db, family_id, current_user.id, asset_id)
    return SuccessResponse(data=rels)


@router.post(
    "/{asset_id}/relationships",
    response_model=SuccessResponse[dict],
    status_code=201,
    summary="创建关系",
    description="创建资产间的关联关系",
)
async def create_relationship(
    asset_id: str,
    data: dict,
    current_user: CurrentUser = None,
    db: AsyncSession = Depends(get_db),
    family_id: str = Depends(verify_family_member),
):
    from app.assets import relationships as rel_service
    rel = await rel_service.create_relationship(
        db=db,
        family_id=family_id,
        user_id=current_user.id,
        source_asset_id=asset_id,
        target_asset_id=data.get("target_asset_id", ""),
        rel_type=data.get("type", ""),
        is_optional=data.get("is_optional", True),
        lifecycle_linked=data.get("lifecycle_linked", False),
    )
    return SuccessResponse(data=rel, message="关系创建成功")


@router.delete(
    "/{asset_id}/relationships/{rel_id}",
    response_model=MessageResponse,
    summary="删除关系",
    description="删除资产间的关联关系",
)
async def delete_relationship(
    asset_id: str,
    rel_id: str,
    current_user: CurrentUser = None,
    db: AsyncSession = Depends(get_db),
    family_id: str = Depends(verify_family_member),
):
    from app.assets import relationships as rel_service
    await rel_service.delete_relationship(db, family_id, current_user.id, rel_id)
    return MessageResponse(message="关系已删除")
