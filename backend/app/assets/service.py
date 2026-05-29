"""Asset management service with search, stats, and duplicate detection."""

import uuid
from typing import Any

from sqlalchemy import and_, func, or_
from sqlalchemy.ext.asyncio import AsyncSession
from sqlmodel import select

from app.assets.models import (
    Asset,
    AssetFinancial,
    AssetLifecycle,
    AssetMetadataAccount,
    AssetMetadataConsumable,
    AssetMetadataElectronics,
    AssetMetadataFinancial,
    AssetMetadataFurniture,
    AssetMetadataInsurance,
    AssetMetadataRealEstate,
    AssetMetadataSubscription,
    AssetMetadataVehicle,
)
from app.assets.schemas import (
    AssetDetailResponse,
    AssetFilterParams,
    AssetFinancialResponse,
    AssetListResponse,
    AssetResponse,
    AssetStatsResponse,
    BulkActionRequest,
    CreateAssetRequest,
    UpdateAssetRequest,
)
from app.common.exceptions import DuplicateError, NotFoundError, PermissionDeniedError
from app.common.logging import get_logger
from app.families.models import FamilyMember

logger = get_logger("asset_service")

# Map metadata_type to model classes
METADATA_MODELS = {
    "vehicle": AssetMetadataVehicle,
    "real_estate": AssetMetadataRealEstate,
    "electronics": AssetMetadataElectronics,
    "furniture": AssetMetadataFurniture,
    "insurance": AssetMetadataInsurance,
    "financial": AssetMetadataFinancial,
    "subscription": AssetMetadataSubscription,
    "account": AssetMetadataAccount,
    "consumable": AssetMetadataConsumable,
}


async def _verify_family_member(db: AsyncSession, family_id: str, user_id: str) -> None:
    """Verify user is a member of the family."""
    stmt = select(FamilyMember).where(
        FamilyMember.family_id == family_id,
        FamilyMember.user_id == user_id,
    )
    result = await db.execute(stmt)
    if not result.scalar_one_or_none():
        raise PermissionDeniedError("访问此家庭的资产")


async def _check_duplicate(db: AsyncSession, family_id: str, name: str, nature: str) -> None:
    """Check for potential duplicate assets."""
    stmt = select(Asset).where(
        Asset.family_id == family_id,
        Asset.name == name,
        Asset.nature == nature,
        Asset.status == "active",
    )
    result = await db.execute(stmt)
    if result.scalar_one_or_none():
        raise DuplicateError("资产", "名称+类型", f"{name} ({nature})")


def _asset_to_response(asset: Asset, financial: AssetFinancial | None = None) -> AssetResponse:
    """Convert Asset model to response."""
    tags = asset.tags if asset.tags else None
    return AssetResponse(
        id=asset.id,
        name=asset.name,
        description=asset.description,
        nature=asset.nature,
        utility=asset.utility,
        ownership=asset.ownership,
        liquidity=asset.liquidity,
        tags=tags,
        status=asset.status,
        financial=AssetFinancialResponse(
            purchase_price=financial.purchase_price if financial else 0,
            purchase_date=financial.purchase_date if financial else None,
            currency=financial.currency if financial else "CNY",
            current_value=financial.current_value if financial else 0,
            last_valuation_date=financial.last_valuation_date if financial else None,
            total_cost_of_ownership=financial.total_cost_of_ownership if financial else 0,
            monthly_carrying_cost=financial.monthly_carrying_cost if financial else 0,
        ) if financial else None,
        created_at=asset.created_at,
    )


async def create_asset(
    db: AsyncSession, family_id: str, user_id: str, data: CreateAssetRequest
) -> AssetResponse:
    """Create a new asset.

    Raises:
        PermissionDeniedError: If user is not a family member.
        DuplicateError: If a similar asset exists.
    """
    await _verify_family_member(db, family_id, user_id)
    await _check_duplicate(db, family_id, data.name, data.nature)

    asset_id = str(uuid.uuid4())

    # Create asset
    asset = Asset(
        id=asset_id,
        family_id=family_id,
        created_by=user_id,
        name=data.name,
        description=data.description,
        nature=data.nature,
        utility=data.utility,
        ownership=data.ownership,
        liquidity=data.liquidity,
        tags=data.tags,
        custom_fields=data.custom_fields,
        status="active",
    )
    db.add(asset)

    # Create financial record
    financial = AssetFinancial(
        id=str(uuid.uuid4()),
        asset_id=asset_id,
        purchase_price=data.purchase_price,
        purchase_date=data.purchase_date,
        currency=data.currency,
        current_value=data.purchase_price,  # Initial value = purchase price
    )
    db.add(financial)

    # Create lifecycle record
    lifecycle = AssetLifecycle(
        id=str(uuid.uuid4()),
        asset_id=asset_id,
        trajectory=_infer_trajectory(data.nature, data.utility),
    )
    db.add(lifecycle)

    # Create type-specific metadata if provided
    if data.metadata_type and data.metadata:
        model_class = METADATA_MODELS.get(data.metadata_type)
        if model_class:
            meta = model_class(
                id=str(uuid.uuid4()),
                asset_id=asset_id,
                **data.metadata,
            )
            db.add(meta)

    await db.flush()
    logger.info("asset_created", asset_id=asset_id, family_id=family_id, name=data.name)

    return _asset_to_response(asset, financial)


def _infer_trajectory(nature: str, utility: str) -> str:
    """Infer lifecycle trajectory from classification."""
    if nature == "financial" and utility in ("speculative", "productive"):
        return "volatile"
    if nature == "service" or utility == "protective":
        return "expiring"
    if utility == "consumable":
        return "consumable"
    if nature == "tangible" and utility in ("essential", "lifestyle"):
        return "depreciating"
    if nature == "tangible" and utility == "productive":
        return "appreciating"
    return "stable"


async def get_asset_detail(
    db: AsyncSession, asset_id: str, family_id: str, user_id: str
) -> AssetDetailResponse:
    """Get detailed asset information.

    Raises:
        NotFoundError: If asset not found.
        PermissionDeniedError: If user is not a family member.
    """
    await _verify_family_member(db, family_id, user_id)

    stmt = select(Asset).where(Asset.id == asset_id, Asset.family_id == family_id)
    result = await db.execute(stmt)
    asset = result.scalar_one_or_none()

    if not asset:
        raise NotFoundError("资产", asset_id)

    # Get financial info
    fin_stmt = select(AssetFinancial).where(AssetFinancial.asset_id == asset_id)
    fin_result = await db.execute(fin_stmt)
    financial = fin_result.scalar_one_or_none()

    # Get metadata
    metadata = None
    metadata_type = None
    for type_name, model_class in METADATA_MODELS.items():
        meta_stmt = select(model_class).where(model_class.asset_id == asset_id)
        meta_result = await db.execute(meta_stmt)
        meta = meta_result.scalar_one_or_none()
        if meta:
            metadata_type = type_name
            # Convert to dict, excluding internal fields
            metadata = {k: v for k, v in meta.__dict__.items()
                       if not k.startswith("_") and k not in ("id", "asset_id", "created_at", "updated_at")}
            break

    return AssetDetailResponse(
        id=asset.id,
        name=asset.name,
        description=asset.description,
        nature=asset.nature,
        utility=asset.utility,
        ownership=asset.ownership,
        liquidity=asset.liquidity,
        tags=asset.tags,
        status=asset.status,
        custom_fields=asset.custom_fields,
        financial=AssetFinancialResponse(
            purchase_price=financial.purchase_price if financial else 0,
            purchase_date=financial.purchase_date if financial else None,
            currency=financial.currency if financial else "CNY",
            current_value=financial.current_value if financial else 0,
            last_valuation_date=financial.last_valuation_date if financial else None,
            total_cost_of_ownership=financial.total_cost_of_ownership if financial else 0,
            monthly_carrying_cost=financial.monthly_carrying_cost if financial else 0,
        ) if financial else None,
        metadata=metadata,
        metadata_type=metadata_type,
        created_at=asset.created_at,
    )


async def list_assets(
    db: AsyncSession, family_id: str, user_id: str, filters: AssetFilterParams
) -> AssetListResponse:
    """List assets with filtering and pagination."""
    await _verify_family_member(db, family_id, user_id)

    # Build query
    conditions = [
        Asset.family_id == family_id,
        Asset.status == filters.status,
    ]

    if filters.nature:
        conditions.append(Asset.nature == filters.nature)
    if filters.utility:
        conditions.append(Asset.utility == filters.utility)
    if filters.ownership:
        conditions.append(Asset.ownership == filters.ownership)
    if filters.liquidity:
        conditions.append(Asset.liquidity == filters.liquidity)
    if filters.search:
        search_term = f"%{filters.search}%"
        conditions.append(
            or_(
                Asset.name.ilike(search_term),
                Asset.description.ilike(search_term),
            )
        )

    # Count total
    count_stmt = select(func.count()).select_from(Asset).where(and_(*conditions))
    count_result = await db.execute(count_stmt)
    total = count_result.scalar()

    # Get assets with pagination
    offset = (filters.page - 1) * filters.page_size
    stmt = (
        select(Asset)
        .where(and_(*conditions))
        .order_by(Asset.created_at.desc())
        .offset(offset)
        .limit(filters.page_size)
    )
    result = await db.execute(stmt)
    assets = result.scalars().all()

    # Get financial info for each asset
    responses = []
    for asset in assets:
        fin_stmt = select(AssetFinancial).where(AssetFinancial.asset_id == asset.id)
        fin_result = await db.execute(fin_stmt)
        financial = fin_result.scalar_one_or_none()
        responses.append(_asset_to_response(asset, financial))

    return AssetListResponse(
        assets=responses,
        total=total,
        page=filters.page,
        page_size=filters.page_size,
    )


async def update_asset(
    db: AsyncSession, asset_id: str, family_id: str, user_id: str, data: UpdateAssetRequest
) -> AssetResponse:
    """Update an asset.

    Raises:
        NotFoundError: If asset not found.
        PermissionDeniedError: If user is not a family member.
    """
    await _verify_family_member(db, family_id, user_id)

    stmt = select(Asset).where(Asset.id == asset_id, Asset.family_id == family_id)
    result = await db.execute(stmt)
    asset = result.scalar_one_or_none()

    if not asset:
        raise NotFoundError("资产", asset_id)

    # Update fields
    if data.name is not None:
        asset.name = data.name
    if data.description is not None:
        asset.description = data.description
    if data.nature is not None:
        asset.nature = data.nature
    if data.utility is not None:
        asset.utility = data.utility
    if data.ownership is not None:
        asset.ownership = data.ownership
    if data.liquidity is not None:
        asset.liquidity = data.liquidity
    if data.tags is not None:
        asset.tags = data.tags
    if data.custom_fields is not None:
        asset.custom_fields = data.custom_fields
    if data.status is not None:
        asset.status = data.status

    await db.flush()
    logger.info("asset_updated", asset_id=asset_id)

    # Get financial info
    fin_stmt = select(AssetFinancial).where(AssetFinancial.asset_id == asset_id)
    fin_result = await db.execute(fin_stmt)
    financial = fin_result.scalar_one_or_none()

    return _asset_to_response(asset, financial)


async def delete_asset(
    db: AsyncSession, asset_id: str, family_id: str, user_id: str
) -> None:
    """Soft delete (archive) an asset.

    Raises:
        NotFoundError: If asset not found.
        PermissionDeniedError: If user is not a family member.
    """
    await _verify_family_member(db, family_id, user_id)

    stmt = select(Asset).where(Asset.id == asset_id, Asset.family_id == family_id)
    result = await db.execute(stmt)
    asset = result.scalar_one_or_none()

    if not asset:
        raise NotFoundError("资产", asset_id)

    asset.status = "archived"
    await db.flush()
    logger.info("asset_archived", asset_id=asset_id)


async def bulk_action(
    db: AsyncSession, family_id: str, user_id: str, data: BulkActionRequest
) -> dict[str, Any]:
    """Perform bulk action on multiple assets."""
    await _verify_family_member(db, family_id, user_id)

    success_count = 0
    for asset_id in data.asset_ids:
        stmt = select(Asset).where(Asset.id == asset_id, Asset.family_id == family_id)
        result = await db.execute(stmt)
        asset = result.scalar_one_or_none()

        if not asset:
            continue

        if data.action == "archive":
            asset.status = "archived"
            success_count += 1
        elif data.action == "delete":
            asset.status = "disposed"
            success_count += 1
        elif data.action == "tag" and data.tag:
            tags = asset.tags or []
            if data.tag not in tags:
                tags.append(data.tag)
                asset.tags = tags
            success_count += 1

    await db.flush()
    logger.info("bulk_action", action=data.action, count=success_count)

    return {"success_count": success_count, "total": len(data.asset_ids)}


async def add_tag(
    db: AsyncSession, asset_id: str, family_id: str, user_id: str, tag: str
) -> None:
    """Add a tag to an asset."""
    await _verify_family_member(db, family_id, user_id)

    stmt = select(Asset).where(Asset.id == asset_id, Asset.family_id == family_id)
    result = await db.execute(stmt)
    asset = result.scalar_one_or_none()

    if not asset:
        raise NotFoundError("资产", asset_id)

    tags = asset.tags or []
    if tag not in tags:
        tags.append(tag)
        asset.tags = tags
        await db.flush()


async def remove_tag(
    db: AsyncSession, asset_id: str, family_id: str, user_id: str, tag: str
) -> None:
    """Remove a tag from an asset."""
    await _verify_family_member(db, family_id, user_id)

    stmt = select(Asset).where(Asset.id == asset_id, Asset.family_id == family_id)
    result = await db.execute(stmt)
    asset = result.scalar_one_or_none()

    if not asset:
        raise NotFoundError("资产", asset_id)

    tags = asset.tags or []
    if tag in tags:
        tags.remove(tag)
        asset.tags = tags
        await db.flush()


async def get_all_tags(
    db: AsyncSession, family_id: str, user_id: str
) -> list[dict[str, Any]]:
    """Get all unique tags used in the family's assets."""
    await _verify_family_member(db, family_id, user_id)

    stmt = select(Asset.tags).where(
        Asset.family_id == family_id,
        Asset.status == "active",
        Asset.tags.isnot(None),
    )
    result = await db.execute(stmt)
    all_tags = result.scalars().all()

    # Count tag usage
    tag_counts: dict[str, int] = {}
    for tags in all_tags:
        if isinstance(tags, list):
            for tag in tags:
                tag_counts[tag] = tag_counts.get(tag, 0) + 1

    return [{"tag": tag, "count": count} for tag, count in sorted(tag_counts.items(), key=lambda x: -x[1])]


async def get_asset_stats(
    db: AsyncSession, family_id: str, user_id: str
) -> AssetStatsResponse:
    """Get asset statistics grouped by dimensions."""
    await _verify_family_member(db, family_id, user_id)

    # Get all active assets with financial info
    stmt = (
        select(Asset, AssetFinancial)
        .join(AssetFinancial, AssetFinancial.asset_id == Asset.id, isouter=True)
        .where(Asset.family_id == family_id, Asset.status == "active")
    )
    result = await db.execute(stmt)
    rows = result.all()

    total_count = len(rows)
    total_value = 0
    by_nature: dict[str, dict] = {}
    by_utility: dict[str, dict] = {}
    by_ownership: dict[str, dict] = {}
    by_liquidity: dict[str, dict] = {}

    for asset, financial in rows:
        value = financial.current_value if financial else 0
        total_value += value

        # Group by nature
        if asset.nature not in by_nature:
            by_nature[asset.nature] = {"count": 0, "value": 0}
        by_nature[asset.nature]["count"] += 1
        by_nature[asset.nature]["value"] += value

        # Group by utility
        if asset.utility not in by_utility:
            by_utility[asset.utility] = {"count": 0, "value": 0}
        by_utility[asset.utility]["count"] += 1
        by_utility[asset.utility]["value"] += value

        # Group by ownership
        if asset.ownership not in by_ownership:
            by_ownership[asset.ownership] = {"count": 0, "value": 0}
        by_ownership[asset.ownership]["count"] += 1
        by_ownership[asset.ownership]["value"] += value

        # Group by liquidity
        if asset.liquidity not in by_liquidity:
            by_liquidity[asset.liquidity] = {"count": 0, "value": 0}
        by_liquidity[asset.liquidity]["count"] += 1
        by_liquidity[asset.liquidity]["value"] += value

    return AssetStatsResponse(
        total_count=total_count,
        total_value=total_value,
        by_nature=by_nature,
        by_utility=by_utility,
        by_ownership=by_ownership,
        by_liquidity=by_liquidity,
    )
